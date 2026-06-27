//
//  LoginViewModel.swift
//  State machine for the unified login flow
//

import SwiftUI
import AuthenticationServices

@Observable
final class LoginViewModel {
    // MARK: - Form State
    var email: String = ""
    var password: String = ""
    var isPasswordVisible: Bool = false
    var instance: String = ""

    // MARK: - Loading / Errors
    var isLoggingIn: Bool = false
    var isStartingSso: Bool = false
    var errorMessage: String?
    var errorType: LoginError?
    var fieldErrors: [String: String] = [:]

    // MARK: - Captcha
    var showCaptchaChallenge: Bool = false
    var captchaSiteKey: String = ""
    var captchaProvider: String = "hcaptcha"
    var captchaToken: String?

    // MARK: - Auth Sub-flows
    var mfaChallenge: MfaChallenge?
    var ipAuthChallenge: IpAuthorizationChallenge?
    var banViewInfo: BanViewInfo?
    var showRegister: Bool = false
    var showForgotPassword: Bool = false
    var forgotPasswordEmailSent: Bool = false
    var resetToken: String?
    var usernameSuggestions: [String] = []

    // MARK: - Passkey
    private var pendingPasskeyChallenge: String?

    // MARK: - Dependencies
    private let authRepository = AuthRepository.shared
    private let api = APIService.shared

    // MARK: - Computed

    var canLogin: Bool {
        !isLoggingIn
            && !isStartingSso
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    var canSubmit: Bool {
        canLogin && (!showCaptchaChallenge || captchaToken != nil)
    }

    // MARK: - Actions

    func login() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard canSubmit, isValidEmail(trimmedEmail) else {
            if !isValidEmail(trimmedEmail) {
                errorType = .invalidEmail
            }
            return
        }

        clearErrors()
        isLoggingIn = true

        Task {
            do {
                let instanceToUse = instance.isEmpty ? WebAuthService.webInstanceHost : instance
                let result = try await authRepository.login(
                    instance: instanceToUse,
                    email: trimmedEmail,
                    password: password,
                    captchaKey: captchaToken
                )
                await handleLoginResult(result)
            } catch let failure as AuthFailure {
                await handleAuthFailure(failure)
            } catch let error as APIError {
                await handleAPIError(error)
            } catch {
                await setError("Unable to sign in. Please try again.", type: .unableToSignIn)
            }
        }
    }

    func register(
        username: String,
        displayName: String,
        email: String,
        password: String,
        dateOfBirth: String
    ) {
        clearErrors()
        isLoggingIn = true

        Task {
            do {
                let instanceToUse = instance.isEmpty ? WebAuthService.webInstanceHost : instance
                let result = try await authRepository.register(
                    instance: instanceToUse,
                    email: email,
                    password: password,
                    dateOfBirth: dateOfBirth,
                    username: username,
                    displayName: displayName,
                    captchaKey: captchaToken
                )
                await handleLoginResult(result)
            } catch let failure as AuthFailure {
                await handleAuthFailure(failure)
            } catch let error as APIError {
                await handleAPIError(error)
            } catch {
                await setError("Unable to create account. Please try again.", type: .unableToCreateAccount)
            }
        }
    }

    func submitForgotPassword(email: String) {
        guard isValidEmail(email) else {
            errorType = .invalidEmail
            return
        }
        clearErrors()
        isLoggingIn = true

        Task {
            do {
                try await authRepository.forgotPassword(email: email)
                await MainActor.run {
                    forgotPasswordEmailSent = true
                    isLoggingIn = false
                }
            } catch let failure as AuthFailure {
                await handleAuthFailure(failure)
            } catch {
                await setError("Unable to send reset link. Please try again.", type: .unableToSendResetLink)
            }
        }
    }

    func submitResetPassword(token: String, password: String) {
        clearErrors()
        isLoggingIn = true

        Task {
            do {
                let result = try await authRepository.resetPassword(token: token, password: password)
                await handleLoginResult(result)
            } catch let failure as AuthFailure {
                await handleAuthFailure(failure)
            } catch {
                await setError("Unable to reset password. Please try again.", type: .unableToResetPassword)
            }
        }
    }

    // MARK: - MFA

    func verifyMfa(code: String, method: MfaMethod) {
        guard let challenge = mfaChallenge else { return }
        clearErrors()
        isLoggingIn = true

        Task {
            do {
                let session: WebSession
                switch method {
                case .totp:
                    session = try await authRepository.verifyMfaTotp(ticket: challenge.ticket, code: code)
                case .sms:
                    session = try await authRepository.verifyMfaSms(ticket: challenge.ticket, code: code)
                case .webauthn:
                    // WebAuthn MFA handled separately.
                    await setError("Security key verification failed.")
                    return
                }
                await completeSession(session)
            } catch let failure as AuthFailure {
                await handleAuthFailure(failure)
            } catch {
                await setError("Invalid code. Please try again.")
            }
        }
    }

