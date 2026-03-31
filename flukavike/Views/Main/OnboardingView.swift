//
//  OnboardingView.swift
//  Welcome flow
//

import SwiftUI

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    
    @State private var currentPage: Int = 0
    @State private var showLogin: Bool = false
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "hexagon.fill",
            title: "Welcome to Flukavike",
            description: "A modern, open-source platform for communities. Self-hostable, customizable, and built for the future."
        ),
        OnboardingPage(
            icon: "person.3.fill",
            title: "Your Communities",
            description: "Join multiple servers, each with their own channels, roles, and personality. All in one seamless app."
        ),
        OnboardingPage(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Rich Messaging",
            description: "Markdown support, reactions, threads, and file sharing. Express yourself with voice and video too."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Privacy First",
            description: "Self-hosting options, transparent data practices, and tools that keep your community in control. You own your data."
        )
    ]
    
    var body: some View {
        ZStack {
            themeManager.backgroundPrimary(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip Button
                HStack {
                    Spacer()
                    Button(action: { showLogin = true }) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? themeManager.accentColor.color : themeManager.separator(colorScheme))
                            .frame(width: currentPage == index ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button(action: { currentPage += 1 }) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.accentColor.color)
                                )
                        }
                    } else {
                        Button(action: { showLogin = true }) {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.accentColor.color)
                                )
                        }
                    }
                    
                    if currentPage == pages.count - 1 {
                        Button(action: { showLogin = true }) {
                            Text("I already have an account")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(themeManager.accentColor.color)
                                .padding(.vertical, 12)
                        }
                    }
                    
                    if currentPage == pages.count - 1 {
                        Button(action: { showLogin = true }) {
                            Text("I already have an account")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(themeManager.accentColor.color)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showLogin) {
            WebLoginView()
        }
    }
}

