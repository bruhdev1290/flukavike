//
//  AuthRepository.swift
//  Unified authentication repository matching the Flutter client
//

import Foundation
import AuthenticationServices

/// Coordinates all authentication REST calls and session persistence.
@Observable
class AuthRepository: NSObject {
    static let shared = AuthRepository()

    private let api = APIService.shared
    private var webAuthSession: ASWebAuthenticationSession?

    private override init() {}

    // MARK: - Session Persistence

    func saveSession(_ session: WebSession) {
        AuthSessionStore.saveSession(session)
        api.setAuthToken(session.token)
    }

    func loadSession() -> WebSession? {
        AuthSessionStore.loadSession()
    }

    func deleteSession() {
        AuthSessionStore.deleteSession()
        api.setAuthToken("")
    }

    // MARK: - Login / Register / Reset

    func login(
        instance: String,
        email: String,
        password: String,
        captchaKey: String? = nil,
        inviteCode: String? = nil
    ) async throws -> LoginResult {
        do {
            let data = try await api.loginRaw(
                instance: instance,
                email: email,
                password: password,
                captchaKey: captchaKey,
                inviteCode: inviteCode
            )
            return try parseAuthResponse(data)
        } catch let error as APIError {
            if case .captchaRequired = error { throw error }
            if let ip = extractIpAuthChallenge(from: error) {
                return .ipAuthRequired(ip)
            }
            throw authFailure(from: error)
        }
    }

    func register(
        instance: String,
        email: String,
        password: String,
        dateOfBirth: String,
        username: String? = nil,
        displayName: String? = nil,
        inviteCode: String? = nil,
        captchaKey: String? = nil
    ) async throws -> LoginResult {
        do {
            let data = try await api.registerRaw(
                instance: instance,
                email: email,
                password: password,
                dateOfBirth: dateOfBirth,
                username: username,
                displayName: displayName,
                inviteCode: inviteCode,
                captchaKey: captchaKey
            )
            return try parseAuthResponse(data)
        } catch let error as APIError {
            if case .captchaRequired = error { throw error }
            if let ip = extractIpAuthChallenge(from: error) {
                return .ipAuthRequired(ip)
            }
            throw authFailure(from: error)
        }
    }

    func forgotPassword(email: String) async throws {
        do {
            try await api.forgotPassword(email: email)
        } catch let error as APIError {
            throw authFailure(from: error)
        }
    }

    func resetPassword(token: String, password: String) async throws -> LoginResult {
        do {
            let data = try await api.resetPassword(token: token, password: password)
            return try parseAuthResponse(data)
        } catch let error as APIError {
            if let ip = extractIpAuthChallenge(from: error) {
                return .ipAuthRequired(ip)
            }
            throw authFailure(from: error)
        }
    }

    func getUsernameSuggestions(globalName: String) async throws -> [String] {
        try await api.getUsernameSuggestions(globalName: globalName)
    }

    // MARK: - MFA

    func verifyMfaTotp(ticket: String, code: String) async throws -> WebSession {
        let data = try await api.verifyMfaTotp(ticket: ticket, code: code)
        return try decodeTokenSession(data)
    }

    func verifyMfaSms(ticket: String, code: String) async throws -> WebSession {
        let data = try await api.verifyMfaSms(ticket: ticket, code: code)
        return try decodeTokenSession(data)
    }

    func sendMfaSms(ticket: String) async throws {
        try await api.sendMfaSms(ticket: ticket)
    }

    func getMfaWebauthnOptions(ticket: String) async throws -> [String: Any] {
        try await api.getMfaWebauthnOptions(ticket: ticket)
    }

    func verifyMfaWebauthn(ticket: String, response: [String: Any], challenge: String) async throws -> WebSession {
        let data = try await api.verifyMfaWebauthn(ticket: ticket, response: response, challenge: challenge)
        return try decodeTokenSession(data)
    }

    // MARK: - IP Authorization

    func pollIpAuthorization(ticket: String) async throws -> IpAuthPollResult {
        do {
            let data = try await api.pollIpAuthorization(ticket: ticket)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if json?["completed"] as? Bool == true,
               let token = json?["token"] as? String,
               let userId = json?["user_id"] as? String {
                let session = WebSession(token: token, refreshToken: nil, user: nil, expiresAt: nil)
                return .completed(session)
            }
            return .pending
        } catch let error as APIError {
            if case .serverError(let code, _) = error, code == 400 {
                return .expired
            }
            throw authFailure(from: error)
        }
    }

    func resendIpAuthorization(ticket: String) async throws {
        try await api.resendIpAuthorization(ticket: ticket)
    }

    // MARK: - SSO

    func startSso(redirectTo: String? = nil) async throws -> SsoStartResponse {
        try await api.startSso(redirectTo: redirectTo)
    }

    func completeSso(code: String, state: String) async throws -> WebSession {
        let data = try await api.completeSso(code: code, state: state)
        return try decodeTokenSession(data)
    }

