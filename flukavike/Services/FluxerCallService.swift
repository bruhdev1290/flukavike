//
//  FluxerCallService.swift
//  Call handling using Fluxer API
//

import SwiftUI
import CallKit
import AVFoundation

@Observable
class FluxerCallService: NSObject {
    static let shared = FluxerCallService()
    
    private let callController = CXCallController()
    private var provider: CXProvider?
    private var apiService: APIService?
    private(set) var webSocketService: WebSocketService?
    
    // Current call state
    var activeCall: FluxerCall?
    var isMuted: Bool = false
    var isVideoEnabled: Bool = false
    var isScreenSharing: Bool = false
    var isDeafened: Bool = false
    
    // Voice connection
    var voiceConnection: VoiceConnection?
    var selectedVoiceChannel: Channel?
    
    // Callbacks
    var onCallConnected: (() -> Void)?
    var onCallEnded: (() -> Void)?
    var onParticipantJoined: ((VoiceParticipant) -> Void)?
    var onParticipantLeft: ((String) -> Void)?
    
    override init() {
        super.init()
        setupCallKit()
    }
    
    func configure(apiService: APIService, webSocketService: WebSocketService) {
        self.apiService = apiService
        self.webSocketService = webSocketService
        setupWebSocketHandlers()
    }
    
    // MARK: - CallKit Setup
    
    private func setupCallKit() {
        let configuration = CXProviderConfiguration(localizedName: "Fluxer")
        configuration.supportsVideo = true
        configuration.supportedHandleTypes = [.generic]
        configuration.ringtoneSound = "ringtone.caf"
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        
        provider = CXProvider(configuration: configuration)
        provider?.setDelegate(self, queue: nil)
    }
    
    // MARK: - WebSocket Handlers
    
    private func setupWebSocketHandlers() {
        webSocketService?.onCallCreate = { [weak self] call in
            self?.handleIncomingCall(call)
        }
        
        webSocketService?.onCallUpdate = { [weak self] call in
            self?.handleCallUpdate(call)
        }
        
        webSocketService?.onCallDelete = { [weak self] callId in
            self?.handleCallEnded(callId)
        }
        
        webSocketService?.onVoiceStateUpdate = { [weak self] voiceState in
            self?.handleVoiceStateUpdate(voiceState)
        }
        
        webSocketService?.onSpeaking = { [weak self] userId, speaking in
            self?.handleSpeakingUpdate(userId: userId, speaking: speaking)
        }
    }
    
    // MARK: - Incoming Calls
    
    private func handleIncomingCall(_ call: FluxerCall) {
        guard call.status == .ringing else { return }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.channelId)
        update.hasVideo = call.type == .video
        
        if let initiator = call.initiator {
            update.localizedCallerName = initiator.displayName ?? initiator.username
        }
        
        let callUUID = UUID(uuidString: call.id) ?? UUID()
        
        provider?.reportNewIncomingCall(
            with: callUUID,
            update: update
        ) { [weak self] error in
            if let error = error {
                print("Failed to report incoming call: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.activeCall = call
            }
        }
    }
    
    // MARK: - Start Call (via API)
    
    func startCall(channelId: String, type: FluxerCall.CallType) async throws {
        // Create call via Fluxer API
        // POST /channels/{channel.id}/calls
        let call = try await apiService?.createCall(channelId: channelId, type: type)
        
        guard let call = call else { return }
        
        let callUUID = UUID(uuidString: call.id) ?? UUID()
        let handle = CXHandle(type: .generic, value: channelId)
        
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        startCallAction.isVideo = type == .video
        
        let transaction = CXTransaction(action: startCallAction)
        
        try await callController.request(transaction)
        
        await MainActor.run {
            self.activeCall = call
            self.isVideoEnabled = type == .video
        }
    }
    
    // MARK: - Answer Call (via API)
    
    func answerCall() async throws {
        guard let call = activeCall else { return }
        
        // Accept call via API
        // POST /calls/{call.id}/accept
        try await apiService?.acceptCall(callId: call.id)
        
        // Join voice channel
        try await joinVoiceChannel(call.channelId)
        
        await MainActor.run {
            self.activeCall?.status = .ongoing
            self.onCallConnected?()
        }
    }
    
    // MARK: - End Call (via API)
    
    func endCall() async throws {
        guard let call = activeCall else { return }
        
        // End call via API
        // DELETE /calls/{call.id}
        try await apiService?.endCall(callId: call.id)
        
        // Leave voice channel
        await leaveVoiceChannel()
        
        let endAction = CXEndCallAction(call: UUID(uuidString: call.id) ?? UUID())
        let transaction = CXTransaction(action: endAction)
        
        try await callController.request(transaction)
        
        await MainActor.run {
            self.cleanupCall()
        }
    }
    
    // MARK: - Voice Channel Operations
    
    func joinVoiceChannel(_ channelId: String) async throws {
        // Get voice token and endpoint from API
        // GET /channels/{channel.id}/voice-token
        let voiceInfo = try await apiService?.getVoiceToken(channelId: channelId)
        
        guard let voiceInfo = voiceInfo else { return }
        
        // Connect to Fluxer voice gateway
        voiceConnection = VoiceConnection(
            endpoint: voiceInfo.endpoint,
            token: voiceInfo.token,
            sessionId: voiceInfo.sessionId,
            userId: voiceInfo.userId
        )
        
        try await voiceConnection?.connect()
        
        await MainActor.run {
            self.selectedVoiceChannel = Channel.previewChannels.first { $0.id == channelId }
        }
    }
    
