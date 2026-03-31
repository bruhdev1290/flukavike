//
//  HomeView.swift
//  Home screen with quick actions
//

import SwiftUI

struct HomeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var servers: [Server] = Server.previewServers
    @State private var selectedServer: Server?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Server Selector Pills
                    serverPillsSection
                    
                    // Pinned Section
                    pinnedSection
                    
                    // Recent Conversations
                    recentConversationsSection
                    
                    // Recent Notifications
                    recentNotificationsSection
                }
                .padding(.vertical, 16)
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Flukavike")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "gear")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Server Pills Section
    private var serverPillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SERVERS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(servers) { server in
                        ServerPill(server: server, isSelected: selectedServer?.id == server.id) {
                            selectedServer = server
                        }
                    }
                    
                    // Add Server Button
                    AddServerPill()
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Pinned Section
    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12))
                Text("PINNED")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(themeManager.textTertiary(colorScheme))
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PinnedChannelRow(
                    channel: Channel.previewChannels[0],
                    serverName: "Flukavike HQ"
                )
                
                Divider()
                    .padding(.leading, 56)
                    .background(themeManager.separator(colorScheme))
                
                PinnedChannelRow(
                    channel: Channel.previewChannels[3],
                    serverName: "Swift Devs"
                )
            }
            .background(themeManager.backgroundSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Recent Conversations Section
    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT CONVERSATIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                ForEach(Message.previewMessages) { message in
                    ConversationRow(message: message)
                    
                    if message.id != Message.previewMessages.last?.id {
                        Divider()
                            .padding(.leading, 68)
                            .background(themeManager.separator(colorScheme))
                    }
                }
            }
            .background(themeManager.backgroundSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Recent Notifications Section
    private var recentNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOTIFICATIONS")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if AppState().unreadNotifications > 0 {
                    Text("\(AppState().unreadNotifications) new")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .foregroundStyle(themeManager.textTertiary(colorScheme))
            .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                ForEach(AppNotification.previewNotifications) { notification in
                    NotificationPreviewRow(notification: notification)
                    
                    if notification.id != AppNotification.previewNotifications.last?.id {
                        Divider()
                            .padding(.leading, 56)
                            .background(themeManager.separator(colorScheme))
                    }
                }
            }
            .background(themeManager.backgroundSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Server Pill
struct ServerPill: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let server: Server
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Server Icon
                ZStack {
                    Circle()
                        .fill(themeManager.accentColor.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Text(String(server.name.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.accentColor.color)
                }
                
                // Server Name
                Text(server.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? themeManager.accentColor.color : themeManager.textPrimary(colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? themeManager.accentColor.color.opacity(0.15) : themeManager.backgroundTertiary(colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? themeManager.accentColor.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Server Pill
struct AddServerPill: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(themeManager.backgroundTertiary(colorScheme))
                    )
                
                Text("Add")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.backgroundTertiary(colorScheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pinned Channel Row
struct PinnedChannelRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let channel: Channel
    let serverName: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Channel Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.accentColor.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: channel.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.accentColor.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(channel.name)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Text(serverName)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
                
                Spacer()
                
                if channel.hasUnread {
                    Circle()
                        .fill(themeManager.accentColor.color)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Avatar
                AvatarView(user: message.author, size: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(message.author.formattedName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        Spacer()
                        
                        Text(message.timestamp, style: .time)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                    
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Preview Row
struct NotificationPreviewRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let notification: AppNotification
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(notification.type.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if !notification.read {
                    Circle()
                        .fill(themeManager.accentColor.color)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environment(ThemeManager())
        .environment(AppState())
}
