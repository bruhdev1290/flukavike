//
//  WebAuthService.swift
//  Web-based authentication for Fluxer via web.fluxer.app
//
//  This service handles authentication through the web interface at web.fluxer.app,
//  bypassing hCaptcha challenges by letting the web handle the login flow.
//

import SwiftUI
import AuthenticationServices

/// Session info returned from web authentication
struct WebSession: Codable {
    let token: String
    let refreshToken: String?
    let user: User
    let expiresAt: Date?
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
}

/// Manages web-based authentication via web.fluxer.app
@Observable
class WebAuthService: NSObject {
    static let shared = WebAuthService()
    
    // MARK: - Constants
    
    /// The central Fluxer web instance (matching Dart SDK)
    static let apiHost = "api.fluxer.app"
    static let apiBaseURL = "https://api.fluxer.app/v1"
    static let webInstanceHost = "web.fluxer.app"
    static let webInstanceURL = "https://web.fluxer.app"
    static let authCallbackScheme = "flukavike"
    static let authCallbackPath = "auth"
    
    // MARK: - Properties
    
    /// Current active session
    private(set) var currentSession: WebSession?
    
    /// All saved sessions (for multiple accounts)
    private(set) var savedSessions: [WebSession] = []
    
    /// Whether user is authenticated
    var isAuthenticated: Bool {
        currentSession != nil
    }
    
    /// Current auth token
    var authToken: String? {
        currentSession?.token
    }
    
    /// Current user
    var currentUser: User? {
        currentSession?.user
    }
    
    /// Authentication session
    private var authSession: ASWebAuthenticationSession?
    
