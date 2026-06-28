//
//  StarredChannelsView.swift
//  Shows channels the user has starred via the ★ button in ChatView.
//

import SwiftUI

struct StarredChannelsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(StarredChannelsStore.self) private var starredStore

    @State private var selectedChannel: Channel?

    private var starred: [(serverName: String, channel: Channel)] {
        starredStore.starredChannels(from: appState.gatewayGuilds, restServers: appState.restServers)
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

                        if item.channel.hasMention {
                            MentionBadge(count: item.channel.mentionCount)
                        } else if item.channel.hasUnread {
                            Circle()
                                .fill(themeManager.accentColor.color)
                                .frame(width: 8, height: 8)
                        }

                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                .listRowSeparator(.hidden)
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        starredStore.remove(channelId: item.channel.id)
                        HapticFeedback.light()
                    } label: {
                        Label("Unstar", systemImage: "star.slash.fill")
                    }
                    .tint(.yellow)
                }
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

#Preview {
    StarredChannelsView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(StarredChannelsStore.shared)
}
