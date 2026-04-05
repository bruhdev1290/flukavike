//
//  FlukavikeCallService.swift
//  Call handling using Flukavike API
//

import SwiftUI
import CallKit
import AVFoundation

@Observable
class FlukavikeCallService: NSObject {
    static let shared = FlukavikeCallService()
    
    private let callController = CXCallController()
    private var provider: CXProvider?
    private var apiService: APIService?
    private(set) var webSocketService: WebSocketService?
    private var appState: AppState?
    
    // Current call state
    var activeCall: FlukavikeCall?
    var isMuted: Bool = false
    var isVideoEnabled: Bool = false
    var isScreenSharing: Bool = false
    var isDeafened: Bool = false
    
    // Voice connection
    var voiceConnection: VoiceConnection?
    var selectedVoiceChannel: Channel?
    
    // Voice participants (shared state for UI)
    @MainActor var voiceParticipants: [VoiceParticipant] = []
    
    // Callbacks
    var onCallConnected: (() -> Void)?
    var onCallEnded: (() -> Void)?
    var onParticipantJoined: ((VoiceParticipant) -> Void)?
    var onParticipantLeft: ((String) -> Void)?
    var onParticipantsUpdated: (() -> Void)?
    
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
        let configuration = CXProviderConfiguration(localizedName: "Flukavike")
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
    