    /// Completion handler for auth
    private var authCompletion: ((Result<WebSession, Error>) -> Void)?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        loadSession()
    }
    
    // MARK: - Authentication
    
    /// Start web-based authentication flow
    func authenticate() async throws -> WebSession {
        return try await withCheckedThrowingContinuation { continuation in
            authenticate { result in
                switch result {
                case .success(let session):
                    continuation.resume(returning: session)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func authenticate(completion: @escaping (Result<WebSession, Error>) -> Void) {
        self.authCompletion = completion
        
        // Build the web auth URL
        // Open the web app login page. After successful login,
        // the web app should support redirecting back to the mobile app.
        // Common patterns: /login?redirect=, /auth?callback=, etc.
        // 
        // For now, we open the main app and the user can login there.
        // The web app needs to support mobile redirect for this to work properly.
        let authURLString = "\(Self.webInstanceURL)/login?redirect=\(Self.authCallbackScheme)://\(Self.authCallbackPath)"
        
        guard let authURL = URL(string: authURLString) else {
            completion(.failure(WebAuthError.invalidURL))
            return
        }
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: Self.authCallbackScheme
        ) { [weak self] callbackURL, error in
            self?.handleAuthCallback(callbackURL: callbackURL, error: error)
        }
        
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        
        DispatchQueue.main.async {
            self.authSession?.start()
        }
    }
    
    /// Handle the authentication callback from web
    private func handleAuthCallback(callbackURL: URL?, error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                authCompletion?(.failure(WebAuthError.cancelled))
            } else {
                authCompletion?(.failure(error))
            }
            authCompletion = nil
            return
        }
        
        guard let url = callbackURL else {
            authCompletion?(.failure(WebAuthError.noCallback))
            authCompletion = nil
            return
        }
        
        // Parse the callback URL
        // Expected: flukavike://auth?token=xxx&refresh_token=yyy&expires_in=zzz
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            authCompletion?(.failure(WebAuthError.invalidCallback))
            authCompletion = nil
            return
        }
        
        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        guard let token = params["token"] else {
            if let errorMessage = params["error"] {
                authCompletion?(.failure(WebAuthError.serverError(errorMessage)))
            } else {
                authCompletion?(.failure(WebAuthError.missingToken))
            }
            authCompletion = nil
            return
        }
        
        // Parse optional fields
        let refreshToken = params["refresh_token"]
        var expiresAt: Date?
        if let expiresIn = params["expires_in"], let seconds = TimeInterval(expiresIn) {
            expiresAt = Date().addingTimeInterval(seconds)
        }
        
        // Fetch user info with the token
        Task {
            do {
                // Set up API with the new token
                APIService.shared.setAuthToken(token)
                APIService.shared.setInstance(Self.webInstanceHost)
                
                // Discover endpoints from api.fluxer.app (matching Dart SDK)
                try await APIService.shared.discoverInstance(Self.apiHost)
                
                // Fetch current user
                let user = try await APIService.shared.getCurrentUser()
                
                let session = WebSession(
                    token: token,
                    refreshToken: refreshToken,
                    user: user,
                    expiresAt: expiresAt
                )
                
                await MainActor.run {
                    self.setSession(session)
                    self.authCompletion?(.success(session))
                    self.authCompletion = nil
                }
            } catch {
                await MainActor.run {
                    self.authCompletion?(.failure(error))
                    self.authCompletion = nil
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Set the current session and save it
    func setSession(_ session: WebSession) {
        currentSession = session
        saveSession()

        // Update API service token only — URLs were already set by discoverInstance
        APIService.shared.setAuthToken(session.token)
    }
    
    /// Clear the current session (logout)
    func logout() {
        // Optionally notify server
        Task {
            _ = try? await APIService.shared.logout()
        }
        clearSession()
    }

    /// Clear session locally without hitting the API (used on 401 to avoid loops)
    func clearSession() {
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: "web_auth_session")
        APIService.shared.setAuthToken("")
        WebSocketService.shared.disconnect()
    }
    
    /// Switch to a different saved account
    func switchToSession(_ session: WebSession) {
        setSession(session)
        
        // Reconnect WebSocket
        if let gatewayURL = APIService.shared.gatewayURL.isEmpty ? nil : APIService.shared.gatewayURL {
            WebSocketService.shared.setGatewayURL(gatewayURL)
            WebSocketService.shared.connect(token: session.token)
        }
    }
    
    // MARK: - Persistence
    
    private func saveSession() {
        guard let session = currentSession,
              let data = try? JSONEncoder.flukavike.encode(session) else {
            return
        }
        UserDefaults.standard.set(data, forKey: "web_auth_session")
    }
    
    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: "web_auth_session"),
              let session = try? JSONDecoder.flukavike.decode(WebSession.self, from: data) else {
            return
        }
        
        // Check if session is expired
        if session.isExpired {
            UserDefaults.standard.removeObject(forKey: "web_auth_session")
            return
        }
        
        currentSession = session

        // Restore API service token — base URLs remain as initialized (api.fluxer.app/v1)
        APIService.shared.setAuthToken(session.token)
    }
    
    // MARK: - Migration
    
    /// Migrate from legacy AuthService to WebAuthService
    func migrateFromLegacyIfNeeded() async {
        guard currentSession == nil,
              let legacyToken = AuthService.shared.authToken else {
            return
        }
        
        do {
            // Try to use legacy token
            APIService.shared.setAuthToken(legacyToken)
            APIService.shared.setInstance(Self.webInstanceHost)
            
            // Discover from api.fluxer.app and fetch user (matching Dart SDK)
            try await APIService.shared.discoverInstance(Self.apiHost)
            let user = try await APIService.shared.getCurrentUser()
            
            let session = WebSession(
                token: legacyToken,
                refreshToken: AuthService.shared.refreshToken,
                user: user,
                expiresAt: nil
            )
            
            await MainActor.run {
                self.setSession(session)
            }
            
            // Clear legacy auth
            await AuthService.shared.logout()
            
        } catch {
            // Migration failed, user needs to re-login
            print("[WebAuth] Migration failed: \(error)")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension WebAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Errors

enum WebAuthError: Error, LocalizedError {
    case invalidURL
    case cancelled
    case noCallback
    case invalidCallback
    case missingToken
    case serverError(String)
    case discoveryFailed
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid authentication URL"
        case .cancelled:
            return "Authentication was cancelled"
        case .noCallback:
            return "No response from authentication server"
        case .invalidCallback:
            return "Invalid response from authentication server"
        case .missingToken:
            return "Authentication token not received"
        case .serverError(let message):
            return "Server error: \(message)"
        case .discoveryFailed:
            return "Could not connect to Fluxer. Please try again."
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}