// MARK: - Onboarding Page
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon Animation
            ZStack {
                // Background glow
                Circle()
                    .fill(themeManager.accentColor.color.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Circle()
                    .fill(themeManager.accentColor.color.opacity(0.2))
                    .frame(width: 160, height: 160)
                
                // Main icon
                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundStyle(themeManager.accentColor.color)
                    .symbolRenderingMode(.multicolor)
            }
            
            // Text Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var instance: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showInstancePicker: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showRegistration: Bool = false
    @State private var showQRCodeHelp: Bool = false
    @State private var captchaToken: String? = nil
    @State private var captchaSiteKey: String = ""
    
    let popularInstances = [
        "web.fluxer.app",
        "fluxer.app",
        "chat.privacy.dev",
        "community.open",
        "talk.tech"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                        
                        Text("Sign in to Flukavike")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    }
                    .padding(.top, 32)
                    
                    // Instance Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instance")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                TextField("fluxer.app", text: $instance)
                                    .font(.system(size: 17))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                
                                Button(action: { showInstancePicker.toggle() }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                                        .rotationEffect(.degrees(showInstancePicker ? 180 : 0))
                                        .animation(.easeInOut(duration: 0.2), value: showInstancePicker)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                            
                            if showInstancePicker {
                                VStack(spacing: 0) {
                                    ForEach(popularInstances, id: \.self) { inst in
                                        Button(action: {
                                            instance = inst
                                            showInstancePicker = false
                                        }) {
                                            HStack {
                                                Text(inst)
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                                
                                                Spacer()
                                                
                                                if instance == inst {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(themeManager.accentColor.color)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        
                                        if inst != popularInstances.last {
                                            Divider()
                                                .padding(.leading, 12)
                                                .background(themeManager.separator(colorScheme))
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.backgroundSecondary(colorScheme))
                                )
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username or Email")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        TextField("username", text: $username)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(12)
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
                            .padding(.horizontal, 4)
                        
                        SecureField("••••••••", text: $password)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    if !captchaSiteKey.isEmpty {
                        HCaptchaWidgetCard(
                            siteKey: captchaSiteKey,
                            token: captchaToken,
                            onToken: { token in
                                captchaToken = token
                                errorMessage = nil
                            },
                            onReset: {
                                captchaToken = nil
                            }
                        )
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
                    .disabled(!canSignIn || isLoading)
                    
                    // Alternative Options
                    VStack(spacing: 16) {
                        Button(action: { showQRCodeHelp = true }) {
                            Text("Sign in with QR Code")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(themeManager.accentColor.color)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                            
                            Button(action: { showRegistration = true }) {
                                Text("Create one")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(themeManager.accentColor.color)
                            }
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
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
            .sheet(isPresented: $showRegistration) {
                RegistrationView {
                    dismiss()
                }
            }
            .alert("QR sign-in isn't available yet", isPresented: $showQRCodeHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Use your instance, username, and password for now.")
            }
            .onChange(of: instance) { _, _ in
                captchaSiteKey = ""
                captchaToken = nil
            }
        }
    }
    

    private var canSignIn: Bool {
        !instance.isEmpty
            && !username.isEmpty
            && !password.isEmpty
            && (captchaSiteKey.isEmpty || captchaToken != nil)
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Discover instance to check for captcha requirement
                try await APIService.shared.discoverInstance(instance)
                
                // If captcha is required and we don't have a token yet, show the challenge
                if let config = APIService.shared.captchaConfig, captchaToken == nil {
                    await MainActor.run {
                        isLoading = false
                        captchaSiteKey = config.sitekey
                        errorMessage = "Complete the hCaptcha verification to continue."
                    }
                    return
                }
                
                let response = try await AuthService.shared.login(
                    instance: instance,
                    login: username,
                    password: password,
                    captchaKey: captchaToken
                )
                
                await MainActor.run {
                    isLoading = false
                    captchaToken = nil
                    appState.currentUser = response.user
                    dismiss()
                }
                
                // Set gateway URL from discovery, then connect WebSocket
                let discoveredGateway = APIService.shared.gatewayURL
                if !discoveredGateway.isEmpty {
                    WebSocketService.shared.setGatewayURL(discoveredGateway)
                }
                WebSocketService.shared.connect(token: response.token)
                
                // Register for push notifications
                if let deviceToken = PushNotificationService.shared.deviceToken {
                    try? await APIService.shared.registerDeviceToken(
                        token: deviceToken,
                        platform: "ios"
                    )
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    let normalizedInstance = APIService.normalizeInstance(instance)
                    switch error {
                    case .captchaRequired(let sitekey, _):
                        // Server requires captcha — show the challenge
                        captchaToken = nil
                        if let sitekey, !sitekey.isEmpty {
                            captchaSiteKey = sitekey
                        } else if let config = APIService.shared.captchaConfig {
                            captchaSiteKey = config.sitekey
                        }
                        if !captchaSiteKey.isEmpty {
                            errorMessage = "Complete the hCaptcha verification to continue."
                        } else {
                            errorMessage = "Captcha required but no sitekey available."
                        }
                    case .unauthorized:
                        captchaToken = nil
                        errorMessage = "Invalid username or password"
                    case .invalidURL:
                        captchaToken = nil
                        errorMessage = "Could not connect to \(instance). Check the instance URL."
                    case .forbidden(let message):
                        captchaToken = nil
                        errorMessage = message ?? "Connection forbidden by \(normalizedInstance)."
                    case .serverError(_, let message):
                        captchaToken = nil
                        errorMessage = message ?? "Server error. Please try again."
                    default:
                        captchaToken = nil
                        errorMessage = "Connection failed: \(error)"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    captchaToken = nil
                    errorMessage = "Could not connect to \(instance). Check the instance URL."
                }
            }
        }
    }
}

// MARK: - Registration View
struct RegistrationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var instance: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showInstancePicker: Bool = false
    @State private var errorMessage: String? = nil
    @State private var captchaToken: String? = nil
    @State private var captchaSiteKey: String = ""
    
    let onAuthenticated: () -> Void
    
    private let popularInstances = [
        "web.fluxer.app",
        "fluxer.app",
        "chat.privacy.dev",
        "community.open",
        "talk.tech"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            HexagonShape()
                                .fill(themeManager.accentColor.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(themeManager.accentColor.color)
                        }
                        
                        Text("Create your Flukavike account")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instance")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                TextField("fluxer.app", text: $instance)
                                    .font(.system(size: 17))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                
                                Button(action: { showInstancePicker.toggle() }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                                        .rotationEffect(.degrees(showInstancePicker ? 180 : 0))
                                        .animation(.easeInOut(duration: 0.2), value: showInstancePicker)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                            
                            if showInstancePicker {
                                VStack(spacing: 0) {
                                    ForEach(popularInstances, id: \.self) { inst in
                                        Button(action: {
                                            instance = inst
                                            showInstancePicker = false
                                        }) {
                                            HStack {
                                                Text(inst)
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                                
                                                Spacer()
                                                
                                                if instance == inst {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(themeManager.accentColor.color)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        
                                        if inst != popularInstances.last {
                                            Divider()
                                                .padding(.leading, 12)
                                                .background(themeManager.separator(colorScheme))
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.backgroundSecondary(colorScheme))
                                )
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        TextField("username", text: $username)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        TextField("name@example.com", text: $email)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .padding(.horizontal, 4)
                        
                        SecureField("Create a password", text: $password)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    if !captchaSiteKey.isEmpty {
                        HCaptchaWidgetCard(
                            siteKey: captchaSiteKey,
                            token: captchaToken,
                            onToken: { token in
                                captchaToken = token
                                errorMessage = nil
                            },
                            onReset: {
                                captchaToken = nil
                            }
                        )
                    }
                    
                    Button(action: register) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canRegister ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                        )
                    }
                    .disabled(!canRegister || isLoading)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
            }
            .onChange(of: instance) { _, _ in
                captchaSiteKey = ""
                captchaToken = nil
            }
        }
    }
    

    private var canRegister: Bool {
        !instance.isEmpty
            && !username.isEmpty
            && !email.isEmpty
            && !password.isEmpty
            && (captchaSiteKey.isEmpty || captchaToken != nil)
    }
    
    private func register() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Discover instance to check for captcha requirement
                try await APIService.shared.discoverInstance(instance)
                
                // If captcha is required and we don't have a token yet, show the challenge
                if let config = APIService.shared.captchaConfig, captchaToken == nil {
                    await MainActor.run {
                        isLoading = false
                        captchaSiteKey = config.sitekey
                        errorMessage = "Complete the hCaptcha verification to continue."
                    }
                    return
                }
                
                let response = try await AuthService.shared.register(
                    instance: instance,
                    username: username,
                    email: email,
                    password: password,
                    captchaKey: captchaToken
                )
                
                await MainActor.run {
                    isLoading = false
                    captchaToken = nil
                    appState.currentUser = response.user
                    dismiss()
                    onAuthenticated()
                }
                
                // Set gateway URL from discovery, then connect WebSocket
                let discoveredGateway = APIService.shared.gatewayURL
                if !discoveredGateway.isEmpty {
                    WebSocketService.shared.setGatewayURL(discoveredGateway)
                }
                WebSocketService.shared.connect(token: response.token)
                
                if let deviceToken = PushNotificationService.shared.deviceToken {
                    try? await APIService.shared.registerDeviceToken(
                        token: deviceToken,
                        platform: "ios"
                    )
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .captchaRequired(let sitekey, _):
                        captchaToken = nil
                        if let sitekey, !sitekey.isEmpty {
                            captchaSiteKey = sitekey
                        } else if let config = APIService.shared.captchaConfig {
                            captchaSiteKey = config.sitekey
                        }
                        if !captchaSiteKey.isEmpty {
                            errorMessage = "Complete the hCaptcha verification to continue."
                        } else {
                            errorMessage = "Captcha required but no sitekey available."
                        }
                    case .invalidURL:
                        captchaToken = nil
                        errorMessage = "Could not connect to \(instance). Check the instance URL."
                    case .forbidden(let message):
                        captchaToken = nil
                        errorMessage = message ?? "Registration forbidden. Please try again."
                    default:
                        captchaToken = nil
                        errorMessage = "Could not create your account: \(error)"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    captchaToken = nil
                    errorMessage = "Could not create your account. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .environment(ThemeManager())
        .environment(AppState())
}
