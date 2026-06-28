//
//  QuickSwitcherView.swift
//  Global ⌘-K quick switcher for channels and DMs.
//

import SwiftUI

struct QuickSwitcherView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(StarredChannelsStore.self) private var starredStore

    @State private var query: String = ""
    @FocusState private var isSearchFocused: Bool

    private var allServers: [Server] {
        var merged: [String: Server] = [:]
        for server in appState.gatewayGuilds + appState.restServers {
            merged[server.id] = server
        }
        return Array(merged.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var allChannels: [(server: Server, channel: Channel)] {
        allServers.flatMap { server in
            server.channels
                .filter { $0.type != .category }
                .sorted { $0.position < $1.position }
                .map { (server, $0) }
        }
    }

    private var filteredChannels: [(server: Server, channel: Channel)] {
        guard !query.isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return allChannels.filter { pair in
            pair.channel.name.localizedCaseInsensitiveContains(trimmed) ||
            pair.server.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var filteredDMs: [DMChannelResponse] {
        guard !query.isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.dmChannels.filter { dm in
            dm.recipients.contains { recipient in
                recipient.formattedName.localizedCaseInsensitiveContains(trimmed) ||
                recipient.username.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }

    private var starredItems: [(serverName: String, channel: Channel)] {
        starredStore.starredChannels(from: appState.gatewayGuilds, restServers: appState.restServers)
    }

    private var filteredStarred: [(serverName: String, channel: Channel)] {
        guard !query.isEmpty else { return starredItems }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return starredItems.filter { item in
            item.channel.name.localizedCaseInsensitiveContains(trimmed) ||
            item.serverName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                List {
                    if !filteredStarred.isEmpty {
                        Section("Starred") {
                            ForEach(filteredStarred, id: \.channel.id) { item in
                                row(
                                    icon: item.channel.type == .announcement ? "megaphone.fill" : "number",
                                    title: "#\(item.channel.name)",
                                    subtitle: item.serverName,
                                    isStarred: true
                                ) {
                                    open(channel: item.channel, serverId: nil)
                                }
                            }
                        }
                    }

                    if !filteredChannels.isEmpty {
                        Section("Channels") {
                            ForEach(filteredChannels, id: \.channel.id) { pair in
                                row(
                                    icon: pair.channel.type.icon,
                                    title: "#\(pair.channel.name)",
                                    subtitle: pair.server.name,
                                    isStarred: starredStore.isStarred(pair.channel.id)
                                ) {
                                    open(channel: pair.channel, serverId: pair.server.id)
                                }
                            }
                        }
                    }

                    if !filteredDMs.isEmpty {
                        Section("Direct Messages") {
                            ForEach(filteredDMs) { dm in
                                let recipient = dm.recipients.first
                                row(
                                    icon: "at",
                                    title: recipient?.formattedName ?? "Unknown",
                                    subtitle: recipient?.displayUsername ?? "",
                                    isStarred: false
                                ) {
                                    open(dm: dm)
                                }
                            }
                        }
                    }

                    if query.isEmpty && filteredStarred.isEmpty && filteredChannels.isEmpty && filteredDMs.isEmpty {
                        Section {
                            Text("Start typing to jump to a channel or conversation.")
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Quick Switcher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
            }
        }
        .onAppear { isSearchFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textTertiary(colorScheme))

            TextField("Jump to channel or DM", text: $query)
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
                .focused($isSearchFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.backgroundTertiary(colorScheme))
        )
    }

    private func row(
        icon: String,
        title: String,
        subtitle: String,
        isStarred: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(themeManager.accentColor.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isStarred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(themeManager.backgroundPrimary(colorScheme))
        .listRowSeparator(.hidden)
    }

    private func open(channel: Channel, serverId: String?) {
        let targetServerId = serverId ?? channel.serverId
        appState.pendingChannelNavigation = AppState.ChannelNavigation(
            serverId: targetServerId,
            channelId: channel.id
        )
        dismiss()
    }

    private func open(dm: DMChannelResponse) {
        appState.pendingDMNavigation = AppState.DMNavigation(
            channelId: dm.id,
            userId: dm.recipients.first?.id
        )
        dismiss()
    }
}

#Preview {
    QuickSwitcherView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(StarredChannelsStore.shared)
}
