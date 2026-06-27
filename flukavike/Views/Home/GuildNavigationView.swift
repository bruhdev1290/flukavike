//
//  GuildNavigationView.swift
//  Optional Discord-style server rail + channel list layout
//

import SwiftUI

struct GuildNavigationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var servers: [Server] = []
    @State private var selectedServer: Server?
    @State private var channels: [Channel] = []
    @State private var isLoadingServers: Bool = false
    @State private var isLoadingChannels: Bool = false
    @State private var channelsError: String?
    @State private var showJoinServerSheet: Bool = false
    @State private var showSettings: Bool = false

    private let apiService = APIService.shared

    private var isAuthenticated: Bool {
        appState.isAuthenticated
    }

    var body: some View {
        HStack(spacing: 0) {
            serverRail
            channelListPane
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle(selectedServer?.name ?? "Servers")
        .navigationBarTitleDisplayMode(.large)
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
                if !servers.contains(where: { $0.id == server.id }) {
                    servers.insert(server, at: 0)
                }
                selectedServer = server
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
        .navigationDestination(for: Channel.self) { channel in
            Group {
                if channel.type == .voice {
                    VoiceChannelView(channel: channel)
                        .environment(themeManager)
                        .environment(appState)
                } else {
                    ChatView(channel: channel)
                        .environment(themeManager)
                        .environment(appState)
                }
            }
        }
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
        .onChange(of: appState.gatewayGuilds) { _, _ in
            guard let server = selectedServer else { return }
            Task { await loadChannels(for: server) }
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
                    action: { /* TODO: open DM list from rail */ }
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
            selectedServer = server
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
                                NavigationLink(value: channel) {
                                    HomeChannelRow(
                                        channel: channel,
                                        isSelected: false
                                    )
                                }
                                .buttonStyle(.plain)

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

            HStack(spacing: 10) {
                if let server = selectedServer {
                    ServerIconView(server: server, size: 40, cornerRadius: 12)
                }

                Text(selectedServer?.name ?? "Select a server")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .shadow(radius: selectedServer?.bannerUrl != nil ? 2 : 0)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
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
    }

    // MARK: - Data Loading

    private func loadServers() async {
        await MainActor.run { isLoadingServers = true }
        do {
            let fetched = try await apiService.getUserGuilds()
            await MainActor.run {
                if !fetched.isEmpty {
                    servers = fetched
                    appState.restServers = fetched
                } else {
                    servers = Server.previewServers
                }
                if selectedServer == nil {
                    selectedServer = servers.first
                }
                isLoadingServers = false
            }
            if let server = selectedServer ?? servers.first {
                await loadChannels(for: server)
            }
        } catch {
            await MainActor.run {
                servers = Server.previewServers
                selectedServer = servers.first
                isLoadingServers = false
                if let server = selectedServer {
                    channels = server.channels.sorted { $0.position < $1.position }
                }
            }
        }
    }

    private func loadChannels(for server: Server) async {
        await MainActor.run {
            isLoadingChannels = true
            channelsError = nil
            channels = []
        }

        if let gatewayGuild = appState.gatewayGuilds.first(where: { $0.id == server.id }),
           !gatewayGuild.channels.isEmpty {
            await MainActor.run {
                channels = gatewayGuild.channels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
            return
        }

        if !server.channels.isEmpty {
            await MainActor.run {
                channels = server.channels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
            return
        }

        do {
            let fetched = try await apiService.getGuildChannels(guildId: server.id)
            await MainActor.run {
                channels = fetched.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoadingChannels = false
            }
        } catch {
            await MainActor.run {
                channelsError = "Failed to load channels: \(error.localizedDescription)"
                appState.selectedServer = server
                isLoadingChannels = false
            }
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
