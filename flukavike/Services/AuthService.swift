//
//  AuthService.swift
//  Authentication service for Flukavike
//

import Foundation

@Observable
class AuthService {
    static let shared = AuthService()
    
    var isAuthenticated: Bool {
        authToken != nil
    }
    
    private(set) var authToken: String? {
        didSet {
            if let token = authToken {
                APIService.shared.setAuthToken(token)
                _ = KeychainTokenStore.saveToken(token)
            } else {
                APIService.shared.setAuthToken("")
                _ = KeychainTokenStore.deleteToken()
            }
        }
    }
    
    private(set) var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                _ = KeychainTokenStore.saveRefreshToken(token)
            } else {
                _ = KeychainTokenStore.deleteRefreshToken()
            }
        }
    }
    
    private init() {
        self.authToken = KeychainTokenStore.getToken()
        self.refreshToken = KeychainTokenStore.getRefreshToken()
        if let token = authToken {
            APIService.shared.setAuthToken(token)
        }
    }
    
    // MARK: - Login
    
    func login(instance: String, username: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        let response = try await APIService.shared.login(
            instance: instance,
            username: username,
            password: password,
            captchaKey: captchaKey
        )
        
        await MainActor.run {
            self.authToken = response.token
            self.refreshToken = response.refreshToken
        }
        
        return response
    }
    
    // MARK: - Register
    
    func register(instance: String, username: String, email: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        let response = try await APIService.shared.register(
            instance: instance,
            username: username,
            email: email,
            password: password,
            captchaKey: captchaKey
        )
        
        await MainActor.run {
            self.authToken = response.token
            self.refreshToken = response.refreshToken
        }
        
        return response
    }
    
    // MARK: - Logout
    
    func logout() async {
        // Optionally notify server
        try? await APIService.shared.logout()
        
        await MainActor.run {
            self.authToken = nil
            self.refreshToken = nil
        }
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        let response = try await APIService.shared.refreshToken(refreshToken: refreshToken)
        
        await MainActor.run {
            self.authToken = response.token
            if let newRefreshToken = response.refreshToken {
                self.refreshToken = newRefreshToken
            }
        }
        
        return response.token
    }
}

// MARK: - Errors

enum AuthError: Error {
    case noRefreshToken
    case invalidCredentials
    case accountLocked
    case unknown
}

// MARK: - Responses

struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
}

struct RefreshResponse: Codable {
    let token: String
    let refreshToken: String?
}
