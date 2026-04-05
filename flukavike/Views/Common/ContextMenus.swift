//
//  ContextMenus.swift
//  Context menus for channels and servers
//

import SwiftUI

// MARK: - Toast Notification
@Observable
class ToastManager {
    static let shared = ToastManager()
    private(set) var message: String?
    private(set) var isShowing = false
    
    func show(_ message: String) {
        self.message = message
        isShowing = true
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            withAnimation {
                self?.isShowing = false
            }
        }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Channel Context Menu
struct ChannelContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    let channel: Channel
    let server: Server?
    
    private var isStarred: Bool {
        StarredChannelsManager.shared.isStarred(channel.id)
    }
    
    private var serverName: String {
        server?.name ?? StarredChannelsManager.shared.serverName(for: channel.id)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Channel Header
                HStack(spacing: 12) {
                    Image(systemName: channelIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.accentColor.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(channel.name)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        if let server = server {
                            Text(server.name)
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Mark as Read (only if has unread)
                        if channel.hasUnread {
                            MenuButton(icon: "eye", title: "Mark as Read", color: themeManager.textPrimary(colorScheme)) {
                                markAsRead()
                                dismiss()
                            }
                        }
                        
                        // Section: Channel Options
                        VStack(spacing: 0) {
                            // Star/Unstar Channel
                            if channel.type != .voice {
                                MenuButton(
                                    icon: isStarred ? "star.fill" : "star",
                                    title: isStarred ? "Unstar Channel" : "Star Channel",
                                    color: isStarred ? .yellow : themeManager.textPrimary(colorScheme)
                                ) {
                                    toggleStar()
                                    dismiss()
                                }
                                
                                Divider()
                                    .background(themeManager.separator(colorScheme))
                                    .padding(.leading, 56)
                            }
                            
                            // Copy Channel Link
                            MenuButton(icon: "link", title: "Copy Link", color: themeManager.textPrimary(colorScheme)) {
                                copyChannelLink()
                                dismiss()
                            }
                            
                            if channel.type != .voice {
                                Divider()
                                    .background(themeManager.separator(colorScheme))
                                    .padding(.leading, 56)
                                
                                // Mute Channel (placeholder - would need backend support)
                                MenuButton(icon: "bell.slash", title: "Mute Channel (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                    dismiss()
                                }
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Channel Info
                        VStack(spacing: 0) {
                            if let topic = channel.topic, !topic.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Topic")
                                            .font(.system(size: 16))
                                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                                        Text(topic)
                                            .font(.system(size: 13))
                                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text:
            return "number"
        case .voice:
            return "speaker.wave.2"
        case .category:
            return "folder"
        case .announcement:
            return "megaphone"
        }
    }
    
    private func toggleStar() {
        let newState = StarredChannelsManager.shared.toggle(channelId: channel.id, serverName: serverName)
        HapticFeedback.light()
        ToastManager.shared.show(newState ? "Channel starred" : "Channel unstarred")
    }
    
    private func markAsRead() {
        // In a real implementation, this would call an API endpoint
        // For now, we just show a toast
        HapticFeedback.light()
        ToastManager.shared.show("Marked as read")
    }
    
    private func copyChannelLink() {
        let link = "https://\(server?.instance ?? "fluxer.app")/channels/\(server?.id ?? "@me")/\(channel.id)"
        UIPasteboard.general.string = link
        HapticFeedback.light()
        ToastManager.shared.show("Link copied to clipboard")
    }
}

// MARK: - Server Context Menu
struct ServerContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    let server: Server
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Server Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeManager.accentColor.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(String(server.name.prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("\(server.memberCount) Members")
                                .font(.system(size: 13))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Section: Quick Actions
                        VStack(spacing: 0) {
                            // Copy Server Invite Link
                            MenuButton(icon: "link", title: "Copy Server Link", color: themeManager.textPrimary(colorScheme)) {
                                copyServerLink()
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Settings (Coming Soon)
                        VStack(spacing: 0) {
                            MenuButton(icon: "bell", title: "Notification Settings (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "person.circle", title: "Edit Server Profile (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Danger Zone
                        VStack(spacing: 0) {
                            MenuButton(icon: "arrow.left.square", title: "Leave Server", color: .red) {
                                leaveServer()
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
    
    private func copyServerLink() {
        let link = "https://\(server.instance)/servers/\(server.id)"
        UIPasteboard.general.string = link
        HapticFeedback.light()
        ToastManager.shared.show("Link copied to clipboard")
    }
    
    private func leaveServer() {
        // In a real implementation, this would call an API to leave the server
        HapticFeedback.notification(.success)
        ToastManager.shared.show("Left \"\(server.name)\"")
    }
}

// MARK: - DM Context Menu
struct DMContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let user: User
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // User Header
                HStack(spacing: 12) {
                    AvatarView(user: user, size: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.formattedName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        if let status = user.customStatus {
                            Text(status)
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Section: Actions
                        VStack(spacing: 0) {
                            MenuButton(icon: "person", title: "View Profile (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "phone", title: "Start Voice Call (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            // Copy User Link
                            MenuButton(icon: "link", title: "Copy User Link", color: themeManager.textPrimary(colorScheme)) {
                                copyUserLink()
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Close DM
                        VStack(spacing: 0) {
                            MenuButton(icon: "xmark.circle", title: "Close DM", color: .red) {
                                closeDM()
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Block
                        VStack(spacing: 0) {
                            MenuButton(icon: "nosign", title: "Block User (Soon)", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
    
    private func copyUserLink() {
        let link = "https://fluxer.app/users/\(user.id)"
        UIPasteboard.general.string = link
        HapticFeedback.light()
        ToastManager.shared.show("Link copied to clipboard")
    }
    
    private func closeDM() {
        HapticFeedback.notification(.success)
        ToastManager.shared.show("DM closed")
    }
}

// MARK: - Menu Button Components
struct MenuButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MenuButtonWithChevron: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Context Menus Preview")
    }
    .sheet(isPresented: .constant(true)) {
        ChannelContextMenu(channel: Channel.previewChannels[0], server: Server.preview)
            .environment(ThemeManager())
    }
}
