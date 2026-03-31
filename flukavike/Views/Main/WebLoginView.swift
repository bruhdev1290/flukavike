//
//  WebLoginView.swift
//  Web-based login for Fluxer via web.fluxer.app
//
//  This view presents a simple sign-in button that opens web.fluxer.app
//  in a web authentication session, bypassing hCaptcha challenges.
//

import SwiftUI

struct WebLoginView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var showAdvancedOptions = false
    @State private var customInstance: String = ""
    @State private var showAPILogin = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo and Header
                VStack(spacing: 20) {
                    ZStack {
                        // Background glow
                        Circle()
                            .fill(themeManager.accentColor.color.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .fill(themeManager.accentColor.color.opacity(0.2))
                            .frame(width: 110, height: 110)
                        
                        // Hexagon logo
                        HexagonShape()
                            .fill(themeManager.accentColor.color.opacity(0.3))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Welcome to Flukavike")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        Text("Sign in with your Fluxer account")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                }
                .padding(.top, 40)
                
                // Error message
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }
                
                // Main Sign In Button - API Login (Primary)
                VStack(spacing: 16) {
                    Button(action: { showAPILogin = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                            
                            Text("Sign in with Username")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.accentColor.color)
                        )
                    }
                    
                    // Subtitle explaining the flow
                    Text("Use your Fluxer username and password")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Advanced options toggle
                VStack(spacing: 16) {
                    Button(action: { showAdvancedOptions.toggle() }) {
                        HStack(spacing: 4) {
                            Text("Advanced Options")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                            
                            Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                        }
                    }
                    
                    if showAdvancedOptions {
                        VStack(spacing: 16) {
                            // Web Login Option (in Safari)
                            Button(action: signInWithWeb) {
                                HStack(spacing: 12) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 20))
                                        .foregroundStyle(themeManager.accentColor.color)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sign in via Web")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                                        
                                        Text("Open web.fluxer.app in Safari")
                                            .font(.system(size: 13))
                                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 16))
                                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isAuthenticating)
                            
                            Divider()
                            
                            // Custom Instance Option
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Instance")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                                
                                HStack(spacing: 12) {
                                    TextField("instance.example.com", text: $customInstance)
                                        .font(.system(size: 15))
                                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(themeManager.backgroundTertiary(colorScheme))
                                        )
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.URL)
                                    
                                    Button(action: signInWithCustomInstance) {
                                        Text("Connect")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(themeManager.accentColor.color)
                                    }
                                    .disabled(customInstance.isEmpty)
                                }
                                
                                Text("For self-hosted instances")
                                    .font(.system(size: 12))
                                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.backgroundSecondary(colorScheme))
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                // Footer
                VStack(spacing: 8) {
                    Text("Powered by Fluxer")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                    HStack(spacing: 16) {
                        Link("Privacy", destination: URL(string: "https://fluxer.app/privacy")!)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.accentColor.color)
                        
                        Text("·")
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                        
                        Link("Terms", destination: URL(string: "https://fluxer.app/terms")!)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
                .padding(.bottom, 34)
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
            .sheet(isPresented: $showAPILogin) {
                WebAPILoginView()
            }
        }
    }
    
    // MARK: - Actions
    
    private func signInWithWeb() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                let session = try await WebAuthService.shared.authenticate()
                
                await MainActor.run {
                    isAuthenticating = false
                    appState.currentUser = session.user
                    dismiss()
                }
                
                // Connect WebSocket after successful auth
                await connectWebSocket()
                
                // Register for push notifications
                await registerForPushNotifications()
                
            } catch WebAuthError.cancelled {
                await MainActor.run {
                    isAuthenticating = false
                    // Don't show error for user cancellation
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func signInWithCustomInstance() {
        // For custom instances, use the traditional API login
        // This would show the old login flow for self-hosted instances
        // Implementation can be added if needed
        errorMessage = "Custom instance support coming soon"
    }
    
    private func connectWebSocket() async {
        guard let session = WebAuthService.shared.currentSession else { return }
        
        // Ensure we have discovered endpoints
        if APIService.shared.gatewayURL.isEmpty {
            try? await APIService.shared.discoverInstance(WebAuthService.webInstanceHost)
        }
        
        let gatewayURL = APIService.shared.gatewayURL
        if !gatewayURL.isEmpty {
            WebSocketService.shared.setGatewayURL(gatewayURL)
        }
        
        WebSocketService.shared.connect(token: session.token)
    }
    
    private func registerForPushNotifications() async {
        guard let deviceToken = PushNotificationService.shared.deviceToken else { return }
        
        do {
            try await APIService.shared.registerDeviceToken(
                token: deviceToken,
                platform: "ios"
            )
        } catch {
            print("[WebLogin] Failed to register push token: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    WebLoginView()
        .environment(ThemeManager())
        .environment(AppState())
}
