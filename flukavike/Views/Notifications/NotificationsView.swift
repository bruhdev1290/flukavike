//
//  NotificationsView.swift
//  Notification center with list design
//

import SwiftUI

struct NotificationsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var selectedFilter: NotificationFilter = .all
    @State private var selectedServerId: String? = nil
    @State private var sortOrder: SortOrder = .newest
    @State private var isLoading: Bool = false

    private let apiService = APIService.shared

    private var notifications: [AppNotification] { appState.notifications }

    enum NotificationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case mentions = "Mentions"
        case reactions = "Reactions"
        case messages = "Messages"

        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case unread = "Unread First"
        case byServer = "By Server"

        var id: String { rawValue }
    }

    var filteredAndSortedNotifications: [AppNotification] {
        let filtered = notifications.filter { notification in
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

        switch sortOrder {
        case .newest:
            return filtered.sorted { $0.timestamp > $1.timestamp }
        case .oldest:
            return filtered.sorted { $0.timestamp < $1.timestamp }
        case .unread:
            return filtered.sorted {
                if $0.read == $1.read {
                    return $0.timestamp > $1.timestamp
                }
                return !$0.read && $1.read
            }
        case .byServer:
            return filtered.sorted {
                let server0 = $0.serverName ?? ""
                let server1 = $1.serverName ?? ""
                if server0 == server1 {
                    return $0.timestamp > $1.timestamp
                }
                return server0 < server1
            }
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
                if isLoading && notifications.isEmpty {
                    Section {
                        HStack { Spacer(); ProgressView().padding(.vertical, 40); Spacer() }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } else if filteredAndSortedNotifications.isEmpty {
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
                        ForEach(filteredAndSortedNotifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .contentShape(Rectangle())
                                .onTapGesture { openNotification(notification) }
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
                        filterMenu

                        if !uniqueServers.isEmpty {
                            serverFilterMenu
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
            .task { await loadNotifications() }
            .refreshable { await loadNotifications() }
        }
    }

    // MARK: - Menus

    private var filterMenu: some View {
        Menu {
            Section("Filter") {
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
            }

            Section("Sort") {
                Button(action: { sortOrder = .newest }) {
                    Label("Newest First", systemImage: sortOrder == .newest ? "checkmark" : "")
                }
                Button(action: { sortOrder = .oldest }) {
                    Label("Oldest First", systemImage: sortOrder == .oldest ? "checkmark" : "")
                }
                Button(action: { sortOrder = .unread }) {
                    Label("Unread First", systemImage: sortOrder == .unread ? "checkmark" : "")
                }
                Button(action: { sortOrder = .byServer }) {
                    Label("By Server", systemImage: sortOrder == .byServer ? "checkmark" : "")
                }
            }

            Section {
                Button("Mark All as Read") {
                    markAllAsRead()
                }

                Button("Clear All", role: .destructive) {
                    clearAll()
                }
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
        .accessibilityLabel("Filter and sort notifications")
    }

    private var serverFilterMenu: some View {
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

    // MARK: - Data Loading

    private func loadNotifications() async {
        await MainActor.run { isLoading = true }
        do {
            let notifications = try await apiService.getNotifications()
            await MainActor.run {
                appState.notifications = notifications.sorted { $0.timestamp > $1.timestamp }
                appState.unreadNotifications = appState.notifications.filter { !$0.read }.count
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Actions

    private func deleteNotification(_ notification: AppNotification) {
        withAnimation {
            appState.notifications.removeAll { $0.id == notification.id }
            appState.unreadNotifications = appState.notifications.filter { !$0.read }.count
        }
        Task {
            try? await apiService.dismissNotification(id: notification.id)
        }
    }

    private func markAsRead(_ notification: AppNotification) {
        guard !notification.read else { return }
        let updated = notification.withRead(true)
        if let index = appState.notifications.firstIndex(where: { $0.id == notification.id }) {
            withAnimation {
                appState.notifications[index] = updated
            }
        }
        appState.unreadNotifications = appState.notifications.filter { !$0.read }.count
        Task {
            try? await apiService.markNotificationRead(id: notification.id)
        }
    }

    private func markAllAsRead() {
        withAnimation {
            appState.notifications = appState.notifications.map { $0.withRead(true) }
        }
        appState.unreadNotifications = 0
        Task {
            try? await apiService.markAllNotificationsRead()
        }
    }

    private func clearAll() {
        let ids = appState.notifications.map { $0.id }
        withAnimation {
            appState.notifications.removeAll()
        }
        appState.unreadNotifications = 0
        Task {
            for id in ids {
                try? await apiService.dismissNotification(id: id)
            }
        }
    }

    // MARK: - Deep-linking

    private func openNotification(_ notification: AppNotification) {
        if !notification.read {
            markAsRead(notification)
        }

        if let channelId = notification.channelId, let serverId = notification.serverId {
            appState.pendingChannelNavigation = AppState.ChannelNavigation(serverId: serverId, channelId: channelId)
        } else if let channelId = notification.channelId {
            appState.pendingDMNavigation = AppState.DMNavigation(channelId: channelId, userId: notification.dmRecipientId)
        } else if let dmRecipientId = notification.dmRecipientId {
            appState.pendingDMNavigation = AppState.DMNavigation(channelId: notification.relatedId ?? dmRecipientId, userId: dmRecipientId)
        }
    }
}

// MARK: - Notification Helpers
private extension AppNotification {
    func withRead(_ read: Bool) -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            title: title,
            message: message,
            timestamp: timestamp,
            read: read,
            relatedId: relatedId,
            channelId: channelId,
            messageId: messageId,
            senderId: senderId,
            senderAvatarUrl: senderAvatarUrl,
            serverId: serverId,
            serverName: serverName,
            dmRecipientId: dmRecipientId
        )
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let avatarURL = notification.senderAvatarUrl.flatMap {
                APIService.shared.avatarURL(userId: notification.senderId ?? "", hash: $0)
            }
            CachedAsyncImage(url: avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholderIcon
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

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

                if let contextName = contextName {
                    HStack(spacing: 4) {
                        Image(systemName: notification.serverId == nil ? "bubble.left" : "server.rack")
                            .font(.system(size: 10))
                        Text(contextName)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(themeManager.accentColor.color.opacity(0.8))
                    .padding(.top, 2)
                }
            }

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

    private var placeholderIcon: some View {
        ZStack {
            Circle()
                .fill(notification.type.color.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: notification.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(notification.type.color)
        }
    }

    private var contextName: String? {
        if let serverName = notification.serverName {
            return serverName
        }
        if notification.dmRecipientId != nil || notification.channelId != nil {
            return "Direct Message"
        }
        return nil
    }
}

// MARK: - Preview
#Preview {
    NotificationsView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(PresenceStore.shared)
}
