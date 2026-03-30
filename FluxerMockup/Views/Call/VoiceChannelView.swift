//
//  VoiceChannelView.swift
//  Voice channel using Fluxer API
//

import SwiftUI

struct VoiceChannelView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let channel: Channel
    @State private var callService = FluxerCallService.shared
    @State private var participants: [VoiceParticipant] = []
    @State private var isConnecting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status
                if isConnecting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(themeManager.backgroundSecondary(colorScheme))
                }
                
                // Participant Grid
                participantGrid
                
                // Bottom Controls
                bottomControls
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Leave") {
                        leaveChannel()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            joinChannel()
        }
        .onDisappear {
            // Don't leave automatically - user might be in PiP
        }
    }
    
    // MARK: - Participant Grid
    private var participantGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: gridColumns,
                spacing: 16
            ) {
                // Add self first
                participantTile(
                    user: callService.webSocketService?.connectionState == .connected ? User.preview : User.preview,
                    isMuted: callService.isMuted,
                    isVideoEnabled: false,
                    isScreenSharing: callService.isScreenSharing,
                    isSpeaking: false
                )
                
                ForEach(participants) { participant in
                    participantTile(
                        user: participant.user,
                        isMuted: participant.voiceState.selfMute || participant.voiceState.mute,
                        isVideoEnabled: false, // Video not yet in voice channels
                        isScreenSharing: false,
                        isSpeaking: participant.isSpeaking
                    )
                }
            }
            .padding(16)
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = max(participants.count + 1, 2) // +1 for self
        if count <= 2 {
            return [GridItem(.flexible()), GridItem(.flexible())]
        } else if count <= 4 {
            return [GridItem(.flexible()), GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    private func participantTile(
        user: User,
        isMuted: Bool,
        isVideoEnabled: Bool,
        isScreenSharing: Bool,
        isSpeaking: Bool
    ) -> some View {
        ZStack {
            // Video or Avatar
            if isVideoEnabled {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        Text("Video")
                            .foregroundStyle(.white)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.backgroundSecondary(colorScheme))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        ZStack {
                            // Speaking indicator ring
                            if isSpeaking {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeManager.accentColor.color, lineWidth: 3)
                            }
                            
                            VStack(spacing: 12) {
                                AvatarView(user: user, size: 60, showStatus: false)
                                
                                Text(user.formattedName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                    .lineLimit(1)
                            }
                        }
                    )
            }
            
            // Status badges
            VStack {
                HStack {
                    Spacer()
                    
                    if isScreenSharing {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                
                HStack {
                    if isMuted {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeManager.separator(colorScheme))
            
            HStack(spacing: 20) {
                // Mute
                ControlButton(
                    icon: callService.isMuted ? "mic.slash.fill" : "mic.fill",
                    color: callService.isMuted ? .red : themeManager.accentColor.color,
                    action: {
                        Task {
                            try? await callService.toggleMute()
                        }
                    }
                )
                
                // Deafen
                ControlButton(
                    icon: callService.isDeafened ? "speaker.slash.fill" : "headphones",
                    color: callService.isDeafened ? .red : themeManager.accentColor.color,
                    action: {
                        callService.toggleDeafen()
                    }
                )
                
                // Video (for future DM calls in voice channels)
                // ControlButton(
                //     icon: "video.fill",
                //     color: .gray,
                //     action: {}
                // )
                
                // Screen Share
                ControlButton(
                    icon: callService.isScreenSharing ? "rectangle.inset.filled.and.person.filled" : "rectangle.on.rectangle",
                    color: callService.isScreenSharing ? .red : themeManager.accentColor.color,
                    action: {
                        Task {
                            if callService.isScreenSharing {
                                try? await callService.stopScreenSharing()
                            } else {
                                try? await callService.startScreenSharing()
                            }
                        }
                    }
                )
                
                // Disconnect
                Button(action: leaveChannel) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(themeManager.backgroundSecondary(colorScheme))
    }
    
    // MARK: - Actions
    
    private func joinChannel() {
        Task {
            isConnecting = true
            do {
                try await callService.joinVoiceChannel(channel.id)
                isConnecting = false
            } catch {
                isConnecting = false
                print("Failed to join voice channel: \(error)")
            }
        }
    }
    
    private func leaveChannel() {
        Task {
            await callService.leaveVoiceChannel()
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    VoiceChannelView(channel: Channel.previewChannels[4])
        .environment(ThemeManager())
}
