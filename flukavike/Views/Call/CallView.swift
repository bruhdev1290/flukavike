//
//  CallView.swift
//  Active call interface using Flukavike API
//

import SwiftUI

struct CallView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var callService = FlukavikeCallService.shared
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Background
            themeManager.backgroundPrimary(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video Grid (or avatar if voice only)
                videoGrid
                
                Spacer()
                
                // Call Info
                callInfoSection
                    .padding(.bottom, 40)
                
                // Controls
                controlsSection
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Video Grid
    private var videoGrid: some View {
        GeometryReader { geometry in
            ZStack {
                // Remote video (main)
                if callService.isVideoEnabled {
                    // VideoView() - Shows remote participant
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.black)
                        .overlay(
                            VStack {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.gray)
                                Text("Video Feed")
                                    .foregroundStyle(.white)
                            }
                        )
                } else {
                    // Avatar view for voice call
                    remoteAvatarView
                }
                
                // Local video (picture-in-picture)
                if callService.isVideoEnabled {
                    VStack {
                        HStack {
                            Spacer()
                            
                            // LocalVideoView()
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 120, height: 160)
                                .overlay(
                                    VStack {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white)
                                        Text("You")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                )
                                .padding(20)
                        }
                        Spacer()
                    }
                }
                
                // Screen share indicator
                if callService.isScreenSharing {
                    VStack {
                        HStack {
                            Label("Sharing Screen", systemImage: "rectangle.inset.filled.and.person.filled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                            
                            Spacer()
                        }
                        .padding(20)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var remoteAvatarView: some View {
        VStack(spacing: 20) {
            if let initiator = callService.activeCall?.initiator {
                // Large avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.accentColor.color.opacity(0.8),
                                    themeManager.accentColor.color.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                    
                    Text(initiator.formattedName.prefix(1))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(initiator.formattedName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
            } else {
                // Group call placeholder
                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(themeManager.accentColor.color)
            }
        }
    }
    
    // MARK: - Call Info
    private var callInfoSection: some View {
        VStack(spacing: 8) {
            if let call = callService.activeCall {
                Text(callStateText)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                
                if call.status == .ongoing {
                    Text(formattedDuration)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .monospacedDigit()
                }
            }
        }
    }
    
    private var callStateText: String {
        switch callService.activeCall?.status {
        case .ringing:
            return "Connecting..."
        case .ongoing:
            return callService.isScreenSharing ? "Screen Sharing" : "Connected"
        case .ended:
            return "Call Ended"
        case .missed:
            return "Missed Call"
        case .declined:
            return "Declined"
        case .none:
            return ""
        }
    }
    
    private var formattedDuration: String {
        let duration = callService.activeCall?.duration ?? 0
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Trigger UI update for duration
        }
    }
    
    // MARK: - Controls
    private var controlsSection: some View {
        HStack(spacing: 32) {
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
            
            // Video (only for video calls)
            if callService.activeCall?.type == .video {
                ControlButton(
                    icon: callService.isVideoEnabled ? "video.fill" : "video.slash.fill",
                    color: callService.isVideoEnabled ? themeManager.accentColor.color : .gray,
                    action: {
                        Task {
                            try? await callService.toggleVideo()
                        }
                    }
                )
            }
            
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
            
            // Speaker / Flip Camera
            ControlButton(
                icon: callService.isVideoEnabled ? "camera.rotate.fill" : "speaker.wave.3.fill",
                color: themeManager.accentColor.color,
                action: {}
            )
            
            // End Call
            ControlButton(
                icon: "phone.down.fill",
                color: .red,
                size: 70,
                action: {
                    Task {
                        try? await callService.endCall()
                    }
                }
            )
        }
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let icon: String
    let color: Color
    var size: CGFloat = 60
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size == 70 ? 28 : 24))
                .foregroundStyle(icon == "phone.down.fill" ? .white : color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(icon == "phone.down.fill" ? color : Color.white.opacity(0.1))
                )
        }
    }
}

// MARK: - Incoming Call View
struct IncomingCallView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var callService = FlukavikeCallService.shared
    
    var body: some View {
        ZStack {
            // Blurred background
            themeManager.backgroundPrimary(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 60) {
                Spacer()
                
                // Caller Info
                VStack(spacing: 20) {
                    if let initiator = callService.activeCall?.initiator {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.accentColor.color.opacity(0.8),
                                            themeManager.accentColor.color.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                            
                            Text(initiator.formattedName.prefix(1))
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text(initiator.formattedName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                            
                            Text(callTypeText)
                                .font(.system(size: 18))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                }
                
                Spacer()
                
                // Answer/Decline buttons
                HStack(spacing: 60) {
                    // Decline
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                try? await callService.endCall()
                            }
                        }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                )
                        }
                        
                        Text("Decline")
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    
                    // Answer
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                try? await callService.answerCall()
                            }
                        }) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(Color.green)
                                )
                        }
                        
                        Text("Accept")
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }
    
    private var callTypeText: String {
        switch callService.activeCall?.type {
        case .video:
            return "Video Call"
        case .voice:
            return "Voice Call"
        case .none:
            return "Incoming Call"
        }
    }
}

// MARK: - Preview
#Preview {
    CallView()
        .environment(ThemeManager())
}