    private func handleIncomingCall(_ call: FlukavikeCall) {
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
    
    func startCall(channelId: String, type: FlukavikeCall.CallType) async throws {
        // Create call via Flukavike API
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
        // Step 1: Send gateway op 4 to join the voice channel
        // The gateway will respond with VOICE_SERVER_UPDATE containing LiveKit token + endpoint
        guard let ws = webSocketService else { throw VoiceError.notConnected }
        
        // Get the guildId for this channel if available
        let guildId = findGuildIdForChannel(channelId)
        print("[Voice] Joining channel \(channelId) in guild \(guildId ?? "none")")
        
        ws.sendVoiceStateUpdate(channelId: channelId, guildId: guildId)

        // Step 2: Wait for VOICE_SERVER_UPDATE (up to 10 seconds)
        // Try both channelId and guildId as keys since different servers send different IDs
        let voiceServer: VoiceServerUpdate = try await withTimeout(seconds: 10) {
            // First try waiting for the channel-specific update
            do {
                return try await ws.waitForVoiceServerUpdate(channelId: channelId)
            } catch {
                // If that fails, try guild-based lookup if we have a guildId
                if let guildId = guildId {
                    print("[Voice] Trying guild-based lookup for \(guildId)")
                    return try await ws.waitForVoiceServerUpdate(channelId: guildId)
                }
                throw error
            }
        }
        
        print("[Voice] Got voice server update, endpoint: \(voiceServer.endpoint)")

        // Step 3: Connect to LiveKit using the token and endpoint from the gateway
        let conn = VoiceConnection(endpoint: voiceServer.endpoint, token: voiceServer.token)
        voiceConnection = conn
        try await conn.connect()
        
        print("[Voice] Connected to LiveKit")

        await MainActor.run { self.isMuted = false }
    }
    
    private func findGuildIdForChannel(_ channelId: String) -> String? {
        // First check the selected voice channel's server
        if let selectedServerId = selectedVoiceChannel?.serverId, !selectedServerId.isEmpty {
            return selectedServerId
        }
        return webSocketService?.currentGuildId
    }

    enum VoiceError: Error {
        case notConnected
        case timeout
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw VoiceError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    func leaveVoiceChannel() async {
        voiceConnection?.disconnect()
        voiceConnection = nil
        // Tell gateway we left (op 4 with channel_id: null)
        webSocketService?.sendVoiceLeave(guildId: webSocketService?.currentGuildId)
        await MainActor.run { 
            self.selectedVoiceChannel = nil 
            self.voiceParticipants = []
        }
    }
    
    // MARK: - Call Controls
    
    func toggleMute() async throws {
        isMuted.toggle()
        voiceConnection?.setMute(isMuted)
        if let call = activeCall {
            try? await apiService?.updateCallState(callId: call.id, mute: isMuted, video: isVideoEnabled)
            let muteAction = CXSetMutedCallAction(call: UUID(uuidString: call.id) ?? UUID(), muted: isMuted)
            try? await callController.request(CXTransaction(action: muteAction))
        }
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

    // MARK: - Camera

    func toggleCamera() {
        isVideoEnabled.toggle()
        if isVideoEnabled {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted { self.isVideoEnabled = false; return }
                    self.voiceConnection?.setCamera(true)
                }
            }
        } else {
            voiceConnection?.setCamera(false)
        }
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
    
    private func handleCallUpdate(_ call: FlukavikeCall) {
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
        Task { @MainActor in
            // Channel ID is nil when user leaves the channel
            guard let channelId = voiceState.channelId else {
                // User left - remove from participants
                voiceParticipants.removeAll { $0.id == voiceState.userId }
                onParticipantLeft?(voiceState.userId)
                onParticipantsUpdated?()
                return
            }
            
            // Check if this update is for our current channel
            guard channelId == selectedVoiceChannel?.id else { return }
            
            // Check if participant already exists
            if let index = voiceParticipants.firstIndex(where: { $0.id == voiceState.userId }) {
                // Update existing participant
                let participant = voiceParticipants[index]
                let updatedParticipant = VoiceParticipant(
                    id: participant.id,
                    user: participant.user,
                    voiceState: voiceState,
                    isSpeaking: participant.isSpeaking
                )
                voiceParticipants[index] = updatedParticipant
            } else {
                // New participant - use member info from voice state if available
                let user: User
                if let member = voiceState.member, let memberUser = member.user {
                    user = memberUser
                } else {
                    // Create a placeholder user - will be updated when we fetch channel info
                    user = User(
                        id: voiceState.userId,
                        username: "user_\(voiceState.userId.suffix(4))",
                        displayName: nil,
                        avatarUrl: nil,
                        bannerUrl: nil,
                        bio: nil,
                        status: .offline,
                        customStatus: nil,
                        bot: false,
                        createdAt: Date()
                    )
                }
                let newParticipant = VoiceParticipant(
                    id: voiceState.userId,
                    user: user,
                    voiceState: voiceState
                )
                voiceParticipants.append(newParticipant)
                onParticipantJoined?(newParticipant)
            }
            onParticipantsUpdated?()
        }
    }
    
    private func handleSpeakingUpdate(userId: String, speaking: Bool) {
        Task { @MainActor in
            if let index = voiceParticipants.firstIndex(where: { $0.id == userId }) {
                let participant = voiceParticipants[index]
                voiceParticipants[index] = VoiceParticipant(
                    id: participant.id,
                    user: participant.user,
                    voiceState: participant.voiceState,
                    isSpeaking: speaking
                )
                onParticipantsUpdated?()
            }
        }
    }
    
    /// Fetch current voice channel participants from API
    func fetchVoiceChannelParticipants(channelId: String) async throws -> [VoiceParticipant] {
        // Try to get participants via the channel info endpoint
        let data = try await apiService?.makeRequest(endpoint: "/channels/\(channelId)")
        guard let data = data else { return [] }
        
        // Parse the response to get voice_states if available
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let voiceStates = json["voice_states"] as? [[String: Any]] {
            
            var participants: [VoiceParticipant] = []
            for state in voiceStates {
                guard let userId = state["user_id"] as? String else { continue }
                
                // Try to get user info from the voice state
                let user: User
                if let userObj = state["user"] as? [String: Any],
                   let userData = try? JSONSerialization.data(withJSONObject: userObj),
                   let parsedUser = try? JSONDecoder.flukavike.decode(User.self, from: userData) {
                    user = parsedUser
                } else {
                    // Create placeholder
                    user = User(
                        id: userId,
                        username: "user_\(userId.prefix(4))",
                        displayName: nil,
                        avatarUrl: nil,
                        bannerUrl: nil,
                        bio: nil,
                        status: .offline,
                        customStatus: nil,
                        bot: false,
                        createdAt: Date()
                    )
                }
                
                // Create voice state from the data we have
                let participantVoiceState = VoiceState(
                    userId: userId,
                    channelId: channelId,
                    guildId: nil,
                    mute: state["mute"] as? Bool ?? false,
                    deaf: state["deaf"] as? Bool ?? false,
                    selfMute: state["self_mute"] as? Bool ?? false,
                    selfDeaf: state["self_deaf"] as? Bool ?? false,
                    suppress: state["suppress"] as? Bool ?? false,
                    requestToSpeakTimestamp: state["request_to_speak_timestamp"] as? String,
                    member: nil
                )
                let participant = VoiceParticipant(
                    id: userId,
                    user: user,
                    voiceState: participantVoiceState
                )
                participants.append(participant)
            }
            
            await MainActor.run {
                self.voiceParticipants = participants
                self.onParticipantsUpdated?()
            }
            return participants
        }
        return []
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
extension FlukavikeCallService: CXProviderDelegate {
    
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
        // LiveKit handles audio session activation internally once SDK is integrated
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // LiveKit handles audio session deactivation internally once SDK is integrated
    }
}

// MARK: - Models

struct FlukavikeCall: Identifiable, Codable, Equatable {
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

struct VoiceState: Decodable {
    let userId: String
    let channelId: String?
    let guildId: String?
    let mute: Bool
    let deaf: Bool
    let selfMute: Bool
    let selfDeaf: Bool
    let suppress: Bool
    let requestToSpeakTimestamp: String?
    /// The member object may be included in gateway VOICE_STATE_UPDATE events
    let member: GuildMemberResponse?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case channelId = "channel_id"
        case guildId = "guild_id"
        case mute
        case deaf
        case selfMute = "self_mute"
        case selfDeaf = "self_deaf"
        case suppress
        case requestToSpeakTimestamp = "request_to_speak_timestamp"
        case member
    }
    
    init(userId: String, channelId: String?, guildId: String?, mute: Bool, deaf: Bool, selfMute: Bool, selfDeaf: Bool, suppress: Bool, requestToSpeakTimestamp: String?, member: GuildMemberResponse?) {
        self.userId = userId
        self.channelId = channelId
        self.guildId = guildId
        self.mute = mute
        self.deaf = deaf
        self.selfMute = selfMute
        self.selfDeaf = selfDeaf
        self.suppress = suppress
        self.requestToSpeakTimestamp = requestToSpeakTimestamp
        self.member = member
    }
}

struct VoiceParticipant: Identifiable {
    let id: String
    let user: User
    let voiceState: VoiceState
    var isSpeaking: Bool = false
}

/// Received from the gateway after sending op 4 (VOICE_STATE_UPDATE).
/// Contains the LiveKit JWT and endpoint needed to connect.
struct VoiceServerUpdate: Codable {
    let token: String
    let endpoint: String
    let guildId: String?
    let channelId: String?   // present for DM calls
    let connectionId: String?
}

// Fluxer REST response for POST /channels/{id}/voice/token
struct VoiceTokenResponse: Codable {
    let endpoint: String
    let token: String
    let connectionId: String?  // "connection_id"
    let tokenNonce: String?    // "token_nonce"
    // Legacy fields kept for fallback compatibility
    let sessionId: String?
    let userId: String?
}

// MARK: - Voice Connection (LiveKit)
import LiveKit

class VoiceConnection {
    let endpoint: String
    let token: String
    private(set) var room: Room?

    init(endpoint: String, token: String) {
        self.endpoint = endpoint
        self.token = token
    }

    func connect() async throws {
        let room = Room()
        self.room = room
        let connectOptions = ConnectOptions(autoSubscribe: true)
        let roomOptions = RoomOptions(
            defaultAudioCaptureOptions: AudioCaptureOptions(echoCancellation: true, noiseSuppression: true)
        )
        try await room.connect(url: endpoint, token: token, connectOptions: connectOptions, roomOptions: roomOptions)
        try await room.localParticipant.setMicrophone(enabled: true)
    }

    func disconnect() {
        Task { await room?.disconnect() }
        room = nil
    }

    func setMute(_ muted: Bool) {
        Task { try? await room?.localParticipant.setMicrophone(enabled: !muted) }
    }

    func setCamera(_ enabled: Bool) {
        Task { try? await room?.localParticipant.setCamera(enabled: enabled) }
    }

    func setDeafen(_ deafened: Bool) {
        // Set output volume to 0 when deafened via AVAudioSession
        let volume: Float = deafened ? 0 : 1
        try? AVAudioSession.sharedInstance().setActive(true)
        // LiveKit doesn't expose per-track mute for remote audio from the receiver side;
        // deafen is handled at the audio output level
        _ = volume // volume control requires AVAudioPlayer or system API
    }
}
