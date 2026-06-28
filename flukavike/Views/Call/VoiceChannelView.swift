//
//  VoiceChannelView.swift
//  Voice channel — participant grid, camera, screen share, mute controls.
//

import SwiftUI
import AVFoundation
import LiveKit

struct VoiceChannelView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let channel: Channel

    @State private var callService = FlukavikeCallService.shared
    @State private var isConnecting = true
    @State private var connectionError: String?
    @State private var participantRefreshTrigger = UUID()

    // Use participants from the service
    private var participants: [VoiceParticipant] {
        _ = participantRefreshTrigger
        return callService.voiceParticipants
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                GeometryReader { geo in
                    participantGrid(size: geo.size)
                }

                statusBar
                controlBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { Task { await join() } }
        .onDisappear { /* keep alive for PiP */ }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button(action: { leaveAndDismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            VStack(spacing: 2) {
                Text("🔊 \(channel.name)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                if isConnecting {
                    Text("Connecting…")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                } else if let err = connectionError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                } else {
                    let count = participants.count + 1
                    Text("\(count) \(count == 1 ? "person" : "people") in channel")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func participantGrid(size: CGSize) -> some View {
        let all = selfTile + participants.map { ParticipantInfo(from: $0, connection: callService.voiceConnection) }
        let cols = gridColumnCount(for: all.count)
        let hSpacing: CGFloat = 12
        let vSpacing: CGFloat = 12
        let itemW = (size.width - CGFloat(cols + 1) * hSpacing) / CGFloat(cols)
        let rows = ceil(Double(all.count) / Double(cols))
        let maxItemH = rows > 0 ? (size.height - CGFloat(rows + 1) * vSpacing) / CGFloat(rows) : size.height
        let itemH = min(itemW * 1.2, maxItemH)

        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: hSpacing), count: cols),
                spacing: vSpacing
            ) {
                ForEach(all) { info in
                    ParticipantTile(
                        info: info,
                        isSelf: info.isSelf
                    )
                    .frame(height: itemH)
                }
            }
            .padding(hSpacing)
        }
    }

    private var selfTile: [ParticipantInfo] {
        guard let me = appState.currentUser else { return [] }
        return [ParticipantInfo(
            id: me.id,
            user: me,
            isMuted: callService.isMuted,
            isDeafened: callService.isDeafened,
            isSpeaking: callService.isLocalSpeaking,
            isScreenSharing: callService.isScreenSharing,
            isSelf: true,
            cameraTrack: callService.voiceConnection?.localCameraTrack
        )]
    }

    private func gridColumnCount(for n: Int) -> Int {
        switch n {
        case 1: return 1
        case 2: return 2
        case 3, 4: return 2
        default: return 3
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        Group {
            if callService.isScreenSharing {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.on.rectangle.fill")
                    Text("You are sharing your screen")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(Color.red.opacity(0.8))
                .clipShape(Capsule())
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 0) {
            VoiceControlButton(
                icon: callService.isMuted ? "mic.slash.fill" : "mic.fill",
                label: callService.isMuted ? "Unmute" : "Mute",
                isActive: callService.isMuted,
                activeColor: .red
            ) {
                Task { try? await callService.toggleMute() }
            }

            VoiceControlButton(
                icon: callService.isDeafened ? "speaker.slash.fill" : "headphones",
                label: callService.isDeafened ? "Undeafen" : "Deafen",
                isActive: callService.isDeafened,
                activeColor: .red
            ) {
                Task { await callService.toggleDeafen() }
            }

            VoiceControlButton(
                icon: callService.isVideoEnabled ? "video.fill" : "video.slash.fill",
                label: callService.isVideoEnabled ? "Stop Video" : "Camera",
                isActive: callService.isVideoEnabled,
                activeColor: .white
            ) {
                callService.toggleCamera()
            }

            VoiceControlButton(
                icon: callService.isScreenSharing ? "rectangle.inset.filled.and.person.filled" : "rectangle.on.rectangle",
                label: callService.isScreenSharing ? "Stop Share" : "Share",
                isActive: callService.isScreenSharing,
                activeColor: .white
            ) {
                Task {
                    if callService.isScreenSharing {
                        do {
                            try await callService.stopScreenSharing()
                            await MainActor.run { connectionError = nil }
                        } catch {
                            await MainActor.run { connectionError = screenShareErrorMessage(error) }
                        }
                    } else {
                        do {
                            try await callService.startScreenSharing()
                            await MainActor.run { connectionError = nil }
                        } catch {
                            await MainActor.run { connectionError = screenShareErrorMessage(error) }
                        }
                    }
                }
            }

            VoiceControlButton(
                icon: "phone.down.fill",
                label: "Leave",
                isActive: true,
                activeColor: .red,
                isDestructive: true
            ) {
                leaveAndDismiss()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func join() async {
        isConnecting = true
        connectionError = nil

        do {
            if callService.selectedVoiceChannel?.id == channel.id,
               callService.voiceConnection?.room != nil {
                isConnecting = false
                return
            }

            callService.onParticipantsUpdated = {
                Task { @MainActor in
                    participantRefreshTrigger = UUID()
                }
            }

            callService.selectedVoiceChannel = channel
            try await callService.joinVoiceChannel(channel.id)

            isConnecting = false
        } catch {
            print("[VoiceChannel] Failed to join: \(error)")
            isConnecting = false
            if !callService.voiceParticipants.isEmpty || callService.voiceConnection?.room != nil {
                connectionError = nil
            } else {
                connectionError = "Failed to connect"
                callService.selectedVoiceChannel = nil
            }
        }
    }

    private func leaveAndDismiss() {
        Task {
            callService.onParticipantsUpdated = nil
            await callService.leaveVoiceChannel()
            dismiss()
        }
    }

    private func screenShareErrorMessage(_ error: Error) -> String {
        if case FlukavikeCallService.VoiceError.screenShareUnavailable(let message) = error {
            return message
        }
        return "Unable to start screen sharing."
    }
}

// MARK: - Participant Info

struct ParticipantInfo: Identifiable {
    let id: String
    let user: User
    let isMuted: Bool
    let isDeafened: Bool
    let isSpeaking: Bool
    let isScreenSharing: Bool
    let isSelf: Bool
    let cameraTrack: VideoTrack?
    let screenShareTrack: VideoTrack?

    init(
        id: String,
        user: User,
        isMuted: Bool,
        isDeafened: Bool,
        isSpeaking: Bool,
        isScreenSharing: Bool,
        isSelf: Bool,
        cameraTrack: VideoTrack? = nil,
        screenShareTrack: VideoTrack? = nil
    ) {
        self.id = id
        self.user = user
        self.isMuted = isMuted
        self.isDeafened = isDeafened
        self.isSpeaking = isSpeaking
        self.isScreenSharing = isScreenSharing
        self.isSelf = isSelf
        self.cameraTrack = cameraTrack
        self.screenShareTrack = screenShareTrack
    }

    init(from p: VoiceParticipant, connection: VoiceConnection?) {
        id = p.user.id
        user = p.user
        isMuted = p.voiceState.selfMute || p.voiceState.mute
        isDeafened = p.voiceState.selfDeaf || p.voiceState.deaf
        isSpeaking = p.isSpeaking
        isSelf = false

        let remoteParticipant = connection?.room?.remoteParticipants.values.first {
            $0.identity?.stringValue == p.user.id
        }
        screenShareTrack = remoteParticipant?.firstScreenShareVideoTrack
        cameraTrack = remoteParticipant?.firstCameraVideoTrack
        isScreenSharing = screenShareTrack != nil
    }
}

// MARK: - Participant Tile

struct ParticipantTile: View {
    let info: ParticipantInfo
    let isSelf: Bool

    private var participantLabel: String {
        if isSelf { return "You" }
        let display = info.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let display, !display.isEmpty { return display }
        let username = info.user.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { return username }
        return "Unknown user"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))

            if info.isSpeaking {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 3)
            }

            videoContent
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack {
                HStack {
                    Spacer()
                    if info.isScreenSharing {
                        Image(systemName: "rectangle.on.rectangle.fill")
                            .voiceBadge(color: .blue)
                            .accessibilityLabel("Screen sharing")
                    }
                }
                Spacer()
                HStack {
                    if info.isMuted {
                        Image(systemName: "mic.slash.fill")
                            .voiceBadge(color: .red)
                            .accessibilityLabel("Muted")
                    }
                    if info.isDeafened {
                        Image(systemName: "speaker.slash.fill")
                            .voiceBadge(color: .orange)
                            .accessibilityLabel("Deafened")
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(participantLabel)\(info.isSpeaking ? ", speaking" : "")\(info.isMuted ? ", muted" : "")\(info.isDeafened ? ", deafened" : "")\(info.isScreenSharing ? ", screen sharing" : "")")
    }

    @ViewBuilder
    private var videoContent: some View {
        if let screen = info.screenShareTrack {
            SwiftUIVideoView(screen, layoutMode: .fill)
        } else if let camera = info.cameraTrack {
            SwiftUIVideoView(camera, layoutMode: .fill)
        } else {
            VStack(spacing: 10) {
                AvatarView(user: info.user, size: 64, showStatus: false)

                Text(participantLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Voice Control Button

struct VoiceControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isDestructive ? .white : (isActive ? activeColor : Color.white.opacity(0.6)))
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(
                            isDestructive ? Color.red :
                            (isActive && activeColor != .white ? activeColor.opacity(0.2) : Color.white.opacity(0.1))
                        )
                    )

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Badge helper

extension Image {
    func voiceBadge(color: Color) -> some View {
        self.font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(6)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    let voiceChannel = Channel(id: "v1", serverId: "1", name: "General", topic: nil, type: .voice, position: 0, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: nil)
    VoiceChannelView(channel: voiceChannel)
        .environment(ThemeManager())
        .environment(AppState())
}
