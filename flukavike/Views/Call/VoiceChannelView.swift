//
//  VoiceChannelView.swift
//  Voice channel — participant grid, camera, screen share, mute controls.
//

import SwiftUI
import AVFoundation

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
        _ = participantRefreshTrigger  // Dependency to trigger refresh
        return callService.voiceParticipants
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar area
                navBar

                // Participant grid
                GeometryReader { geo in
                    participantGrid(size: geo.size)
                }

                // Status bar
                statusBar

                // Bottom controls
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
                    let count = participants.count + 1 // +1 for self
                    Text("\(count) \(count == 1 ? "person" : "people") in channel")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            // Empty spacer to balance layout
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func participantGrid(size: CGSize) -> some View {
        let all = selfTile + participants.map { ParticipantInfo(from: $0) }
        let cols = gridColumnCount(for: all.count)
        let itemW = (size.width - CGFloat(cols + 1) * 12) / CGFloat(cols)
        let itemH = min(itemW * 1.2, (size.height - 20) / CGFloat(ceil(Double(all.count) / Double(cols))))

        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: cols),
                spacing: 12
            ) {
                ForEach(all) { info in
                    ParticipantTile(
                        info: info,
                        isSelf: info.isSelf,
                        showCamera: info.isSelf && callService.isVideoEnabled
                    )
                    .frame(height: itemH)
                }
            }
            .padding(12)
        }
    }

    private var selfTile: [ParticipantInfo] {
        guard let me = appState.currentUser else { return [] }
        return [ParticipantInfo(
            id: me.id,
            user: me,
            isMuted: callService.isMuted,
            isDeafened: callService.isDeafened,
            isSpeaking: false,
            isScreenSharing: callService.isScreenSharing,
            isSelf: true
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
            // Mute
            VoiceControlButton(
                icon: callService.isMuted ? "mic.slash.fill" : "mic.fill",
                label: callService.isMuted ? "Unmute" : "Mute",
                isActive: callService.isMuted,
                activeColor: .red
            ) {
                Task { try? await callService.toggleMute() }
            }

            // Deafen
            VoiceControlButton(
                icon: callService.isDeafened ? "speaker.slash.fill" : "headphones",
                label: callService.isDeafened ? "Undeafen" : "Deafen",
                isActive: callService.isDeafened,
                activeColor: .red
            ) {
                callService.toggleDeafen()
            }

            // Camera
            VoiceControlButton(
                icon: callService.isVideoEnabled ? "video.fill" : "video.slash.fill",
                label: callService.isVideoEnabled ? "Stop Video" : "Camera",
                isActive: callService.isVideoEnabled,
                activeColor: .white
            ) {
                callService.toggleCamera()
            }

            // Screen Share
            VoiceControlButton(
                icon: callService.isScreenSharing ? "rectangle.inset.filled.and.person.filled" : "rectangle.on.rectangle",
                label: callService.isScreenSharing ? "Stop Share" : "Share",
                isActive: callService.isScreenSharing,
                activeColor: .white
            ) {
                Task {
                    if callService.isScreenSharing {
                        try? await callService.stopScreenSharing()
                    } else {
                        try? await callService.startScreenSharing()
                    }
                }
            }

            // Disconnect
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
            // Set up callback for participant updates
            callService.onParticipantsUpdated = { 
                // Force UI refresh when participants change
                Task { @MainActor in
                    participantRefreshTrigger = UUID()
                }
            }
            
            // Fetch existing participants first
            _ = try? await callService.fetchVoiceChannelParticipants(channelId: channel.id)
            
            // Join the voice channel
            try await callService.joinVoiceChannel(channel.id)
            
            // Store selected channel in service
            callService.selectedVoiceChannel = channel
            
            isConnecting = false
        } catch {
            isConnecting = false
            connectionError = "Failed to connect"
        }
    }

    private func leaveAndDismiss() {
        Task {
            callService.onParticipantsUpdated = nil
            await callService.leaveVoiceChannel()
            dismiss()
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Participant Info (display model)

struct ParticipantInfo: Identifiable {
    let id: String
    let user: User
    let isMuted: Bool
    let isDeafened: Bool
    let isSpeaking: Bool
    let isScreenSharing: Bool
    let isSelf: Bool

    init(id: String, user: User, isMuted: Bool, isDeafened: Bool, isSpeaking: Bool, isScreenSharing: Bool, isSelf: Bool) {
        self.id = id; self.user = user; self.isMuted = isMuted
        self.isDeafened = isDeafened; self.isSpeaking = isSpeaking
        self.isScreenSharing = isScreenSharing; self.isSelf = isSelf
    }

    init(from p: VoiceParticipant) {
        id = p.user.id; user = p.user
        isMuted = p.voiceState.selfMute || p.voiceState.mute
        isDeafened = p.voiceState.selfDeaf || p.voiceState.deaf
        isSpeaking = p.isSpeaking; isScreenSharing = false; isSelf = false
    }
}

// MARK: - Participant Tile

struct ParticipantTile: View {
    let info: ParticipantInfo
    let isSelf: Bool
    let showCamera: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))

            // Speaking ring
            if info.isSpeaking {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 3)
            }

            if showCamera {
                // Live camera preview for self
                LocalCameraPreview()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    AvatarView(user: info.user, size: 64, showStatus: false)

                    Text(isSelf ? "You" : info.user.formattedName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            // Badges (top-right)
            VStack {
                HStack {
                    Spacer()
                    if info.isScreenSharing {
                        Image(systemName: "rectangle.on.rectangle.fill")
                            .voiceBadge(color: .blue)
                    }
                }
                Spacer()
                HStack {
                    // Mute badge (bottom-left)
                    if info.isMuted {
                        Image(systemName: "mic.slash.fill")
                            .voiceBadge(color: .red)
                    }
                    if info.isDeafened {
                        Image(systemName: "speaker.slash.fill")
                            .voiceBadge(color: .orange)
                    }
                    Spacer()
                }
            }
            .padding(10)
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
    }
}

// MARK: - Local Camera Preview

struct LocalCameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }
        session.addInput(input)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer
        context.coordinator.session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.layer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
        var session: AVCaptureSession?
        deinit { session?.stopRunning() }
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
