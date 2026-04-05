//
//  HomeView.swift
//  Home screen with server channels
//

import SwiftUI

struct HomeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var servers: [Server] = []
    @State private var selectedServer: Server?
    @State private var channels: [Channel] = []
    @State private var isLoadingServers: Bool = false
    @State private var isLoadingChannels: Bool = false
    @State private var channelsError: String?
    @State private var selectedChannel: Channel?
    @State private var contextMenuServer: Server?
    @State private var contextMenuChannel: Channel?
    
    // Sheet presentation state - using enum to avoid multiple sheet modifiers
    @State private var activeSheet: HomeSheet? = nil

    private let apiService = APIService.shared
    
    enum HomeSheet: Identifiable {
        case search
        case settings
        case channel(Channel)
        case serverMenu(Server)
        case channelMenu(Channel)
        case addServer
        
        var id: String {
            switch self {
            case .search: return "search"
            case .settings: return "settings"
            case .channel(let c): return "channel-\(c.id)"
            case .serverMenu(let s): return "server-\(s.id)"
            case .channelMenu(let c): return "channelMenu-\(c.id)"
            case .addServer: return "addServer"
            }
        }
    }
    
    private var isAuthenticated: Bool {
        appState.isAuthenticated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Server Selector Pills
                    serverPillsSection
                    
                    // Channels List
                    serverChannelsSection
                }
                .padding(.vertical, 16)
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle(isAuthenticated ? "Flukavike" : "Flukavike (Preview)")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if servers.isEmpty {
                    if isAuthenticated {
                        Task { await loadServers() }
                    } else {
                        servers = Server.previewServers
                        selectedServer = servers.first
                        if let server = selectedServer {
                            channels = server.channels.sorted { $0.position < $1.position }
                        }
                    }
                }
            }
            .onChange(of: appState.gatewayGuilds) { _, gatewayGuilds in
                guard !gatewayGuilds.isEmpty, let server = selectedServer else { return }
                Task { await loadChannels(for: server) }
            }
            .onChange(of: appState.pendingChannelNavigation) { _, pending in
                guard let pending else { return }
                // Switch to the right server then open the channel
                if let server = servers.first(where: { $0.id == pending.serverId  }) {
                    selectedServer = server
                    Task { await loadChannels(for: server) }
                }
                let channelId = pending.channelId
                // Wait briefly for channels to load before opening the sheet
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let channel = channels.first(where: { $0.id == channelId }) {
                        await MainActor.run {
                            activeSheet = .channel(channel)
                            appState.pendingChannelNavigation = nil
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isLoadingServers || isLoadingChannels {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { 
                            Task { await loadServers() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                        
                        Button(action: { activeSheet = .search }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                        
                        Button(action: { 
                            print("Settings tapped!")
                            activeSheet = .settings 
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                Group {
                    switch sheet {
                    case .search:
                        SearchView()
                            .environment(themeManager)
                            .environment(appState)
                    case .settings:
                        SettingsView()
                            .environment(themeManager)
                            .environment(appState)
                    case .channel(let channel):
                        if channel.type == .voice {
                            VoiceChannelView(channel: channel)
                                .environment(themeManager)
                                .environment(appState)
                        } else {
                            NavigationStack {
                                ChatView(channel: channel)
                            }
                        }
                    case .serverMenu(let server):
                        ServerContextMenu(server: server)
                            .environment(themeManager)
                            .environment(appState)
                    case .channelMenu(let channel):
                        ChannelContextMenu(channel: channel, server: selectedServer)
                            .environment(themeManager)
                            .environment(appState)
                    case .addServer:
                        JoinServerView { server in
                            if !servers.contains(where: { $0.id == server.id }) {
                                servers.insert(server, at: 0)
                            }
                            selectedServer = server
                            activeSheet = nil
                        }
                        .environment(themeManager)
                        .environment(appState)
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading

    private func loadServers() async {
        await MainActor.run {
            isLoadingServers = true
        }
        
        do {
            let fetched = try await apiService.getUserGuilds()
            
            await MainActor.run {
                // Only use fetched servers if we got real data
                if !fetched.isEmpty {
                    servers = fetched
                    appState.restServers = fetched   // store for name resolution elsewhere
                    ChannelStore.shared.update(guilds: appState.gatewayGuilds, restServers: fetched)
                } else {
                    // Fallback to preview if API returns empty
                    servers = Server.previewServers
                }
                selectedServer = servers.first
                isLoadingServers = false
            }
            
            // Load channels for the selected server
            if let server = servers.first {
                await loadChannels(for: server)
            }
        } catch {
            await MainActor.run {
                // Fallback to preview data on error
                servers = Server.previewServers
                selectedServer = servers.first
                isLoadingServers = false
                
                // Load preview channels
                if let server = servers.first {
                    channels = server.channels.sorted { $0.position < $1.position }
                }
            }
        }
    }
    
    private func loadChannels(for server: Server) async {
        // Clear channels immediately to prevent showing old data
        await MainActor.run {
            isLoadingChannels = true
            channelsError = nil
            channels = [] // Clear old channels immediately
        }
        
        // ⚠️ WARNING — DO NOT REORDER OR REMOVE THIS BLOCK.
        // Fluxer's REST endpoint GET /guilds/{id}/channels always returns [] for user tokens.
        // The only source of channel data is AppState.gatewayGuilds, which is populated when
        // the WebSocket Gateway fires the READY event. The REST fallback below this block will
        // never return channels on Fluxer — it is kept only for non-Fluxer instance compatibility.
        // Check gateway guilds first (Fluxer delivers channels via Gateway READY, not REST)
        if let gatewayGuild = appState.gatewayGuilds.first(where: { $0.id == server.id }),
           !gatewayGuild.channels.isEmpty {
            let gatewayChannels = gatewayGuild.channels
            await MainActor.run {
                channels = gatewayChannels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
            return
        }

        // Fall back to embedded channels (preview servers)
        if !server.channels.isEmpty {
            await MainActor.run {
                channels = server.channels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
            return
        }

        // Last resort: try REST (returns [] on Fluxer but may work on other instances)
        do {
            let fetchedChannels = try await apiService.getGuildChannels(guildId: server.id)
            await MainActor.run {
                channels = fetchedChannels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
        } catch {
            await MainActor.run {
                channelsError = "Failed to load channels: \(error.localizedDescription)"
                channels = []
                appState.selectedServer = server
                isLoadingChannels = false
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
                        ServerPill(
                            server: server,
                            isSelected: selectedServer?.id == server.id
                        ) {
                            selectedServer = server
                            Task {
                                await loadChannels(for: server)
                            }
                        } onLongPress: {
                            contextMenuServer = server
                            activeSheet = .serverMenu(server)
                            HapticFeedback.medium()
                        }
                    }
                    
                    // Add Server Button
                    AddServerPill { activeSheet = .addServer }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Server Channels Section
    private var serverChannelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let server = selectedServer {
                HStack {
                    Text(server.name.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                    Spacer()
                    
                    if isLoadingChannels {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            if let error = channelsError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
            
            if channels.isEmpty && !isLoadingChannels {
                Text("No channels available")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.backgroundSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            } else {
            VStack(spacing: 0) {
                ForEach(sortedCategoryKeys, id: \.self) { categoryKey in
                    let categoryChannels = groupedChannels[categoryKey] ?? []
                    
                    // Category Header
                    if !categoryKey.isEmpty {
                        Text(categoryName(for: categoryKey))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }
                    
                    // Channels in this category
                    ForEach(categoryChannels) { channel in
                        HomeChannelRow(
                            channel: channel,
                            isSelected: selectedChannel?.id == channel.id
                        )
                        .onTapGesture {
                            activeSheet = .channel(channel)
                            appState.selectedChannel = channel
                        }
                        .onLongPressGesture {
                            contextMenuChannel = channel
                            activeSheet = .channelMenu(channel)
                            HapticFeedback.medium()
                        }
                        
                        if channel.id != categoryChannels.last?.id {
                            Divider()
                                .padding(.leading, 56)
                                .background(themeManager.separator(colorScheme))
                        }
                    }
                }
            }
            .background(themeManager.backgroundSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            } // End else
        }
    }
    
    // MARK: - Channel Grouping Helpers
    
    private var categoriesById: [String: Channel] {
        Dictionary(uniqueKeysWithValues: channels
            .filter { $0.type == .category }
            .map { ($0.id, $0) }
        )
    }
    
    private var groupedChannels: [String: [Channel]] {
        let displayChannels = channels.filter { $0.type != .category }
        return Dictionary(grouping: displayChannels) { channel in
            channel.parentId ?? ""
        }
    }
    
    private var sortedCategoryKeys: [String] {
        var keys = Array(groupedChannels.keys)
        keys.sort { a, b in
            if a.isEmpty { return true }
            if b.isEmpty { return false }
            let posA = categoriesById[a]?.position ?? Int.max
            let posB = categoriesById[b]?.position ?? Int.max
            return posA < posB
        }
        return keys
    }
    
    private func categoryName(for key: String) -> String {
        if key.isEmpty { return "CHANNELS" }
        return categoriesById[key]?.name.uppercased() ?? key
    }
}

// MARK: - Server Pill
struct ServerPill: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let server: Server
    let isSelected: Bool
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ServerIconView(server: server, size: 32, cornerRadius: 10)

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
        .onLongPressGesture {
            onLongPress?()
        }
    }
}

// MARK: - Add Server Pill
struct AddServerPill: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

// MARK: - Home Channel Row
struct HomeChannelRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let channel: Channel
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Channel Icon
            Image(systemName: channelIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSelected ? themeManager.accentColor.color : themeManager.textSecondary(colorScheme))
                .frame(width: 24)
            
            // Channel Name
            Text(channel.name)
                .font(.system(size: 16, weight: channel.hasUnread ? .semibold : .regular))
                .foregroundStyle(isSelected ? themeManager.accentColor.color : themeManager.textPrimary(colorScheme))
            
            Spacer()
            
            // Unread/Mention Indicators
            HStack(spacing: 8) {
                if channel.hasMention {
                    MentionBadge(count: channel.mentionCount)
                } else if channel.hasUnread {
                    Circle()
                        .fill(themeManager.accentColor.color)
                        .frame(width: 8, height: 8)
                }
                
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? themeManager.accentColor.color.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
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
}

// MARK: - Join Server View
struct JoinServerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let onJoined: (Server) -> Void

    @State private var inviteCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.accentColor.color)
                    Text("Join a Server")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    Text("Enter an invite link or code to join an existing server.")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("INVITE LINK OR CODE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    TextField("e.g. fluxer.app/invite/abc123", text: $inviteCode)
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.backgroundTertiary(colorScheme)))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button(action: joinServer) {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        Text(isLoading ? "Joining..." : "Join Server")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(
                        inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
                            ? themeManager.backgroundTertiary(colorScheme)
                            : themeManager.accentColor.color
                    ))
                    .foregroundStyle(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
                        ? themeManager.textTertiary(colorScheme) : .white)
                }
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Add a Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }

    private func joinServer() {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let server = try await APIService.shared.joinServer(inviteCode: code)
                await MainActor.run { onJoined(server) }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Could not join server. Check the invite code and try again."
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environment(ThemeManager())
        .environment(AppState())
}
