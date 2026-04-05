//
//  NotificationsView.swift
//  Notification center with list design
//

import SwiftUI

struct NotificationsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    
    @State private var notifications: [AppNotification] = AppNotification.previewNotifications
    @State private var selectedFilter: NotificationFilter = .all
    @State private var selectedServerId: String? = nil
    @State private var showFilterSheet: Bool = false
    
    enum NotificationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case mentions = "Mentions"
        case reactions = "Reactions"
        case messages = "Messages"
        
        var id: String { rawValue }
    }
    
    var filteredNotifications: [AppNotification] {
        notifications.filter { notification in
            let matchesType: Bool = {
                switch selectedFilter {
                case .all:
                    return true
                case .mentions:
                    return notification.type == .mention
                case .reactions:
                    return notification.type == .reaction
                case .messages:
                    return notification.type == .dm || notification.type == .reply
                }
            }()
            
            let matchesServer: Bool = {
                guard let selectedId = selectedServerId else { return true }
                return notification.serverId == selectedId
            }()
            
            return matchesType && matchesServer
        }
    }
    
    var uniqueServers: [(id: String, name: String)] {
        var servers: [(id: String, name: String)] = []
        for notification in notifications {
            if let serverId = notification.serverId,
               let serverName = notification.serverName,
               !servers.contains(where: { $0.id == serverId }) {
                servers.append((id: serverId, name: serverName))
            }
        }
        return servers.sorted { $0.name < $1.name }
    }
    
    var unreadCount: Int {
        notifications.filter { !$0.read }.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredNotifications.isEmpty {
                    Section {
                        EmptyStateView(
                            icon: "bell.slash",
                            title: "No Notifications",
                            message: "You're all caught up! Check back later for mentions, reactions, and messages."
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(filteredNotifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteNotification(notification)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        markAsRead(notification)
                                    } label: {
                                        Label("Read", systemImage: "checkmark")
                                    }
                                    .tint(themeManager.accentColor.color)
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        // Type Filter
                        Menu {
                            Button(action: { selectedFilter = .all }) {
                                Label("All", systemImage: selectedFilter == .all ? "checkmark" : "")
                            }
                            Button(action: { selectedFilter = .mentions }) {
                                Label("Mentions", systemImage: selectedFilter == .mentions ? "checkmark" : "")
                            }
                            Button(action: { selectedFilter = .reactions }) {
                                Label("Reactions", systemImage: selectedFilter == .reactions ? "checkmark" : "")
                            }
                            Button(action: { selectedFilter = .messages }) {
                                Label("Messages", systemImage: selectedFilter == .messages ? "checkmark" : "")
                            }
                            
                            Divider()
                            
                            Button("Mark All as Read") {
                                markAllAsRead()
                            }
                            
                            Button("Clear All", role: .destructive) {
                                clearAll()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedFilter.rawValue)
                                    .font(.system(size: 17, weight: .regular))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(themeManager.accentColor.color)
                        }
                        
                        // Server Filter
                        if !uniqueServers.isEmpty {
                            Menu {
                                Button(action: { selectedServerId = nil }) {
                                    Label("All Servers", systemImage: selectedServerId == nil ? "checkmark" : "")
                                }
                                
                                Divider()
                                
                                ForEach(uniqueServers, id: \.id) { server in
                                    Button(action: { selectedServerId = server.id }) {
                                        Label(server.name, systemImage: selectedServerId == server.id ? "checkmark" : "")
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "server.rack")
                                        .font(.system(size: 14))
                                    Text(selectedServerId == nil ? "All Servers" : uniqueServers.first { $0.id == selectedServerId }?.name ?? "Unknown")
                                        .font(.system(size: 17, weight: .regular))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(themeManager.accentColor.color)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if unreadCount > 0 {
                        Button("Mark All Read") {
                            markAllAsRead()
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.accentColor.color)
                    }
                }
            }
        }
        .onAppear {
            appState.unreadNotifications = unreadCount
        }
    }
    
    private func deleteNotification(_ notification: AppNotification) {
        withAnimation {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    private func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            var updated = notification
            // Toggle read status
            withAnimation {
                notifications[index] = AppNotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    timestamp: notification.timestamp,
                    read: true,
                    relatedId: notification.relatedId,
                    serverId: notification.serverId,
                    serverName: notification.serverName
                )
            }
        }
        appState.unreadNotifications = unreadCount
    }
    
    private func markAllAsRead() {
        withAnimation {
            notifications = notifications.map { notification in
                AppNotification(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    timestamp: notification.timestamp,
                    read: true,
                    relatedId: notification.relatedId,
                    serverId: notification.serverId,
                    serverName: notification.serverName
                )
            }
        }
        appState.unreadNotifications = 0
    }
    
    private func clearAll() {
        withAnimation {
            notifications.removeAll()
        }
        appState.unreadNotifications = 0
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(notification.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Spacer()
                    
                    Text(notification.timestamp, style: .relative)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
                
                Text(notification.message)
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .lineLimit(2)
                
                if let serverName = notification.serverName {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 10))
                        Text(serverName)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(themeManager.accentColor.color.opacity(0.8))
                    .padding(.top, 2)
                }
            }
            
            // Unread Indicator
            if !notification.read {
                Circle()
                    .fill(themeManager.accentColor.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(notification.read ? Color.clear : themeManager.accentColor.color.opacity(0.05))
        )
        .opacity(notification.read ? 0.7 : 1.0)
    }
}

// MARK: - Preview
#Preview {
    NotificationsView()
        .environment(ThemeManager())
        .environment(AppState())
}
