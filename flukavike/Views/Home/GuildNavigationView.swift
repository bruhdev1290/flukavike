//
//  GuildNavigationView.swift
//  Optional Discord-style server rail + channel list layout
//

import SwiftUI

struct GuildNavigationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var isLoadingServers: Bool = false
    @State private var isLoadingChannels: Bool = false
    @State private var channelsError: String?
    @State private var showJoinServerSheet: Bool = false
    @State private var showSettings: Bool = false
    @State private var selectedChannel: Channel?
    @State private var contextMenuChannel: Channel? = nil
    @State private var showMessages: Bool = false
    @State private var menuServer: Server?

    private let apiService = APIService.shared

    private var isAuthenticated: Bool {
        appState.isAuthenticated
    }

    private var servers: [Server] { appState.railServers }
    private var selectedServer: Server? { appState.railSelectedServer }
    private var channels: [Channel] { appState.railChannels }

    var body: some View {
        HStack(spacing: 0) {
            serverRail
            channelListPane
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isLoadingServers || isLoadingChannels {
                    ProgressView().scaleEffect(0.8)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { Task { await loadServers() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                .accessibilityLabel("Refresh servers")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showJoinServerSheet) {
            JoinServerView { server in
                if !appState.railServers.contains(where: { $0.id == server.id }) {
                    appState.railServers.insert(server, at: 0)
                }
                selectServer(server)
                Task { await loadChannels(for: server) }
            }
            .environment(themeManager)
            .environment(appState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(themeManager)
                .environment(appState)
        }
        .sheet(item: $selectedChannel) { channel in
            Group {
                if channel.type == .voice {
                    VoiceChannelView(channel: channel)
                        .environment(themeManager)
                        .environment(appState)
                } else {
                    NavigationStack {
                        ChatView(channel: channel)
                            .environment(themeManager)
                            .environment(appState)
                    }
                }
            }
        }
        .sheet(isPresented: $showMessages) {
            NavigationStack {
                MessagesView()
                    .environment(themeManager)
                    .environment(appState)
            }
        }
        .sheet(item: $contextMenuChannel) { channel in
            ChannelContextMenu(channel: channel, server: selectedServer)
                .environment(themeManager)
                .environment(appState)
        }
        .sheet(item: $menuServer) { server in
            ServerContextMenu(server: server)
                .environment(themeManager)
                .environment(appState)
        }
        .onAppear {
            if appState.railServers.isEmpty {
                if isAuthenticated {
                    Task { await loadServers() }
                } else {
                    let preview = Server.previewServers
                    appState.railServers = preview
                    if let first = preview.first {
                        selectServer(first)
                        Task { await loadChannels(for: first) }
                    }
                }
            } else if appState.railSelectedServer == nil {
                if let first = appState.railServers.first {
                    selectServer(first)
                }
            }
        }
        .onChange(of: appState.gatewayGuilds) { _, _ in
            guard let server = appState.railSelectedServer else { return }
            Task { await loadChannels(for: server) }
        }
        .onChange(of: appState.pendingChannelNavigation) { _, pending in
            guard let pending else { return }
            if let server = appState.railServers.first(where: { $0.id == pending.serverId }) {
                selectServer(server)
                Task {
                    await loadChannels(for: server)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if let channel = appState.railChannels.first(where: { $0.id == pending.channelId }) {
                        await MainActor.run {
                            selectedChannel = channel
                            appState.pendingChannelNavigation = nil
                        }
                    }
                }
            }
        }
        .onChange(of: appState.pendingDMNavigation) { _, pending in
            guard pending != nil else { return }
            showMessages = true
        }
    }

    // MARK: - Server Rail

    private var serverRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // @me / DMs shortcut
                railButton(
                    icon: "bubble.left.fill",
                    isSelected: false,
                    color: .green,
                    action: { showMessages = true }
                )
                .accessibilityLabel("Direct Messages")

                Divider()
                    .background(themeManager.separator(colorScheme))
                    .frame(width: 36)

                ForEach(servers) { server in
                    railServerButton(server: server)
                }

                Divider()
                    .background(themeManager.separator(colorScheme))
                    .frame(width: 36)

                railButton(
                    icon: "plus",
                    isSelected: false,
                    color: themeManager.textSecondary(colorScheme),
                    action: { showJoinServerSheet = true }
                )
                .accessibilityLabel("Add a server")

                Spacer(minLength: 12)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 72)
        .background(themeManager.backgroundSecondary(colorScheme))
    }

    private func railServerButton(server: Server) -> some View {
        let selected = selectedServer?.id == server.id
        return Button {
            selectServer(server)
            Task { await loadChannels(for: server) }
        } label: {
            ZStack(alignment: .leading) {
                HStack {
                    Spacer()
                    ServerIconView(server: server, size: 48, cornerRadius: selected ? 16 : 24)
                    Spacer()
                }

                if selected {
                    Capsule()
                        .fill(themeManager.textPrimary(colorScheme))
                        .frame(width: 4, height: 32)
                        .offset(x: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(server.name) server\(selected ? ", selected" : "")")
    }

    private func railButton(
        icon: String,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: isSelected ? 16 : 24)
                                .fill(isSelected
                                      ? themeManager.accentColor.color.opacity(0.15)
                                      : themeManager.backgroundTertiary(colorScheme))
                        )
                    Spacer()
                }

                if isSelected {
                    Capsule()
                        .fill(themeManager.textPrimary(colorScheme))
                        .frame(width: 4, height: 32)
                        .offset(x: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel List Pane

    private var channelListPane: some View {
        ScrollView {
            VStack(spacing: 0) {
                serverHeader

                if let error = channelsError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                if channels.isEmpty && !isLoadingChannels {
                    Text("No channels available")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                        .padding(.vertical, 60)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedCategoryKeys, id: \.self) { categoryKey in
                            let categoryChannels = groupedChannels[categoryKey] ?? []

                            if !categoryKey.isEmpty {
                                HStack {
                                    Text(categoryName(for: categoryKey))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                            }

                            ForEach(categoryChannels) { channel in
                                HomeChannelRow(
                                    channel: channel,
                                    isSelected: false
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedChannel = channel
                                    appState.selectedChannel = channel
                                }
                                .onLongPressGesture {
                                    contextMenuChannel = channel
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
                    .padding(.bottom, 16)
                }
            }
        }
        .background(themeManager.backgroundPrimary(colorScheme))
    }

    private var serverHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            if let bannerUrl = selectedServer?.bannerUrl,
               let url = APIService.shared.serverBannerURL(serverId: selectedServer?.id ?? "", hash: bannerUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        themeManager.backgroundSecondary(colorScheme)
                    }
                }
                .frame(height: 120)
                .clipped()
            } else {
                themeManager.backgroundSecondary(colorScheme)
                    .frame(height: 80)
            }

            ZStack {
                HStack {
                    if let server = selectedServer {
                        ServerIconView(server: server, size: 40, cornerRadius: 12)
                    }
                    Spacer()
                }

                Text(selectedServer?.name ?? "Select a server")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .shadow(radius: selectedServer?.bannerUrl != nil ? 2 : 0)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()
                    // Chevron opens the server menu (manage / leave).
                    Button {
                        if let server = selectedServer {
                            menuServer = server
                            HapticFeedback.medium()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Server menu")
                    .disabled(selectedServer == nil)
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(selectedServer?.bannerUrl != nil ? 0.0 : 0.0),
                        Color.black.opacity(selectedServer?.bannerUrl != nil ? 0.4 : 0.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: selectedServer?.bannerUrl != nil ? 120 : 80)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedServer?.bannerUrl != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedServer?.id)
    }

    // MARK: - Data Loading

    private func loadServers() async {
        await MainActor.run { isLoadingServers = true }
        do {
            let fetched = try await apiService.getUserGuilds()
            await MainActor.run {
                if !fetched.isEmpty {
                    appState.railServers = fetched
                    appState.restServers = fetched
                } else {
                    appState.railServers = Server.previewServers
                }
                if appState.railSelectedServer == nil {
                    appState.railSelectedServer = appState.railServers.first
                }
                isLoadingServers = false
            }
            if let server = appState.railSelectedServer ?? appState.railServers.first {
                await loadChannels(for: server)
            }
        } catch {
            await MainActor.run {
                let preview = Server.previewServers
                appState.railServers = preview
                appState.railSelectedServer = preview.first
                isLoadingServers = false
            }
            if let server = appState.railSelectedServer {
                await loadChannels(for: server)
            }
        }
    }

    private func loadChannels(for server: Server) async {
        await MainActor.run {
            isLoadingChannels = true
            channelsError = nil
        }

        let loaded: [Channel]
        if let gatewayGuild = appState.gatewayGuilds.first(where: { $0.id == server.id }),
           !gatewayGuild.channels.isEmpty {
            loaded = gatewayGuild.channels.sorted { $0.position < $1.position }
        } else if !server.channels.isEmpty {
            loaded = server.channels.sorted { $0.position < $1.position }
        } else {
            do {
                loaded = try await apiService.getGuildChannels(guildId: server.id)
                    .sorted { $0.position < $1.position }
            } catch {
                await MainActor.run {
                    channelsError = "Failed to load channels: \(error.localizedDescription)"
                    isLoadingChannels = false
                }
                return
            }
        }

        await MainActor.run {
            appState.railChannels = loaded
            appState.railSelectedServer = server
            appState.selectedServer = server
            isLoadingChannels = false
        }
    }

    private func selectServer(_ server: Server) {
        appState.railSelectedServer = server
        appState.selectedServer = server
    }

    // MARK: - Channel Grouping Helpers

    private var categoriesById: [String: Channel] {
        Dictionary(uniqueKeysWithValues: channels
            .filter { $0.type == .category }
            .map { ($0.id, $0) }
        )
    }

    private var groupedChannels: [String: [Channel]] {
        Dictionary(grouping: channels.filter { $0.type != .category }) { $0.parentId ?? "" }
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

// MARK: - Preview

#Preview {
    GuildNavigationView()
        .environment(ThemeManager())
        .environment(AppState())
}
