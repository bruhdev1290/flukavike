//
//  APIService.swift
//  Flukavike HTTP API client
//

import Foundation

@Observable
class APIService {
    static let shared = APIService()
    static let fallbackHCaptchaSiteKey = "9cbad400-df84-4e0c-bda6-e65000be78aa"
    
    /// Default Fluxer web instance
    static let defaultInstance = "web.fluxer.app"
    
    private var authToken: String?
    private(set) var currentInstance: String = ""
    
    // Discovered endpoints (populated by discoverInstance or set manually)
    private(set) var apiBaseURL: String = ""
    private(set) var gatewayURL: String = ""
    private(set) var cdnURL: String = ""
    private(set) var webBaseURL: String = ""
    private(set) var captchaConfig: InstanceConfig.CaptchaConfig?
    
    var captchaRequired: Bool { captchaConfig != nil }
    
    private var baseURL: String { apiBaseURL }

    private var activeAuthToken: String? {
        WebAuthService.shared.authToken ?? authToken
    }

    private let blockedRequestHeaders: Set<String> = [
        "authorization",
        "connection",
        "content-length",
        "cookie",
        "host",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailer",
        "trailers",
        "transfer-encoding",
        "upgrade"
    ]
    
    // MARK: - Initialization
    
    init() {
        // Set default instance on initialization
        self.currentInstance = Self.defaultInstance
        // Use endpoints from the discovery document (matching Dart SDK)
        self.apiBaseURL = "https://api.fluxer.app/v1"
        self.webBaseURL = "https://web.fluxer.app"
        self.gatewayURL = "wss://gateway.fluxer.app"
    }
    
    // MARK: - URL Configuration
    
    /// Sets custom base URLs for an instance (used by WebAuthService after discovery)
    func setCustomBaseURLs(api: String, gateway: String, web: String) {
        self.apiBaseURL = api.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.gatewayURL = gateway
        self.webBaseURL = web.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    /// Clears the current captcha configuration
    func clearCaptchaConfig() {
        self.captchaConfig = nil
    }
    
    /// Resets to default Fluxer instance URLs
    func resetToDefaultInstance() {
        self.currentInstance = Self.defaultInstance
        self.apiBaseURL = "https://api.fluxer.app/v1"
        self.webBaseURL = "https://web.fluxer.app"
        self.gatewayURL = "wss://gateway.fluxer.app"
        self.captchaConfig = nil
    }
    
    private var urlSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }
    
    // MARK: - Authentication

    private struct AuthResponsePayload: Decodable {
        let token: String
        let refreshToken: String?
        let user: User?

        private enum CodingKeys: String, CodingKey {
            case token
            case accessToken = "access_token"
            case refreshToken
            case user
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            token = try container.decodeIfPresent(String.self, forKey: .token)
                ?? container.decode(String.self, forKey: .accessToken)
            refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
            user = try container.decodeIfPresent(User.self, forKey: .user)
        }
    }

    private struct AuthMfaRequiredPayload: Decodable {
        let mfa: Bool
        let ticket: String
        let allowedMethods: [String]

        private enum CodingKeys: String, CodingKey {
            case mfa
            case ticket
            case allowedMethods = "allowed_methods"
        }
    }