    func sendMfaSms() {
        guard let ticket = mfaChallenge?.ticket else { return }
        Task {
            do {
                try await authRepository.sendMfaSms(ticket: ticket)
            } catch {
                await setError("Unable to send SMS code.")
            }
        }
    }

    func startMfaWebauthn() async {
        guard let challenge = mfaChallenge else { return }
        #if canImport(AuthenticationServices)
        do {
            let options = try await authRepository.getMfaWebauthnOptions(ticket: challenge.ticket)
            // ASAuthorizationController passkey flow would go here.
            // For parity, surface a placeholder message.
            await setError("Security key support is coming in a future update.")
        } catch {
            await setError("Unable to start security key verification.")
        }
        #else
        await setError("Security key support is not available on this device.")
        #endif
    }

    // MARK: - IP Authorization

    func pollIpAuthorization() async -> IpAuthPollResult {
        guard let challenge = ipAuthChallenge else { return .expired }
        do {
            let result = try await authRepository.pollIpAuthorization(ticket: challenge.ticket)
            if case .completed(let session) = result {
                await completeSession(session)
            }
            return result
        } catch {
            await setError("Login approval check failed.")
            return .pending
        }
    }

    func resendIpAuthorization() {
        guard let ticket = ipAuthChallenge?.ticket else { return }
        Task {
            do {
                try await authRepository.resendIpAuthorization(ticket: ticket)
            } catch {
                await setError("Unable to resend approval email.")
            }
        }
    }

    // MARK: - SSO

    func startSsoLogin() {
        guard !isStartingSso && !isLoggingIn else { return }
        clearErrors()
        isStartingSso = true

        Task {
            do {
                let start = try await authRepository.startSso(redirectTo: "flukavike://auth/sso/callback")
                let callback = try await authRepository.authenticateWithSso(authorizationUrl: start.authorizationUrl)
                let session = try await authRepository.completeSso(code: callback.code, state: callback.state)
                await completeSession(session)
                await MainActor.run { isStartingSso = false }
            } catch let failure as AuthFailure {
                await MainActor.run { isStartingSso = false }
                await handleAuthFailure(failure)
            } catch {
                await MainActor.run { isStartingSso = false }
                await setError("SSO sign-in failed.", type: .ssoFailed)
            }
        }
    }

    // MARK: - Passkey

    func loginWithPasskey() {
        guard !isLoggingIn else { return }
        clearErrors()
        isLoggingIn = true

        Task {
            do {
                let options = try await authRepository.getPasskeyLoginOptions()
                pendingPasskeyChallenge = options["challenge"] as? String
                // ASAuthorizationController passkey flow placeholder.
                await setError("Passkey sign-in is coming in a future update.")
                await MainActor.run { isLoggingIn = false }
            } catch {
                await setError("Unable to start passkey sign-in.")
                await MainActor.run { isLoggingIn = false }
            }
        }
    }

    // MARK: - Username Suggestions