    func leaveVoiceChannel() async {
        voiceConnection?.disconnect()
        voiceConnection = nil
        
        await MainActor.run {
            self.selectedVoiceChannel = nil
        }
    }
    
    // MARK: - Call Controls
    
    func toggleMute() async throws {
        guard let call = activeCall else { return }
        
        isMuted.toggle()
        
        // Update via API
        // PATCH /calls/{call.id}/mute
        try await apiService?.updateCallState(
            callId: call.id,
            mute: isMuted,
            video: isVideoEnabled
        )
        
        // Update CallKit
        let muteAction = CXSetMutedCallAction(
            call: UUID(uuidString: call.id) ?? UUID(),
            muted: isMuted
        )
        let transaction = CXTransaction(action: muteAction)
        try? await callController.request(transaction)
    }
    
    func toggleVideo() async throws {
        guard let call = activeCall else { return }
        
        isVideoEnabled.toggle()
        
        // Update via API
        try await apiService?.updateCallState(
            callId: call.id,
            mute: isMuted,
            video: isVideoEnabled
        )
        
        // Update CallKit
        let update = CXCallUpdate()
        update.hasVideo = isVideoEnabled
        provider?.reportCall(with: UUID(uuidString: call.id) ?? UUID(), updated: update)
    }
    
    func toggleDeafen() {
        isDeafened.toggle()
        voiceConnection?.setDeafen(isDeafened)
    }
    
    // MARK: - Screen Sharing
    
    func startScreenSharing() async throws {
        guard let call = activeCall else { return }
        
        // Request screen share via API
        // POST /calls/{call.id}/screen-share
        try await apiService?.startScreenShare(callId: call.id)
        
        await MainActor.run {
            self.isScreenSharing = true
        }
        
        // Trigger broadcast extension
        // This is handled by the UI layer showing RPSystemBroadcastPickerView
    }
    
    func stopScreenSharing() async throws {
        guard let call = activeCall else { return }
        
        // Stop via API
        // DELETE /calls/{call.id}/screen-share
        try await apiService?.stopScreenShare(callId: call.id)
        
        await MainActor.run {
            self.isScreenSharing = false
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleCallUpdate(_ call: FluxerCall) {
        DispatchQueue.main.async { [weak self] in
            if call.id == self?.activeCall?.id {
                self?.activeCall = call
            }
        }
    }
    
    private func handleCallEnded(_ callId: String) {
        guard activeCall?.id == callId else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.cleanupCall()
            self?.onCallEnded?()
        }
    }
    
    private func handleVoiceStateUpdate(_ voiceState: VoiceState) {
        // Update participant list
    }
    
    private func handleSpeakingUpdate(userId: String, speaking: Bool) {
        // Update speaking indicators
    }
    
    private func cleanupCall() {
        activeCall = nil
        isMuted = false
        isVideoEnabled = false
        isDeafened = false
        isScreenSharing = false
        voiceConnection?.disconnect()
        voiceConnection = nil
    }
}

// MARK: - CXProviderDelegate
extension FluxerCallService: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        Task {
            await leaveVoiceChannel()
            cleanupCall()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task {
            try? await answerCall()
            action.fulfill()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task {
            try? await endCall()
            action.fulfill()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task {
            isMuted = action.isMuted
            if let call = activeCall {
                try? await apiService?.updateCallState(
                    callId: call.id,
                    mute: isMuted,
                    video: isVideoEnabled
                )
            }
            action.fulfill()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task {
            // Outgoing call started via CallKit
            action.fulfill()
        }
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        voiceConnection?.audioSessionDidActivate(audioSession)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        voiceConnection?.audioSessionDidDeactivate(audioSession)
    }
}

// MARK: - Models

struct FluxerCall: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let guildId: String?
    let initiator: User?
    let participants: [User]
    let type: CallType
    var status: CallStatus
    let startedAt: Date
    var endedAt: Date?
    
    enum CallType: String, Codable {
        case voice
        case video
    }
    
    enum CallStatus: String, Codable {
        case ringing
        case ongoing
        case ended
        case missed
        case declined
    }
    
    var duration: TimeInterval {
        let end = endedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }
}

struct VoiceState: Codable {
    let userId: String
    let channelId: String?
    let guildId: String?
    let mute: Bool
    let deaf: Bool
    let selfMute: Bool
    let selfDeaf: Bool
    let suppress: Bool
    let requestToSpeakTimestamp: String?
}

struct VoiceParticipant: Identifiable {
    let id: String
    let user: User
    let voiceState: VoiceState
    var isSpeaking: Bool = false
}

struct VoiceTokenResponse: Codable {
    let endpoint: String
    let token: String
    let sessionId: String
    let userId: String
}

// MARK: - Voice Connection (Wraps WebRTC)
class VoiceConnection {
    let endpoint: String
    let token: String
    let sessionId: String
    let userId: String
    
    init(endpoint: String, token: String, sessionId: String, userId: String) {
        self.endpoint = endpoint
        self.token = token
        self.sessionId = sessionId
        self.userId = userId
    }
    
    func connect() async throws {
        // Connect to Fluxer voice gateway
        // Exchange SDP and ICE candidates
        // This uses WebRTC under the hood but via Fluxer protocol
    }
    
    func disconnect() {
        // Disconnect from voice gateway
    }
    
    func setDeafen(_ deafen: Bool) {
        // Update deafen state
    }
    
    func audioSessionDidActivate(_ session: AVAudioSession) {}
    func audioSessionDidDeactivate(_ session: AVAudioSession) {}
}
