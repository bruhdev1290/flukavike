//
//  APIService.swift
//  Fluxer HTTP API client
//

import Foundation

@Observable
class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://api.fluxer.app/v1"
    private var authToken: String?
    private var currentInstance: String = "fluxer.app"
    
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
        self.currentInstance = instance
    }
    
    func login(instance: String, username: String, password: String) async throws -> LoginResponse {
        setInstance(instance)
        let body = [
            "username": username,
            "password": password
        ]
        let bodyData = try JSONEncoder.fluxer.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/login",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.fluxer.decode(LoginResponse.self, from: data)
    }
    
    func register(instance: String, username: String, email: String, password: String) async throws -> LoginResponse {
        setInstance(instance)
        let body = [
            "username": username,
            "email": email,
            "password": password
        ]
        let bodyData = try JSONEncoder.fluxer.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/register",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.fluxer.decode(LoginResponse.self, from: data)
    }
    
    func refreshToken(refreshToken: String) async throws -> RefreshResponse {
        let body = ["refresh_token": refreshToken]
        let bodyData = try JSONEncoder.fluxer.encode(body)
        let data = try await makeRequest(
            endpoint: "/auth/refresh",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.fluxer.decode(RefreshResponse.self, from: data)
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
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - User Endpoints
    
    func getCurrentUser() async throws -> User {
        let data = try await makeRequest(endpoint: "/users/@me")
        return try JSONDecoder.fluxer.decode(User.self, from: data)
    }
    
    func getUserGuilds() async throws -> [Server] {
        let data = try await makeRequest(endpoint: "/users/@me/guilds")
        return try JSONDecoder.fluxer.decode([Server].self, from: data)
    }
    
    // MARK: - Guild Endpoints
    
    func getGuild(id: String) async throws -> Server {
        let data = try await makeRequest(endpoint: "/guilds/\(id)")
        return try JSONDecoder.fluxer.decode(Server.self, from: data)
    }
    
    func getGuildChannels(guildId: String) async throws -> [Channel] {
        let data = try await makeRequest(endpoint: "/guilds/\(guildId)/channels")
        return try JSONDecoder.fluxer.decode([Channel].self, from: data)
    }
    
    // MARK: - Channel Endpoints
    
    func getChannel(id: String) async throws -> Channel {
        let data = try await makeRequest(endpoint: "/channels/\(id)")
        return try JSONDecoder.fluxer.decode(Channel.self, from: data)
    }
    
    func getMessages(channelId: String, before: String? = nil, limit: Int = 50) async throws -> [Message] {
        var endpoint = "/channels/\(channelId)/messages?limit=\(limit)"
        if let before = before {
            endpoint += "&before=\(before)"
        }
        let data = try await makeRequest(endpoint: endpoint)
        return try JSONDecoder.fluxer.decode([Message].self, from: data)
    }
    
    func sendMessage(channelId: String, content: String) async throws -> Message {
        let body = ["content": content]
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(
            endpoint: "/channels/\(channelId)/messages",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.fluxer.decode(Message.self, from: data)
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
            return try JSONDecoder.fluxer.decode(Message.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Call Endpoints
    
    func createCall(channelId: String, type: FluxerCall.CallType) async throws -> FluxerCall {
        let body = ["type": type.rawValue]
        let bodyData = try JSONEncoder().encode(body)
        let data = try await makeRequest(
            endpoint: "/channels/\(channelId)/calls",
            method: "POST",
            body: bodyData
        )
        return try JSONDecoder.fluxer.decode(FluxerCall.self, from: data)
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
        return try JSONDecoder.fluxer.decode(VoiceTokenResponse.self, from: data)
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

// MARK: - Errors

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(statusCode: Int)
    case decodingError(Error)
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static var fluxer: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    static var fluxer: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