    private func decodeAuthResponse(from data: Data) async throws -> LoginResponse {
        let decoder = JSONDecoder.flukavike
        if let direct = try? decoder.decode(LoginResponse.self, from: data) {
            return direct
        }

        // Backend may return MFA-required response instead of a token payload.
        if let mfaPayload = try? decoder.decode(AuthMfaRequiredPayload.self, from: data), mfaPayload.mfa {
            throw APIError.mfaRequired(ticket: mfaPayload.ticket, allowedMethods: mfaPayload.allowedMethods)
        }

        let payload = try decoder.decode(AuthResponsePayload.self, from: data)

        // Some instances return token-only login payloads; fetch user profile explicitly.
        let resolvedUser: User
        if let user = payload.user {
            resolvedUser = user
        } else {
            setAuthToken(payload.token)
            resolvedUser = try await getCurrentUser()
        }

        return LoginResponse(
            token: payload.token,
            refreshToken: payload.refreshToken,
            user: resolvedUser
        )
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    func setInstance(_ instance: String) {
        let normalized = Self.normalizeInstance(instance)
        self.currentInstance = normalized
        // Default API URL until discovery overrides it
        self.apiBaseURL = "https://\(normalized)/api"
        self.webBaseURL = "https://\(normalized)"
    }
    
    /// Normalizes an instance string by stripping protocol, path, and trailing slashes.
    static func normalizeInstance(_ instance: String) -> String {
        var normalized = instance
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        // Strip protocol
        if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst("https://".count))
        } else if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst("http://".count))
        }
        
        // Strip path and trailing slashes
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[normalized.startIndex..<slashIndex])
        }
        
        return normalized
    }
    
    /// Extracts the base domain from an instance (e.g., "web.fluxer.app" → "fluxer.app")
    private static func baseDomain(of instance: String) -> String? {
        let parts = instance.split(separator: ".")
        guard parts.count > 2 else { return nil }
        return parts.dropFirst().joined(separator: ".")
    }
    
    // MARK: - Instance Discovery
    
    /// Discovers API endpoints from the instance's /.well-known/fluxer document.
    /// Tries the instance domain first, then falls back to api.{baseDomain}.
    func discoverInstance(_ instance: String) async throws {
        let normalized = Self.normalizeInstance(instance)
        self.currentInstance = normalized
        
        // Try discovery at the entered domain first
        if let config = try? await fetchWellKnown(host: normalized) {
            applyConfig(config)
            return
        }
        
        // If the domain has a subdomain (e.g., web.fluxer.app), try api.{baseDomain}
        if let base = Self.baseDomain(of: normalized) {
            if let config = try? await fetchWellKnown(host: "api.\(base)") {
                applyConfig(config)
                return
            }
            
            // Also try the bare base domain
            if let config = try? await fetchWellKnown(host: base) {
                applyConfig(config)
                return
            }
        }
        
        // Fallback: assume standard Fluxer layout with /v1 prefix
        self.apiBaseURL = "https://\(normalized)/v1"
        self.gatewayURL = ""
        self.cdnURL = ""
        self.webBaseURL = "https://\(normalized)"
        self.captchaConfig = nil
    }
    
    private func fetchWellKnown(host: String) async throws -> InstanceConfig {
        guard let url = URL(string: "https://\(host)/.well-known/fluxer") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        // Make sure we got JSON, not an HTML/JS SPA page
        if let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("text/html") {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder.flukavike.decode(InstanceConfig.self, from: data)
    }
    
    private func applyConfig(_ config: InstanceConfig) {
        self.apiBaseURL = config.api.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.gatewayURL = config.gateway
        self.cdnURL = config.cdn ?? ""
        self.webBaseURL = config.web?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "https://\(currentInstance)"
        if let configCaptcha = config.captcha {
            self.captchaConfig = InstanceConfig.CaptchaConfig(
                provider: configCaptcha.provider,
                sitekey: sanitizedCaptchaSiteKey(configCaptcha.sitekey) ?? Self.fallbackHCaptchaSiteKey
            )
        } else {
            self.captchaConfig = nil
        }
    }

    private func captchaDetails(from json: [String: Any]?) -> (sitekey: String?, service: String?) {
        guard let json else {
            return (nil, nil)
        }

        let nestedCaptcha = json["captcha"] as? [String: Any]

        let sitekey = [
            json["captcha_sitekey"],
            json["captcha_site_key"],
            json["sitekey"],
            json["site_key"],
            nestedCaptcha?["sitekey"],
            nestedCaptcha?["site_key"],
            nestedCaptcha?["key"]
        ]
            .compactMap { $0 as? String }
            .first { !$0.isEmpty }

        let service = [
            json["captcha_service"],
            json["captcha_provider"],
            json["service"],
            json["provider"],
            nestedCaptcha?["service"],
            nestedCaptcha?["provider"]
        ]
            .compactMap { $0 as? String }
            .first { !$0.isEmpty }

        return (sitekey, service)
    }

    private func sanitizedCaptchaSiteKey(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let filteredScalars = value.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) &&
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
        let sanitized = String(String.UnicodeScalarView(filteredScalars))
        return sanitized.isEmpty ? nil : sanitized
    }

    private func parseErrorCode(from json: [String: Any]?) -> String? {
        guard let json else { return nil }

        if let code = json["code"] as? String, !code.isEmpty {
            return code
        }
        if let code = json["code"] as? Int {
            return String(code)
        }

        if let nested = json["error"] as? [String: Any] {
            if let code = nested["code"] as? String, !code.isEmpty {
                return code
            }
            if let code = nested["code"] as? Int {
                return String(code)
            }
        }

        if let errorString = json["error"] as? String, !errorString.isEmpty {
            if isCaptchaMessage(errorString) {
                return "7"
            }
        }

        if let code = json["error_code"] as? String, !code.isEmpty {
            return code
        }
        if let code = json["error_code"] as? Int {
            return String(code)
        }

        return nil
    }

    private func parseErrorMessage(from json: [String: Any]?) -> String? {
        guard let json else { return nil }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let errorString = json["error"] as? String, !errorString.isEmpty {
            return errorString
        }
        if let nested = json["error"] as? [String: Any],
           let message = nested["message"] as? String,
           !message.isEmpty {
            return message
        }
        return nil
    }

    private func parseErrorData(from json: [String: Any]?) -> [String: Any]? {
        guard let json else { return nil }

        if let data = json["data"] as? [String: Any] {
            return data
        }

        if let error = json["error"] as? [String: Any],
           let data = error["data"] as? [String: Any] {
            return data
        }

        return nil
    }

    private func parseIpAuthorizationDetails(from json: [String: Any]?) -> (ticket: String?, email: String?, resendAvailableIn: Int?) {
        let data = parseErrorData(from: json)

        let ticket = (data?["ticket"] as? String)
        let email = (data?["email"] as? String)
        let resendAvailableIn = data?["resend_available_in"] as? Int

        return (ticket, email, resendAvailableIn)
    }

    private func isCaptchaMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower == "7" || lower.contains("captcha") || lower.contains("api error 7") {
            return true
        }

        // Normalize punctuation/spacing so variants like "API Error #7" still match.
        let normalized = lower.filter { $0.isLetter || $0.isNumber }
        return normalized.contains("apierror7")
    }

    private func isCaptchaErrorCode(_ code: String?) -> Bool {
        guard let code else { return false }
        let normalized = code.uppercased()
        return normalized == "CAPTCHA_REQUIRED"
            || code == "captcha-required"
            || normalized == "INVALID_CAPTCHA"
            || code == "7"
    }

    private func captchaTypeHeaderValue() -> String {
        let provider = captchaConfig?.provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return provider?.isEmpty == false ? provider! : "hcaptcha"
    }

    private func applyDefaultHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("mobile", forHTTPHeaderField: "X-Fluxer-Platform")

        // Match browser origin behavior expected by Fluxer API for auth/captcha enforcement.
        if !webBaseURL.isEmpty {
            request.setValue(webBaseURL, forHTTPHeaderField: "Origin")
        } else if !currentInstance.isEmpty {
            request.setValue("https://\(currentInstance)", forHTTPHeaderField: "Origin")
        }
    }

    private func sanitizeAdditionalHeaders(_ headers: [String: String], includeAuthorization: Bool) -> [String: String] {
        var sanitized: [String: String] = [:]

        for (header, value) in headers {
            let lowercasedHeader = header.lowercased()
            if blockedRequestHeaders.contains(lowercasedHeader) {
                if includeAuthorization && lowercasedHeader == "authorization" {
                    sanitized[header] = value
                }
                continue
            }

            sanitized[header] = value
        }

        return sanitized
    }
    
    // MARK: - Authentication
    
    func login(instance: String, login: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        // Run discovery before login to find the correct API URL
        try await discoverInstance(instance)
        
        var body: [String: String] = [
            "email": login,
            "password": password
        ]

        var headers: [String: String] = [:]
        if let captchaKey {
            body["captcha_key"] = captchaKey
            headers["X-Captcha-Token"] = captchaKey
            headers["X-Captcha-Type"] = captchaTypeHeaderValue()
        }
        let bodyData = try JSONEncoder.flukavike.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/login",
            method: "POST",
            body: bodyData,
            includeAuthorization: false,
            additionalHeaders: headers
        )

        do {
            return try await decodeAuthResponse(from: data)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func register(instance: String, username: String, email: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        // Run discovery before registration
        try await discoverInstance(instance)
        
        var body = [
            "username": username,
            "email": email,
            "password": password
        ]

        var headers: [String: String] = [:]
        if let captchaKey {
            body["captcha_key"] = captchaKey
            headers["X-Captcha-Token"] = captchaKey
            headers["X-Captcha-Type"] = captchaTypeHeaderValue()
        }
        let bodyData = try JSONEncoder.flukavike.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/register",
            method: "POST",
            body: bodyData,
            includeAuthorization: false,
            additionalHeaders: headers
        )

        do {
            return try await decodeAuthResponse(from: data)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func refreshToken(refreshToken: String) async throws -> RefreshResponse {
        let body = ["refresh_token": refreshToken]
        let bodyData = try JSONEncoder.flukavike.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/refresh",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.flukavike.decode(RefreshResponse.self, from: data)
    }
    
    func logout() async throws {
        _ = try await makeRequest(
            endpoint: "/auth/logout",
            method: "POST"
        )
    }
    
    private func makeRequest(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        includeAuthorization: Bool = true,
        additionalHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        applyDefaultHeaders(to: &request)
        
        if includeAuthorization {
            // Use session token from WebAuthService for authenticated requests
            if let token = activeAuthToken, !token.isEmpty {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }
        }

        let sanitizedHeaders = sanitizeAdditionalHeaders(additionalHeaders, includeAuthorization: includeAuthorization)
        for (header, value) in sanitizedHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        print("[API] \(method) \(url.absoluteString)")
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("[API] → \(httpResponse.statusCode)")

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let code = parseErrorCode(from: json)
        let message = parseErrorMessage(from: json)
        let rawBody = String(data: data, encoding: .utf8) ?? ""
        let normalizedCode = code?.uppercased()

        let messageText = message ?? ""
        let rawText = rawBody
        let captchaLikeMessage = isCaptchaMessage(messageText) || isCaptchaMessage(rawText)

        if normalizedCode == "IP_AUTHORIZATION_REQUIRED" {
            let details = parseIpAuthorizationDetails(from: json)
            throw APIError.ipAuthorizationRequired(
                ticket: details.ticket,
                email: details.email,
                resendAvailableIn: details.resendAvailableIn
            )
        }

        if isCaptchaErrorCode(code) || captchaLikeMessage {
            let details = captchaDetails(from: json)
            let sitekey = sanitizedCaptchaSiteKey(details.sitekey)
                ?? sanitizedCaptchaSiteKey(captchaConfig?.sitekey)
                ?? Self.fallbackHCaptchaSiteKey
            let service = details.service ?? captchaConfig?.provider
            throw APIError.captchaRequired(sitekey: sitekey, service: service)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 400:
            print("[API] Error 400: \(rawBody)")
            throw APIError.serverError(statusCode: 400, message: message)
        case 401:
            // Session expired or revoked — clear stored session so UI redirects to login
            await MainActor.run { WebAuthService.shared.clearSession() }
            throw APIError.unauthorized
        case 403:
            print("[API] Error 403: \(rawBody)")
            throw APIError.forbidden(message: message)
        case 404:
            print("[API] Error 404: \(url.absoluteString)")
            throw APIError.notFound
        case 429:
            print("[API] Error 429 (rate limited): \(rawBody)")
            throw APIError.rateLimited
        default:
            print("[API] Error \(httpResponse.statusCode): \(rawBody)")
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    // MARK: - User Endpoints
    
    func getCurrentUser() async throws -> User {
        let data = try await makeRequest(endpoint: "/users/@me")
        return try JSONDecoder.flukavike.decode(User.self, from: data)
    }
    
    func getUserGuilds() async throws -> [Server] {
        let data = try await makeRequest(endpoint: "/users/@me/guilds")
        return try JSONDecoder.flukavike.decode([Server].self, from: data)
    }
    
    // MARK: - Guild Endpoints
    
    func getGuild(id: String) async throws -> Server {
        let data = try await makeRequest(endpoint: "/guilds/\(id)")
        return try JSONDecoder.flukavike.decode(Server.self, from: data)
    }
    
    func getGuildChannels(guildId: String) async throws -> [Channel] {
        let data = try await makeRequest(endpoint: "/guilds/\(guildId)/channels")
        return try JSONDecoder.flukavike.decode([Channel].self, from: data)
    }
    
    // MARK: - Channel Endpoints
    
    func getChannel(id: String) async throws -> Channel {
        let data = try await makeRequest(endpoint: "/channels/\(id)")
        return try JSONDecoder.flukavike.decode(Channel.self, from: data)
    }
    
    func getMessages(channelId: String, before: String? = nil, limit: Int = 50) async throws -> [Message] {
        var endpoint = "/channels/\(channelId)/messages?limit=\(limit)"
        if let before = before {
            endpoint += "&before=\(before)"
        }
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder.flukavike.decode([Message].self, from: data)
    }
    
    func sendMessage(channelId: String, content: String) async throws -> Message {
        let body = ["content": content]
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(
            endpoint: "/channels/\(channelId)/messages",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.flukavike.decode(Message.self, from: data)
    }
    
    func sendVoiceMessage(
        channelId: String,
        audioURL: URL,
        duration: TimeInterval,
        waveform: [UInt8]
    ) async throws -> Message {
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/channels/\(channelId)/messages")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("mobile", forHTTPHeaderField: "X-Fluxer-Platform")
        if !webBaseURL.isEmpty {
            request.setValue(webBaseURL, forHTTPHeaderField: "Origin")
        } else if !currentInstance.isEmpty {
            request.setValue("https://\(currentInstance)", forHTTPHeaderField: "Origin")
        }
        
        if let token = activeAuthToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"voice_message.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add metadata
        let metadata: [String: Any] = [
            "duration": duration,
            "waveform": waveform
        ]
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"attachments_metadata\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder.flukavike.decode(Message.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Call Endpoints
    
    func createCall(channelId: String, type: FlukavikeCall.CallType) async throws -> FlukavikeCall {
        let body = ["type": type.rawValue]
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(
            endpoint: "/channels/\(channelId)/calls",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.flukavike.decode(FlukavikeCall.self, from: data)
    }
    
    func acceptCall(callId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/calls/\(callId)/accept",
            method: "POST"
        )
    }
    
    func endCall(callId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/calls/\(callId)",
            method: "DELETE"
        )
    }
    
    func updateCallState(callId: String, mute: Bool, video: Bool) async throws {
        let body: [String: Any] = [
            "mute": mute,
            "video": video
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await makeRequest(
            endpoint: "/calls/\(callId)/state",
            method: "PATCH",
            body: bodyData
        )
    }
    
    func startScreenShare(callId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/calls/\(callId)/screen-share",
            method: "POST"
        )
    }
    
    func stopScreenShare(callId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/calls/\(callId)/screen-share",
            method: "DELETE"
        )
    }
    
    // MARK: - Voice Endpoints
    
    func getVoiceToken(channelId: String) async throws -> VoiceTokenResponse {
        let data = try await makeRequest(endpoint: "/channels/\(channelId)/voice-token")
        return try JSONDecoder.flukavike.decode(VoiceTokenResponse.self, from: data)
    }
    
    // MARK: - Notification Endpoints
    
    func registerDeviceToken(token: String, platform: String = "ios") async throws {
        let body: [String: Any] = [
            "token": token,
            "platform": platform,
            "voip": true
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await makeRequest(
            endpoint: "/users/@me/devices",
            method: "POST",
            body: bodyData
        )
    }
    
    func markChannelRead(channelId: String, messageId: String) async throws {
        _ = try await makeRequest(
            endpoint: "/channels/\(channelId)/messages/\(messageId)/ack",
            method: "POST"
        )
    }
}

// MARK: - Instance Discovery Model

struct InstanceConfig: Decodable {
    let api: String
    let gateway: String
    let cdn: String?
    let publicApi: String?
    let web: String?
    let admin: String?
    let invite: String?
    let captcha: CaptchaConfig?
    
    // Extended fields for federation/instance discovery
    let name: String?
    let description: String?
    let icon: String?
    let banner: String?
    let publicInstance: Bool?
    let userCount: Int?
    let version: String?
    let features: [String]?
    
    enum CodingKeys: String, CodingKey {
        case api, gateway, cdn
        case publicApi = "public_api"
        case web, admin, invite, captcha
        case endpoints
        case name, description, icon, banner
        case publicInstance = "public_instance"
        case userCount = "user_count"
        case version, features
    }

    private struct EndpointsConfig: Decodable {
        let api: String?
        let apiClient: String?
        let apiPublic: String?
        let gateway: String?
        let media: String?
        let staticCdn: String?
        let webapp: String?
        let admin: String?
        let invite: String?

        enum CodingKeys: String, CodingKey {
            case api, gateway, media, admin, invite
            case apiClient = "api_client"
            case apiPublic = "api_public"
            case staticCdn = "static_cdn"
            case webapp
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let endpoints = try container.decodeIfPresent(EndpointsConfig.self, forKey: .endpoints)

        let resolvedApi =
            try container.decodeIfPresent(String.self, forKey: .api)
            ?? endpoints?.api
            ?? endpoints?.apiClient
            ?? endpoints?.apiPublic

        guard let api = resolvedApi else {
            throw DecodingError.keyNotFound(
                CodingKeys.api,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing API endpoint")
            )
        }

        self.api = api
        self.gateway =
            (try container.decodeIfPresent(String.self, forKey: .gateway))
            ?? endpoints?.gateway
            ?? ""
        self.cdn =
            (try container.decodeIfPresent(String.self, forKey: .cdn))
            ?? endpoints?.staticCdn
            ?? endpoints?.media
        self.publicApi =
            (try container.decodeIfPresent(String.self, forKey: .publicApi))
            ?? endpoints?.apiPublic
        self.web =
            (try container.decodeIfPresent(String.self, forKey: .web))
            ?? endpoints?.webapp
        self.admin =
            (try container.decodeIfPresent(String.self, forKey: .admin))
            ?? endpoints?.admin
        self.invite =
            (try container.decodeIfPresent(String.self, forKey: .invite))
            ?? endpoints?.invite
        self.captcha = try container.decodeIfPresent(CaptchaConfig.self, forKey: .captcha)

        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.banner = try container.decodeIfPresent(String.self, forKey: .banner)
        self.publicInstance = try container.decodeIfPresent(Bool.self, forKey: .publicInstance)
        self.userCount = try container.decodeIfPresent(Int.self, forKey: .userCount)
        self.version = try container.decodeIfPresent(String.self, forKey: .version)
        self.features = try container.decodeIfPresent([String].self, forKey: .features)
    }
    
    struct CaptchaConfig: Decodable {
        let provider: String
        let sitekey: String

        private enum CodingKeys: String, CodingKey {
            case provider
            case service
            case sitekey
            case siteKey
            case site_key
            case key
            case hcaptchaSiteKey = "hcaptcha_site_key"
            case turnstileSiteKey = "turnstile_site_key"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let explicitProvider = (try container.decodeIfPresent(String.self, forKey: .provider)
                ?? container.decodeIfPresent(String.self, forKey: .service)
                ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let hcaptchaSiteKey = try container.decodeIfPresent(String.self, forKey: .hcaptchaSiteKey)
            let turnstileSiteKey = try container.decodeIfPresent(String.self, forKey: .turnstileSiteKey)

            sitekey = try container.decodeIfPresent(String.self, forKey: .sitekey)
                ?? container.decodeIfPresent(String.self, forKey: .siteKey)
                ?? container.decodeIfPresent(String.self, forKey: .site_key)
                ?? container.decodeIfPresent(String.self, forKey: .key)
                ?? hcaptchaSiteKey
                ?? turnstileSiteKey
                ?? ""

            if explicitProvider.isEmpty || explicitProvider == "none" {
                if let turnstileSiteKey, !turnstileSiteKey.isEmpty {
                    provider = "turnstile"
                } else if let hcaptchaSiteKey, !hcaptchaSiteKey.isEmpty {
                    provider = "hcaptcha"
                } else {
                    provider = "hcaptcha"
                }
            } else {
                provider = explicitProvider
            }
        }

        init(provider: String, sitekey: String) {
            self.provider = provider
            self.sitekey = sitekey
        }
    }
}

// MARK: - Errors

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden(message: String?)
    case ipAuthorizationRequired(ticket: String?, email: String?, resendAvailableIn: Int?)
    case notFound
    case rateLimited
    case mfaRequired(ticket: String, allowedMethods: [String])
    case captchaRequired(sitekey: String?, service: String?)
    case serverError(statusCode: Int, message: String? = nil)
    case decodingError(Error)
    case discoveryFailed
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static var flukavike: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    static var flukavike: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
