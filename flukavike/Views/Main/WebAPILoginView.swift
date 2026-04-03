//
//  WebAPILoginView.swift
//  Direct API login for web.fluxer.app with captcha support
//

import SwiftUI

struct WebAPILoginView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    // Captcha state
    @State private var showCaptchaSheet: Bool = false
    @State private var captchaToken: String?
    @State private var captchaSiteKey: String = ""
    @State private var captchaProvider: String = "hcaptcha"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 16) {
                        ZStack {
                            HexagonShape()
                                .fill(themeManager.accentColor.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "hexagon.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(themeManager.accentColor.color)
                        }
                        
                        Text("Sign in to Fluxer")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        Text("web.fluxer.app")
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.top, 40)
                    
                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Form
                    VStack(spacing: 20) {
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username or Email")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                            
                            TextField("username", text: $username)
                                .font(.system(size: 17))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.backgroundTertiary(colorScheme))
                                )
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                            
                            SecureField("••••••••", text: $password)
                                .font(.system(size: 17))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.backgroundTertiary(colorScheme))
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    if showCaptchaSheet && !captchaSiteKey.isEmpty {
                        HCaptchaWidgetCard(
                            siteKey: captchaSiteKey,
                            provider: captchaProvider,
                            token: captchaToken,
                            onToken: { token in
                                captchaToken = token
                                errorMessage = "Verification completed."
                            },
                            onReset: {
                                captchaToken = nil
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Sign In Button
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canSignIn && (!showCaptchaSheet || captchaToken != nil) ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                        )
                    }
                    .disabled(!canSignIn || isLoading || (showCaptchaSheet && captchaToken == nil))
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Info
                    VStack(spacing: 8) {
                        Text("Powered by Fluxer")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                        
                        HStack(spacing: 16) {
                            Link("Privacy", destination: URL(string: "https://fluxer.app/privacy")!)
                            Link("Terms", destination: URL(string: "https://fluxer.app/terms")!)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.accentColor.color)
                    }
                    .padding(.bottom, 34)
                }
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
            }
        }
    }
    
    private var canSignIn: Bool {
        !username.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use the API host (matching Dart SDK: api.fluxer.app)
                let instance = WebAuthService.apiHost
                
                // Discover endpoints first
                try await APIService.shared.discoverInstance(instance)

                // Attempt login. If captcha is required, the error will be caught
                // and the captcha challenge will be displayed.
                let response = try await AuthService.shared.login(
                    instance: instance,
                    login: username,
                    password: password,
                    captchaKey: captchaToken
                )
                
                // Create web session
                let session = WebSession(
                    token: response.token,
                    refreshToken: response.refreshToken,
                    user: response.user,
                    expiresAt: nil
                )
                
                await MainActor.run {
                    WebAuthService.shared.setSession(session)
                    appState.currentUser = response.user
                    isLoading = false
                    captchaToken = nil
                    showCaptchaSheet = false
                    dismiss()
                }
                
                // Connect WebSocket
                await connectWebSocket(token: response.token)
                
            } catch let error as APIError {
                print("[Login] APIError: \(error)")
                await MainActor.run {
                    isLoading = false
                    handleAPIError(error)
                }
            } catch {
                print("[Login] Unexpected error: \(error)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Login could not be completed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .captchaRequired(let sitekey, let service):
            startCaptchaChallenge(sitekey: sitekey, provider: service)
            errorMessage = "Complete verification to continue."

        case .mfaRequired(_, let allowedMethods):
            showCaptchaSheet = false
            captchaToken = nil
            let methods = allowedMethods.joined(separator: ", ")
            if methods.isEmpty {
                errorMessage = "This account requires multi-factor authentication."
            } else {
                errorMessage = "This account requires multi-factor authentication (\(methods))."
            }

        case .ipAuthorizationRequired(_, let email, _):
            showCaptchaSheet = false
            captchaToken = nil
            if let email, !email.isEmpty {
                errorMessage = "Check \(email) and approve this login attempt."
            } else {
                errorMessage = "Approve this login attempt from your email, then try again."
            }
            
        case .unauthorized:
            errorMessage = "Invalid username or password"
            // Reset captcha on auth failure
            captchaToken = nil
            showCaptchaSheet = false

        case .invalidURL:
            errorMessage = "Could not connect to server"

        case .rateLimited:
            showCaptchaSheet = false
            captchaToken = nil
            errorMessage = "Too many login attempts. Please wait a few minutes and try again."

        case .forbidden:
            showCaptchaSheet = false
            captchaToken = nil
            errorMessage = "Access denied. Please try again or contact support."

        case .serverError(_, let message):
            let lower = message?.lowercased() ?? ""
            let normalized = lower.filter { $0.isLetter || $0.isNumber }
            if lower.contains("captcha") || lower.contains("api error 7") || normalized.contains("apierror7") {
                startCaptchaChallenge(sitekey: nil, provider: nil)
                errorMessage = "Complete verification to continue."
            } else {
                errorMessage = message ?? "Server error"
                showCaptchaSheet = false
            }

        case .decodingError(let underlying):
            showCaptchaSheet = false
            captchaToken = nil
            errorMessage = "Unexpected response: \(underlying.localizedDescription)"

        case .notFound:
            showCaptchaSheet = false
            captchaToken = nil
            errorMessage = "API endpoint not found. Check that the server is reachable. (URL: \(APIService.shared.apiBaseURL))"

        case .invalidResponse:
            showCaptchaSheet = false
            captchaToken = nil
            errorMessage = "No response from server. Check your network connection."

        default:
            showCaptchaSheet = false
            errorMessage = "Login could not be completed. Please try again."
        }
    }

    private func startCaptchaChallenge(sitekey: String?, provider: String?) {
        captchaToken = nil

        if let sitekey, !sitekey.isEmpty {
            captchaSiteKey = sitekey
        } else if let config = APIService.shared.captchaConfig, !config.sitekey.isEmpty {
            captchaSiteKey = config.sitekey
        } else {
            captchaSiteKey = APIService.fallbackHCaptchaSiteKey
        }

        let resolvedProvider = (provider
            ?? APIService.shared.captchaConfig?.provider
            ?? "hcaptcha")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        captchaProvider = resolvedProvider.contains("turnstile") ? "turnstile" : "hcaptcha"

        showCaptchaSheet = !captchaSiteKey.isEmpty
        if !showCaptchaSheet {
            errorMessage = "Verification is temporarily unavailable. Please try again."
        }
    }
    
    private func connectWebSocket(token: String) async {
        if APIService.shared.gatewayURL.isEmpty {
            try? await APIService.shared.discoverInstance(WebAuthService.webInstanceHost)
        }
        
        let gatewayURL = APIService.shared.gatewayURL
        if !gatewayURL.isEmpty {
            WebSocketService.shared.setGatewayURL(gatewayURL)
        }
        WebSocketService.shared.connect(token: token)
        
        // Register for push
        if let deviceToken = PushNotificationService.shared.deviceToken {
            try? await APIService.shared.registerDeviceToken(token: deviceToken, platform: "ios")
        }
    }
}

#Preview {
    WebAPILoginView()
        .environment(ThemeManager())
        .environment(AppState())
}
