//
//  ChannelListView.swift
//  Channel browser with list design
//

import SwiftUI

struct ChannelListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var servers: [Server] = []
    @State private var channels: [Channel] = []
    @State private var selectedChannel: Channel?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let apiService = APIService.shared
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading && channels.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 20)
                        Spacer()
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                    .listRowSeparator(.hidden)
                }

                if let errorMessage, channels.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                        .listRowSeparator(.hidden)
                }

                ForEach(groupedChannels.keys.sorted(), id: \.self) { category in
                    Section {
                        ForEach(groupedChannels[category] ?? []) { channel in
                            ChannelRow(
                                channel: channel,
                                isSelected: selectedChannel?.id == channel.id
                            )
                            .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                            .onTapGesture {
                                selectedChannel = channel
                                appState.selectedChannel = channel
                            }
                        }
                    } header: {
                        Text(category.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                }
            }
            .listStyle(.plain)
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Channels")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if servers.isEmpty {
                    await loadServersAndChannels()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !servers.isEmpty {
                            Section("Servers") {
                                ForEach(servers) { server in
                                    Button {
                                        appState.selectedServer = server
                                        Task {
                                            await loadChannels(for: server)
                                        }
                                    } label: {
                                        if appState.selectedServer?.id == server.id {
                                            Label(server.name, systemImage: "checkmark")
                                        } else {
                                            Text(server.name)
                                        }
                                    }
                                }
                            }
                            Divider()
                        }

                        Button("Refresh") {
                            Task {
                                await loadServersAndChannels()
                            }
                        }

                        Divider()
                        Button("Create Channel") {}
                        Button("Create Category") {}
                        Button("Channel Settings") {}
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
            }
            .sheet(item: $selectedChannel) { channel in
                NavigationStack {
                    ChatView(channel: channel)
                }
            }
        }
    }
    
    private var groupedChannels: [String: [Channel]] {
        Dictionary(grouping: channels) { channel in
            channel.parentId ?? "TEXT CHANNELS"
        }
    }

    private func loadServersAndChannels() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetchedServers = try await apiService.getUserGuilds()
            let server = appState.selectedServer.flatMap { current in
                fetchedServers.first { $0.id == current.id }
            } ?? fetchedServers.first

            await MainActor.run {
                servers = fetchedServers
                appState.selectedServer = server
            }

            if let server {
                await loadChannels(for: server)
            } else {
                await MainActor.run {
                    channels = []
                    isLoading = false
                    errorMessage = "No servers available for this account."
                }
            }
        } catch {
            await MainActor.run {
                channels = []
                isLoading = false
                errorMessage = "Failed to load servers. Please try again."
            }
        }
    }

    private func loadChannels(for server: Server) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetchedChannels = try await apiService.getGuildChannels(guildId: server.id)
            await MainActor.run {
                channels = fetchedChannels.sorted { $0.position < $1.position }
                appState.selectedServer = server
                isLoading = false
            }
        } catch {
            await MainActor.run {
                channels = []
                isLoading = false
                errorMessage = "Failed to load channels for \(server.name)."
            }
        }
    }
}

// MARK: - Channel Row
struct ChannelRow: View {
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
                
                // Participant count for voice channels
                if channel.type == .voice {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("12")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
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

// MARK: - Mention Badge
struct MentionBadge: View {
    @Environment(ThemeManager.self) private var themeManager
    let count: Int
    
    var body: some View {
        Text("@\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(themeManager.accentColor.color)
            )
    }
}

// MARK: - Preview
#Preview {
    ChannelListView()
        .environment(ThemeManager())
        .environment(AppState())
}
