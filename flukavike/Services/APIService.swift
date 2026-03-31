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
    
    // MARK: - Initialization
    
    init() {
        // Set default instance on initialization
        self.currentInstance = Self.defaultInstance
        self.apiBaseURL = "https://api.fluxer.app"
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
        self.apiBaseURL = "https://api.fluxer.app"
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
        
        // Fallback: assume standard layout
        self.apiBaseURL = "https://\(normalized)/api"
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
    
    // MARK: - Authentication
    
    func login(instance: String, login: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        // Run discovery before login to find the correct API URL
        try await discoverInstance(instance)
        
        var body: [String: String] = [
            "login": login,
            "password": password
        ]
        if let captchaKey {
            body["captcha_key"] = captchaKey
        }
        let bodyData = try JSONEncoder.flukavike.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/login",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.flukavike.decode(LoginResponse.self, from: data)
    }
    
    func register(instance: String, username: String, email: String, password: String, captchaKey: String? = nil) async throws -> LoginResponse {
        // Run discovery before registration
        try await discoverInstance(instance)
        
        var body = [
            "username": username,
            "email": email,
            "password": password
        ]
        if let captchaKey {
            body["captcha_key"] = captchaKey
        }
        let bodyData = try JSONEncoder.flukavike.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/register",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.flukavike.decode(LoginResponse.self, from: data)
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
        body: Data? = nil
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set Origin header to match the web frontend (required by Fluxer API)
        if !webBaseURL.isEmpty {
            request.setValue(webBaseURL, forHTTPHeaderField: "Origin")
        } else if !currentInstance.isEmpty {
            request.setValue("https://\(currentInstance)", forHTTPHeaderField: "Origin")
        }
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 400:
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let code = json?["code"] as? String
            if code == "CAPTCHA_REQUIRED" || code == "captcha-required" {
                let details = captchaDetails(from: json)
                let sitekey = sanitizedCaptchaSiteKey(details.sitekey)
                    ?? sanitizedCaptchaSiteKey(captchaConfig?.sitekey)
                    ?? Self.fallbackHCaptchaSiteKey
                let service = details.service ?? captchaConfig?.provider
                throw APIError.captchaRequired(sitekey: sitekey, service: service)
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[API] Error 400: \(errorBody)")
            let message = json?["message"] as? String
            throw APIError.serverError(statusCode: 400, message: message)
        case 401:
            throw APIError.unauthorized
        case 403:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw APIError.forbidden(message: message)
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[API] Error \(httpResponse.statusCode): \(errorBody)")
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
        
        if !webBaseURL.isEmpty {
            request.setValue(webBaseURL, forHTTPHeaderField: "Origin")
        } else if !currentInstance.isEmpty {
            request.setValue("https://\(currentInstance)", forHTTPHeaderField: "Origin")
        }
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        case name, description, icon, banner
        case publicInstance = "public_instance"
        case userCount = "user_count"
        case version, features
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
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            provider = try container.decodeIfPresent(String.self, forKey: .provider)
                ?? container.decodeIfPresent(String.self, forKey: .service)
                ?? "hcaptcha"

            sitekey = try container.decodeIfPresent(String.self, forKey: .sitekey)
                ?? container.decodeIfPresent(String.self, forKey: .siteKey)
                ?? container.decodeIfPresent(String.self, forKey: .site_key)
                ?? container.decodeIfPresent(String.self, forKey: .key)
                ?? ""
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
    case notFound
    case rateLimited
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
