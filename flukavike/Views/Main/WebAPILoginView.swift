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
    @State private var showCaptcha: Bool = false
    @State private var captchaToken: String?
    @State private var captchaSiteKey: String = ""
    
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
                    
                    // Captcha Widget (shown when required)
                    if showCaptcha && !captchaSiteKey.isEmpty {
                        VStack(spacing: 12) {
                            Text("Complete the verification to continue")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                            
                            HCaptchaWidgetCard(
                                siteKey: captchaSiteKey,
                                token: captchaToken,
                                onToken: { token in
                                    captchaToken = token
                                    errorMessage = nil
                                    // Auto-submit when captcha is completed
                                    signIn()
                                },
                                onReset: {
                                    captchaToken = nil
                                }
                            )
                        }
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
                                .fill(canSignIn ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                        )
                    }
                    .disabled(!canSignIn || isLoading || (showCaptcha && captchaToken == nil))
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
                
                // Attempt login with captcha token if available
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
                    dismiss()
                }
                
                // Connect WebSocket
                await connectWebSocket(token: response.token)
                
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    handleAPIError(error)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed. Please try again."
                }
            }
        }
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .captchaRequired(let sitekey, _):
            // Show captcha challenge
            showCaptcha = true
            if let sitekey = sitekey, !sitekey.isEmpty {
                captchaSiteKey = sitekey
            } else if let config = APIService.shared.captchaConfig {
                captchaSiteKey = config.sitekey
            } else {
                captchaSiteKey = APIService.fallbackHCaptchaSiteKey
            }
            errorMessage = "Please complete the verification below."
            
        case .unauthorized:
            errorMessage = "Invalid username or password"
            // Reset captcha on auth failure
            captchaToken = nil
            
        case .invalidURL:
            errorMessage = "Could not connect to server"
            
        case .serverError(_, let message):
            errorMessage = message ?? "Server error"
            
        default:
            errorMessage = "Sign in failed: \(error.localizedDescription)"
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
