//
//  AuthModels.swift
//  Authentication models matching the Flutter client
//

import Foundation

// MARK: - Auth Session

/// Minimal session representation used by the auth repository.
struct AuthSession: Codable {
    let token: String
    let userId: String
}

// MARK: - Login Result

enum LoginResult {
    case success(WebSession)
    case mfaRequired(MfaChallenge)
    case ipAuthRequired(IpAuthorizationChallenge)
    case suspended(BanViewInfo)
}

// MARK: - MFA

enum MfaMethod: String, Codable, CaseIterable {
    case totp
    case sms
    case webauthn
}

struct MfaChallenge: Codable {
    let ticket: String
    let totp: Bool
    let sms: Bool
    let webauthn: Bool
    let smsPhoneHint: String?

    var availableMethods: [MfaMethod] {
        var methods: [MfaMethod] = []
        if totp { methods.append(.totp) }
        if sms { methods.append(.sms) }
        if webauthn { methods.append(.webauthn) }
        return methods
    }

    var hasMultipleMethods: Bool {
        availableMethods.count > 1
    }
}

// MARK: - IP Authorization

struct IpAuthorizationChallenge: Codable {
    let ticket: String
    let email: String
    let resendAvailableIn: Int
}

enum IpAuthPollResult {
    case pending
    case completed(WebSession)
    case expired
}

// MARK: - Account Suspension

struct BanViewInfo: Codable {
    let token: String
    let banType: BanType
}

enum BanType: String, Codable {
    case ban
    case temporaryBan = "temporary_ban"
    case suspension
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = BanType(rawValue: raw) ?? .unknown
    }
}

// MARK: - Auth Failure

struct AuthFailure: Error, LocalizedError {
    enum Kind {
        case generic
        case invalidCredentials
        case invalidEmail
        case unableToSignIn
        case unableToCreateAccount
        case unableToSendResetLink
        case unableToResetPassword
        case ssoFailed
        case ssoCancelled
    }

    let message: String
    let fieldErrors: [String: String]
    let kind: Kind

    init(
        _ message: String,
        fieldErrors: [String: String] = [:],
        kind: Kind = .generic
    ) {
        self.message = message
        self.fieldErrors = fieldErrors
        self.kind = kind
    }

    var errorDescription: String? { message }
}

enum LoginError: String, CaseIterable {
    case invalidEmail
    case invalidCredentials
    case unableToSignIn
    case unableToCreateAccount
    case unableToSendResetLink
    case unableToResetPassword
    case ssoFailed
    case ssoCancelled
}

// MARK: - SSO

struct SsoStartResponse: Decodable {
    let authorizationUrl: String
}

struct SsoCompleteResponse: Decodable {
    let token: String
    let userId: String
    let user: User?
}

// MARK: - Token Response

struct TokenWithUserResponse: Decodable {
    let token: String
    let userId: String?
    let refreshToken: String?
    let user: User?
}

// MARK: - MFA API Response

struct MfaRequiredResponse: Decodable {
    let mfa: Bool
    let ticket: String
    let totp: Bool?
    let sms: Bool?
    let webauthn: Bool?
    let smsPhoneHint: String?
}
