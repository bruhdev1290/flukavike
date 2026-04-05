//
//  StarredChannelsView.swift
//  Shows channels the user has starred via the ★ button in ChatView.
//

import SwiftUI

// MARK: - Starred Channels Manager
@Observable
class StarredChannelsManager {
    static let shared = StarredChannelsManager()
    private let idsKey = "starred_channel_ids"
    private let namesKey = "starred_server_names"   // [channelId: serverName]
    private let channelsKey = "starred_channel_data" // [channelId: channelJson]

    private(set) var starredIds: Set<String>
    private var serverNames: [String: String]

    private init() {
        starredIds = Set(UserDefaults.standard.stringArray(forKey: idsKey) ?? [])
        serverNames = (UserDefaults.standard.dictionary(forKey: "starred_server_names") as? [String: String]) ?? [:]
    }

    func serverName(for channelId: String) -> String {
        serverNames[channelId] ?? ""
    }

    /// Toggles the starred state. Pass serverName so it can be shown even when guild data is incomplete.
    @discardableResult
    func toggle(channelId: String, serverName: String) -> Bool {
        if starredIds.contains(channelId) {
            starredIds.remove(channelId)
            serverNames.removeValue(forKey: channelId)
        } else {
            starredIds.insert(channelId)
            if !serverName.isEmpty { serverNames[channelId] = serverName }
        }
        UserDefaults.standard.set(Array(starredIds), forKey: idsKey)
        UserDefaults.standard.set(serverNames, forKey: namesKey)
        return starredIds.contains(channelId)
    }

    func isStarred(_ channelId: String) -> Bool {
        starredIds.contains(channelId)
    }

    /// Returns starred channels found across all guilds, with correct server name.
    /// Uses REST servers for proper names (gateway guilds often lack `name`).
    func starredChannels(from guilds: [Server], restServers: [Server] = []) -> [(serverName: String, channel: Channel)] {
        var result: [(String, Channel)] = []
        for guild in guilds {
            for channel in guild.channels.sorted(by: { $0.position < $1.position }) where starredIds.contains(channel.id) {
                // Priority: REST server name → stored name → gateway name → stored server name
                let restName = restServers.first(where: { $0.id == guild.id })?.name
                let name: String
                if let r = restName, !r.isEmpty, r != "Unknown Server" {
                    name = r
                } else if let stored = serverNames[channel.id], !stored.isEmpty, stored != "Unknown Server" {
                    name = stored
                } else if guild.name != "Unknown Server", !guild.name.isEmpty {
                    name = guild.name
                } else {
                    name = serverNames[channel.id] ?? guild.name
                }
                result.append((name, channel))
            }
        }
        return result
    }
}

// MARK: - Starred Channels View
struct StarredChannelsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var selectedChannel: Channel?

    private var starred: [(serverName: String, channel: Channel)] {
        StarredChannelsManager.shared.starredChannels(from: appState.gatewayGuilds, restServers: appState.restServers)
    }

    var body: some View {
        Group {
            if starred.isEmpty {
                emptyState
            } else {
                channelList
            }
        }
        .navigationTitle("Starred")
        .navigationBarTitleDisplayMode(.large)
        .background(themeManager.backgroundPrimary(colorScheme))
        .sheet(item: $selectedChannel) { channel in
            NavigationStack {
                ChatView(channel: channel)
            }
        }
    }
    
    private var channelList: some View {
        List {
            ForEach(starred, id: \.channel.id) { item in
                Button(action: { selectedChannel = item.channel }) {
                    HStack(spacing: 12) {
                        Image(systemName: item.channel.type == .announcement ? "megaphone.fill" : "number")
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.accentColor.color)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(item.channel.name)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                            Text(item.serverName)
                                .font(.system(size: 13))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                        }

                        Spacer()

                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                .listRowSeparator(.hidden)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
        .background(themeManager.backgroundPrimary(colorScheme))
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 56))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            Text("No Starred Channels")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            Text("Tap the ★ icon in any channel to pin it here for quick access.")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
