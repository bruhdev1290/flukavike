//
//  WebSocketService.swift
//  Flukavike Gateway WebSocket client
//

import SwiftUI

@Observable
class WebSocketService: NSObject {
    static let shared = WebSocketService()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var gatewayURL = "wss://gateway.fluxer.app/?v=1&encoding=json"
    
    var isConnected: Bool = false
    var connectionState: ConnectionState = .disconnected
    
    // Heartbeat
    private var heartbeatInterval: TimeInterval = 30
    private var heartbeatTimer: Timer?
    private var sequenceNumber: Int?
    private var sessionId: String?
    
    // Reconnection
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 10
    private var reconnectTimer: Timer?
    private var shouldReconnect: Bool = false
    private var authToken: String?
    
    // Callbacks
    var onReady: ((GatewayReady) -> Void)?
    var onMessageCreate: ((Message) -> Void)?
    var onMessageUpdate: ((Message) -> Void)?
    var onMessageDelete: ((String) -> Void)?
    var onTypingStart: ((TypingEvent) -> Void)?
    var onPresenceUpdate: ((PresenceUpdate) -> Void)?
    var onCallCreate: ((FlukavikeCall) -> Void)?
    var onCallUpdate: ((FlukavikeCall) -> Void)?
    var onCallDelete: ((String) -> Void)?
    var onVoiceStateUpdate: ((VoiceState) -> Void)?
    var onSpeaking: ((String, Bool) -> Void)?
    var onNotification: ((AppNotification) -> Void)?
    var onConnectionStateChange: ((ConnectionState) -> Void)?
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case identifying
        case connected
        case reconnecting
        case error(String)
    }
    
    /// Updates the gateway URL (called after instance discovery)
    func setGatewayURL(_ url: String) {
        var wsURL = url
        // Ensure it has query params for encoding
        if !wsURL.contains("?") {
            wsURL += "/?v=1&encoding=json"
        }
        self.gatewayURL = wsURL
    }
    
    // MARK: - Connection
    
    func connect(token: String) {
        self.authToken = token
        self.shouldReconnect = true
        
        guard webSocketTask == nil else {
            // Already connected or connecting
            return
        }
        
        connectionState = .connecting
        notifyConnectionStateChange()
        
        guard let url = URL(string: gatewayURL) else {
            connectionState = .error("Invalid gateway URL")
            notifyConnectionStateChange()
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: request)
        
        receiveMessage()
        webSocketTask?.resume()
    }
    
    func disconnect() {
        shouldReconnect = false
        reconnectAttempts = 0
        invalidateTimers()
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        connectionState = .disconnected
        notifyConnectionStateChange()
    }
    
    func reconnect() {
        guard shouldReconnect, let token = authToken else { return }
        
        webSocketTask = nil
        connectionState = .reconnecting
        notifyConnectionStateChange()
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        reconnectAttempts += 1
        
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect(token: token)
        }
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.receiveMessage() // Continue receiving
                
            case .failure(let error):
                self?.handleError(error)
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }
        
        guard let data = text.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        guard let op = payload["op"] as? Int else { return }
        
        switch op {
        case 0: // Dispatch
            handleDispatch(payload)
            
        case 1: // Heartbeat
            sendHeartbeat()
            
        case 10: // Hello
            handleHello(payload)
            
        case 11: // Heartbeat ACK
            // Heartbeat acknowledged
            break
            
        case 7: // Reconnect
            handleReconnect()
            
        case 9: // Invalid Session
            handleInvalidSession()
            
        default:
            break
        }
    }
    
    private func handleDispatch(_ payload: [String: Any]) {
        guard let eventType = payload["t"] as? String else { return }
        
        sequenceNumber = payload["s"] as? Int
        
        guard let eventData = payload["d"] as? [String: Any] else { return }
        
        switch eventType {
        case "READY":
            handleReady(eventData)
            
        case "MESSAGE_CREATE":
            if let message = try? decode(Message.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onMessageCreate?(message)
                }
            }
            
        case "MESSAGE_UPDATE":
            if let message = try? decode(Message.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onMessageUpdate?(message)
                }
            }
            
        case "MESSAGE_DELETE":
            if let id = eventData["id"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.onMessageDelete?(id)
                }
            }
            
        case "TYPING_START":
            if let event = try? decode(TypingEvent.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onTypingStart?(event)
                }
            }
            
        case "PRESENCE_UPDATE":
            if let update = try? decode(PresenceUpdate.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onPresenceUpdate?(update)
                }
            }
            
        case "CALL_CREATE":
            if let call = try? decode(FlukavikeCall.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onCallCreate?(call)
                }
            }
            
        case "CALL_UPDATE":
            if let call = try? decode(FlukavikeCall.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onCallUpdate?(call)
                }
            }
            
        case "CALL_DELETE":
            if let id = eventData["id"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.onCallDelete?(id)
                }
            }
            
        case "VOICE_STATE_UPDATE":
            if let state = try? decode(VoiceState.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onVoiceStateUpdate?(state)
                }
            }
            
        case "SPEAKING":
            if let userId = eventData["user_id"] as? String,
               let speaking = eventData["speaking"] as? Bool {
                DispatchQueue.main.async { [weak self] in
                    self?.onSpeaking?(userId, speaking)
                }
            }
            
        case "NOTIFICATION_CREATE":
            if let notification = try? decode(AppNotification.self, from: eventData) {
                DispatchQueue.main.async { [weak self] in
                    self?.onNotification?(notification)
                }
            }
            
        default:
            break
        }
    }
    
    private func handleHello(_ payload: [String: Any]) {
        guard let data = payload["d"] as? [String: Any],
              let interval = data["heartbeat_interval"] as? TimeInterval else {
            return
        }
        
        heartbeatInterval = interval / 1000 // Convert to seconds
        startHeartbeat()
        
        // Send identify or resume
        connectionState = .identifying
        notifyConnectionStateChange()
        
        if sessionId != nil && sequenceNumber != nil && reconnectAttempts > 0 {
            sendResume()
        } else {
            sendIdentify()
        }
    }
    
    private func handleReady(_ data: [String: Any]) {
        reconnectAttempts = 0 // Reset on successful connection
        
        if let sessionId = data["session_id"] as? String {
            self.sessionId = sessionId
        }
        
        if let ready = try? decode(GatewayReady.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = true
                self?.connectionState = .connected
                self?.notifyConnectionStateChange()
                self?.onReady?(ready)
            }
        }
    }
    
    private func handleInvalidSession() {
        sessionId = nil
        sequenceNumber = nil
        connectionState = .error("Invalid session")
        notifyConnectionStateChange()
        
        // Re-identify after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.sendIdentify()
        }
    }
    
    private func handleReconnect() {
        connectionState = .reconnecting
        notifyConnectionStateChange()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        reconnect()
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.connectionState = .error(error.localizedDescription)
            self?.notifyConnectionStateChange()
            self?.webSocketTask = nil
            self?.reconnect()
        }
    }
    
    // MARK: - Outgoing Messages
    
    private func sendIdentify() {
        guard let token = authToken else { return }
        
        let identify: [String: Any] = [
            "op": 2,
            "d": [
                "token": token,
                "properties": [
                    "os": "iOS",
                    "browser": "Flukavike Mobile",
                    "device": UIDevice.current.model
                ],
                "compress": false,
                "large_threshold": 250
            ]
        ]
        
        sendJSON(identify)
    }
    
    private func sendResume() {
        guard let token = authToken, let sessionId = sessionId else { return }
        
        let resume: [String: Any] = [
            "op": 6,
            "d": [
                "token": token,
                "session_id": sessionId,
                "seq": sequenceNumber ?? 0
            ]
        ]
        
        sendJSON(resume)
    }
    
    private func sendHeartbeat() {
        let heartbeat: [String: Any] = [
            "op": 1,
            "d": sequenceNumber ?? NSNull()
        ]
        
        sendJSON(heartbeat)
    }
    
    func sendTyping(channelId: String) {
        let typing: [String: Any] = [
            "op": 4,
            "d": [
                "channel_id": channelId
            ]
        ]
        
        sendJSON(typing)
    }
    
    func updatePresence(status: UserStatus, customStatus: String?) {
        let presence: [String: Any] = [
            "op": 3,
            "d": [
                "status": status.rawValue.lowercased(),
                "custom_status": customStatus as Any,
                "since": NSNull(),
                "activities": [],
                "afk": false
            ]
        ]
        
        sendJSON(presence)
    }
    
    func requestGuildMembers(guildId: String, query: String = "", limit: Int = 0) {
        let request: [String: Any] = [
            "op": 8,
            "d": [
                "guild_id": guildId,
                "query": query,
                "limit": limit
            ]
        ]
        
        sendJSON(request)
    }
    
    func updateVoiceState(guildId: String?, channelId: String?, selfMute: Bool = false, selfDeaf: Bool = false) {
        let voiceState: [String: Any] = [
            "op": 4,
            "d": [
                "guild_id": guildId as Any,
                "channel_id": channelId as Any,
                "self_mute": selfMute,
                "self_deaf": selfDeaf
            ]
        ]
        
        sendJSON(voiceState)
    }
    
    // MARK: - Helpers
    
    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func startHeartbeat() {
        invalidateHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func invalidateHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func invalidateTimers() {
        invalidateHeartbeat()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func notifyConnectionStateChange() {
        DispatchQueue.main.async { [weak self] in
            if let state = self?.connectionState {
                self?.onConnectionStateChange?(state)
            }
        }
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder.flukavike.decode(type, from: data)
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketService: URLSessionWebSocketDelegate {
    
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // Connection opened, wait for Hello
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionWebSocketTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            handleError(error)
        } else {
            // Clean disconnect
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                self?.webSocketTask = nil
                if self?.shouldReconnect == true {
                    self?.reconnect()
                } else {
                    self?.connectionState = .disconnected
                    self?.notifyConnectionStateChange()
                }
            }
        }
    }
}

// MARK: - Gateway Models

struct GatewayReady: Decodable {
    let version: Int
    let user: User
    let guilds: [Server]
    let sessionId: String
    let resumeGatewayUrl: String?
    let shard: [Int]?
}

struct TypingEvent: Codable {
    let channelId: String
    let guildId: String?
    let userId: String
    let timestamp: Int
}

struct PresenceUpdate: Codable {
    let user: User
    let status: String
    let customStatus: String?
    let clientStatus: ClientStatus?
    
    struct ClientStatus: Codable {
        let desktop: String?
        let mobile: String?
        let web: String?
    }
}