    func authenticateWithSso(authorizationUrl: String) async throws -> SsoCallback {
        guard let url = URL(string: authorizationUrl) else {
            throw AuthFailure("Invalid SSO URL.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "flukavike"
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                if let error = error as NSError? {
                    if error.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthFailure("SSO cancelled.", kind: .ssoCancelled))
                    } else {
                        continuation.resume(throwing: AuthFailure(error.localizedDescription, kind: .ssoFailed))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthFailure("No SSO callback received.", kind: .ssoFailed))
                    return
                }
                let params = callbackURL.queryParameters ?? [:]
                guard let code = params["code"], let state = params["state"] else {
                    continuation.resume(throwing: AuthFailure("Invalid SSO callback.", kind: .ssoFailed))
                    return
                }
                continuation.resume(returning: SsoCallback(code: code, state: state))
            }
            session.presentationContextProvider = self
            self.webAuthSession = session
            session.start()
        }
    }

    // MARK: - Passkeys

    func getPasskeyLoginOptions() async throws -> [String: Any] {
        try await api.getPasskeyLoginOptions()
    }

    func loginWithPasskey(response: [String: Any], challenge: String) async throws -> LoginResult {
        do {
            let data = try await api.loginWithPasskey(response: response, challenge: challenge)
            return try parseAuthResponse(data)
        } catch let error as APIError {
            if case .captchaRequired = error { throw error }
            if let ip = extractIpAuthChallenge(from: error) {
                return .ipAuthRequired(ip)
            }
            throw authFailure(from: error)
        }
    }

    // MARK: - Validation

    func validateSession() async throws -> User {
        try await api.getCurrentUser()
    }

    // MARK: - Response Parsing

    private func parseAuthResponse(_ data: Data) throws -> LoginResult {
        let decoder = JSONDecoder.flukavike

        // 1. Try token response
        if let tokenResponse = try? decoder.decode(TokenWithUserResponse.self, from: data) {
            return .success(session(from: tokenResponse))
        }

        // 2. Try MFA response
        if let mfaResponse = try? decoder.decode(MfaRequiredResponse.self, from: data), mfaResponse.mfa {
            return .mfaRequired(MfaChallenge(
                ticket: mfaResponse.ticket,
                totp: mfaResponse.totp ?? false,
                sms: mfaResponse.sms ?? false,
                webauthn: mfaResponse.webauthn ?? false,
                smsPhoneHint: mfaResponse.smsPhoneHint
            ))
        }

        // 3. Try suspension / ban
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let banToken = json?["ban_view_token"] as? String,
           let banTypeRaw = json?["ban_type"] as? String {
            return .suspended(BanViewInfo(
                token: banToken,
                banType: BanType(rawValue: banTypeRaw) ?? .unknown
            ))
        }

        throw AuthFailure("Unexpected response from Fluxer.")
    }

    private func decodeTokenSession(_ data: Data) throws -> WebSession {
        if let tokenResponse = try? JSONDecoder.flukavike.decode(TokenWithUserResponse.self, from: data) {
            return session(from: tokenResponse)
        }
        throw AuthFailure("Unable to decode session.")
    }

    private func session(from response: TokenWithUserResponse) -> WebSession {
        WebSession(
            token: response.token,
            refreshToken: response.refreshToken,
            user: response.user,
            expiresAt: nil
        )
    }

    private func resolveUserId(from response: TokenWithUserResponse) async throws -> String {
        if let userId = response.userId, !userId.isEmpty {
            return userId
        }
        if let user = response.user {
            return user.id
        }
        let user = try await api.getCurrentUser()
        return user.id
    }

    private func extractIpAuthChallenge(from error: APIError) -> IpAuthorizationChallenge? {
        guard case .ipAuthorizationRequired(let ticket, let email, let resend) = error else { return nil }
        guard let ticket, !ticket.isEmpty, let email, !email.isEmpty else { return nil }
        return IpAuthorizationChallenge(
            ticket: ticket,
            email: email,
            resendAvailableIn: resend ?? 30
        )
    }

    private func authFailure(from error: APIError) -> AuthFailure {
        switch error {
        case .unauthorized:
            return AuthFailure("Invalid email or password.", kind: .invalidCredentials)
        case .forbidden(let message):
            return AuthFailure(message ?? "Access denied.")
        case .rateLimited:
            return AuthFailure("Too many attempts. Please wait and try again.")
        case .serverError(_, let message):
            return AuthFailure(message ?? "Server error. Please try again.")
        case .invalidURL:
            return AuthFailure("Could not connect to server. Check the instance URL.")
        case .invalidResponse:
            return AuthFailure("No response from server. Check your network connection.")
        case .captchaRequired:
            return AuthFailure("Captcha required.")
        case .discoveryFailed:
            return AuthFailure("Could not connect to Fluxer. Please try again.")
        default:
            return AuthFailure(error.localizedDescription)
        }
    }
}

// MARK: - SSO Callback

struct SsoCallback {
    let code: String
    let state: String
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthRepository: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