    func fetchUsernameSuggestions(displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            usernameSuggestions = []
            return
        }
        Task {
            do {
                let suggestions = try await authRepository.getUsernameSuggestions(globalName: trimmed)
                await MainActor.run { self.usernameSuggestions = suggestions }
            } catch {
                await MainActor.run { self.usernameSuggestions = [] }
            }
        }
    }

    // MARK: - Navigation State

    func showRegisterScreen() {
        clearErrors()
        showRegister = true
        showForgotPassword = false
        forgotPasswordEmailSent = false
        resetToken = nil
    }

    func backFromRegister() {
        showRegister = false
        usernameSuggestions = []
        clearErrors()
    }

    func showForgotPasswordScreen() {
        clearErrors()
        showForgotPassword = true
        showRegister = false
        forgotPasswordEmailSent = false
        resetToken = nil
    }

    func backFromForgotPassword() {
        showForgotPassword = false
        forgotPasswordEmailSent = false
        clearErrors()
    }

    func setResetToken(_ token: String) {
        clearErrors()
        resetToken = token
        showForgotPassword = false
        showRegister = false
    }

    func clearResetToken() {
        resetToken = nil
        clearErrors()
    }

    func clearMfaChallenge() {
        mfaChallenge = nil
        clearErrors()
    }

    func clearIpAuthChallenge() {
        ipAuthChallenge = nil
        clearErrors()
    }

    func clearBanView() {
        banViewInfo = nil
        clearErrors()
    }

    func togglePasswordVisibility() {
        isPasswordVisible.toggle()
    }

    // MARK: - Captcha

    func applyCaptchaToken(_ token: String) {
        captchaToken = token
        errorMessage = nil
    }

    func resetCaptcha() {
        captchaToken = nil
    }

    func startCaptchaChallenge(sitekey: String?, provider: String?) {
        captchaToken = nil
        captchaSiteKey = {
            if let sitekey, !sitekey.isEmpty { return sitekey }
            if let config = api.captchaConfig, !config.sitekey.isEmpty { return config.sitekey }
            return APIService.fallbackHCaptchaSiteKey
        }()
        let resolvedProvider = (provider ?? api.captchaConfig?.provider ?? "hcaptcha")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        captchaProvider = resolvedProvider.contains("turnstile") ? "turnstile" : "hcaptcha"
        showCaptchaChallenge = !captchaSiteKey.isEmpty
        if !showCaptchaChallenge {
            errorMessage = "Verification is temporarily unavailable. Please try again."
        }
    }

    // MARK: - Helpers

    private func handleLoginResult(_ result: LoginResult) async {
        switch result {
        case .success(let session):
            await completeSession(session)
        case .mfaRequired(let challenge):
            await MainActor.run {
                mfaChallenge = challenge
                isLoggingIn = false
                captchaToken = nil
                showCaptchaChallenge = false
            }
        case .ipAuthRequired(let challenge):
            await MainActor.run {
                ipAuthChallenge = challenge
                isLoggingIn = false
                captchaToken = nil
                showCaptchaChallenge = false
            }
        case .suspended(let info):
            await MainActor.run {
                banViewInfo = info
                isLoggingIn = false
                captchaToken = nil
                showCaptchaChallenge = false
            }
        }
    }

    func completeSession(_ session: WebSession) async {
        do {
            var resolvedSession = session
            if session.user == nil {
                let user = try await authRepository.validateSession()
                resolvedSession = WebSession(
                    token: session.token,
                    refreshToken: session.refreshToken,
                    user: user,
                    expiresAt: session.expiresAt
                )
            }
            await MainActor.run {
                authRepository.saveSession(resolvedSession)
                WebAuthService.shared.setSession(resolvedSession)
                resetAuthState()
            }
            await connectAfterLogin(token: resolvedSession.token)
        } catch {
            await setError("Session validation failed.", type: .unableToSignIn)
        }
    }

    private func connectAfterLogin(token: String) async {
        if api.gatewayURL.isEmpty {
            try? await api.discoverInstance(WebAuthService.webInstanceHost)
        }
        if !api.gatewayURL.isEmpty {
            WebSocketService.shared.setGatewayURL(api.gatewayURL)
        }
        WebSocketService.shared.connect(token: token)
        if let deviceToken = PushNotificationService.shared.deviceToken {
            try? await api.registerDeviceToken(token: deviceToken, platform: "ios")
        }
    }

    private func handleAuthFailure(_ failure: AuthFailure) async {
        await MainActor.run {
            isLoggingIn = false
            isStartingSso = false
            if !failure.fieldErrors.isEmpty {
                fieldErrors = failure.fieldErrors
                errorMessage = failure.message
            } else {
                errorMessage = failure.message
                fieldErrors = [:]
            }
            switch failure.kind {
            case .invalidCredentials: errorType = .invalidCredentials
            case .invalidEmail: errorType = .invalidEmail
            case .unableToSignIn: errorType = .unableToSignIn
            case .unableToCreateAccount: errorType = .unableToCreateAccount
            case .unableToSendResetLink: errorType = .unableToSendResetLink
            case .unableToResetPassword: errorType = .unableToResetPassword
            case .ssoFailed: errorType = .ssoFailed
            case .ssoCancelled: errorType = .ssoCancelled
            default: break
            }
        }
    }

    private func handleAPIError(_ error: APIError) async {
        switch error {
        case .captchaRequired(let sitekey, let service):
            await MainActor.run {
                startCaptchaChallenge(sitekey: sitekey, provider: service)
                isLoggingIn = false
            }
        case .unauthorized:
            await setError("Invalid email or password.", type: .invalidCredentials)
        case .serverError(_, let message):
            await setError(message ?? error.localizedDescription)
        default:
            await setError(error.localizedDescription)
        }
    }

    private func setError(_ message: String, type: LoginError? = nil) async {
        await MainActor.run {
            isLoggingIn = false
            isStartingSso = false
            errorMessage = message
            errorType = type
            fieldErrors = [:]
        }
    }

    private func clearErrors() {
        errorMessage = nil
        errorType = nil
        fieldErrors = [:]
    }

    private func resetAuthState() {
        email = ""
        password = ""
        isPasswordVisible = false
        isLoggingIn = false
        isStartingSso = false
        showCaptchaChallenge = false
        captchaToken = nil
        mfaChallenge = nil
        ipAuthChallenge = nil
        banViewInfo = nil
        showRegister = false
        showForgotPassword = false
        forgotPasswordEmailSent = false
        resetToken = nil
        usernameSuggestions = []
        errorMessage = nil
        errorType = nil
        fieldErrors = [:]
    }

    private func isValidEmail(_ email: String) -> Bool {
        guard let regex = try? Regex(#"^[^@\s]+@[^@\s]+\.[^@\s]+$"#) else { return false }
        return email.wholeMatch(of: regex) != nil
    }
}
