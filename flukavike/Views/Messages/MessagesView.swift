//
//  MessagesView.swift
//  Direct Messages (DMs) tab
//

import SwiftUI

struct MessagesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var dmChannels: [DMChannelResponse] = []
    @State private var isLoading: Bool = false
    @State private var selectedChannel: DMChannelResponse?
    @State private var showNewMessageSheet: Bool = false

    private let apiService = APIService.shared

    var body: some View {
        NavigationStack {
            List {
                if isLoading && dmChannels.isEmpty {
                    HStack { Spacer(); ProgressView().padding(.vertical, 40); Spacer() }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if dmChannels.isEmpty {
                    emptyStateSection
                } else {
                    ForEach(dmChannels) { dm in
                        DMConversationRow(dm: dm)
                            .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .onTapGesture { selectedChannel = dm }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { dmChannels.removeAll { $0.id == dm.id } }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showNewMessageSheet = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    }
                }
            }
            .sheet(item: $selectedChannel) { dm in
                NavigationStack {
                    ChatView(channel: Channel.dmChannel(
                        id: dm.id,
                        name: dm.recipients.first?.formattedName ?? "DM"
                    ))
                }
            }
            .sheet(isPresented: $showNewMessageSheet) {
                NewMessageView { userId in
                    openDM(with: userId)
                }
                .environment(themeManager)
                .environment(appState)
            }
            .task { await loadDMChannels() }
            .refreshable { await loadDMChannels() }
        }
    }

    // MARK: - Empty State
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                Text("No Messages Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                Text("Start a conversation with your friends")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                Button(action: { showNewMessageSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                        Text("New Message").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(themeManager.accentColor.color))
                }
                .padding(.top, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Data Loading
    private func loadDMChannels() async {
        await MainActor.run { isLoading = true }
        do {
            let channels = try await apiService.getUserDMChannels()
            await MainActor.run {
                // Show only 1-on-1 DMs (type 1) sorted by most recent
                dmChannels = channels.filter { $0.type == 1 }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func openDM(with userId: String) {
        Task {
            do {
                let dm = try await apiService.openDMChannel(userId: userId)
                await MainActor.run {
                    if !dmChannels.contains(where: { $0.id == dm.id }) {
                        dmChannels.insert(dm, at: 0)
                    }
                    selectedChannel = dm
                    showNewMessageSheet = false
                }
            } catch {
                NSLog("[flukavike] Failed to open DM: %@", String(describing: error))
            }
        }
    }
}

// MARK: - DM Conversation Row
struct DMConversationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let dm: DMChannelResponse

    private var recipient: User? { dm.recipients.first }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let user = recipient {
                    AvatarView(user: user, size: 50)
                    Circle()
                        .fill(user.status.color)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 2))
                        .offset(x: 2, y: 2)
                } else {
                    Circle().fill(themeManager.backgroundTertiary(colorScheme)).frame(width: 50, height: 50)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipient?.formattedName ?? "Unknown")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                Text(recipient?.displayUsername ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.clear))
    }
}

// MARK: - New Message View

private struct ServerMemberEntry: Identifiable {
    let user: User
    let serverName: String
    var id: String { user.id }
}

struct NewMessageView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onSelectUser: (String) -> Void

    @State private var searchQuery: String = ""
    @State private var friends: [RelationshipResponse] = []
    @State private var serverMembers: [ServerMemberEntry] = []
    @State private var isLoading: Bool = false

    private let apiService = APIService.shared

    private var friendUsers: [User] { friends.filter { $0.isFriend }.map { $0.user } }
    private var friendIds: Set<String> { Set(friendUsers.map { $0.id }) }

    private var filteredFriends: [User] {
        guard !searchQuery.isEmpty else { return friendUsers }
        let q = searchQuery.lowercased()
        return friendUsers.filter {
            $0.username.lowercased().contains(q) || ($0.displayName?.lowercased().contains(q) ?? false)
        }
    }

    private var filteredMembers: [ServerMemberEntry] {
        // Exclude anyone already in friends list
        let nonFriends = serverMembers.filter { !friendIds.contains($0.user.id) }
        guard !searchQuery.isEmpty else { return nonFriends }
        let q = searchQuery.lowercased()
        return nonFriends.filter {
            $0.user.username.lowercased().contains(q) ||
            ($0.user.displayName?.lowercased().contains(q) ?? false) ||
            $0.serverName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    TextField("Search people...", text: $searchQuery)
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(themeManager.backgroundTertiary(colorScheme)))
                .padding(.horizontal, 16).padding(.vertical, 8)

                if isLoading {
                    ProgressView().padding(.top, 40)
                    Spacer()
                } else if filteredFriends.isEmpty && filteredMembers.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                        Text(searchQuery.isEmpty ? "No people found" : "No results for \"\(searchQuery)\"")
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                        Spacer()
                    }
                } else {
                    List {
                        if !filteredFriends.isEmpty {
                            Section(header: Text("Friends").font(.system(size: 13, weight: .bold))) {
                                ForEach(filteredFriends) { user in
                                    userRow(user, serverName: nil)
                                }
                            }
                        }
                        if !filteredMembers.isEmpty {
                            Section(header: Text("Server Members").font(.system(size: 13, weight: .bold))) {
                                ForEach(filteredMembers) { entry in
                                    userRow(entry.user, serverName: entry.serverName)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(themeManager.backgroundPrimary(colorScheme))
                }
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .task { await loadPeople() }
        }
    }

    @ViewBuilder
    private func userRow(_ user: User, serverName: String?) -> some View {
        UserRow(user: user, serverName: serverName)
            .listRowBackground(themeManager.backgroundPrimary(colorScheme))
            .listRowSeparator(.hidden)
            .onTapGesture {
                onSelectUser(user.id)
                dismiss()
            }
    }

    private func loadPeople() async {
        await MainActor.run { isLoading = true }

        // Load friends and server members in parallel
        async let friendsResult = (try? apiService.getUserRelationships()) ?? []
        async let membersResult = loadServerMembers()

        let (f, m) = await (friendsResult, membersResult)
        await MainActor.run {
            friends = f
            serverMembers = m
            isLoading = false
        }
    }

    private func loadServerMembers() async -> [ServerMemberEntry] {
        let selfId = appState.currentUser?.id
        var seen = Set<String>()
        var entries: [ServerMemberEntry] = []
        for guild in appState.gatewayGuilds {
            if let fetched = try? await apiService.getGuildMembers(guildId: guild.id, limit: 100) {
                for member in fetched {
                    if let user = member.user, user.id != selfId, seen.insert(user.id).inserted {
                        entries.append(ServerMemberEntry(user: user, serverName: guild.name))
                    }
                }
            }
        }
        return entries
    }
}

// MARK: - User Row
struct UserRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let user: User
    var serverName: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(user: user, size: 44)
                Circle()
                    .fill(user.status.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.formattedName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                Text(user.displayUsername)
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                if let serverName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 10))
                        Text(serverName)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                    .padding(.top, 1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Channel Extension for DM
extension Channel {
    static func dmChannel(id: String, name: String) -> Channel {
        Channel(id: id, serverId: "", name: name, topic: nil, type: .text,
                position: 0, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date())
    }
}

// MARK: - Preview
#Preview {
    MessagesView()
        .environment(ThemeManager())
        .environment(AppState())
}
