//
//  MessagesView.swift
//  Direct Messages (DMs) tab
//

import SwiftUI

struct MessagesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    
    @State private var conversations: [DMConversation] = []
    @State private var isLoading: Bool = false
    @State private var selectedConversation: DMConversation?
    @State private var showNewMessageSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                if conversations.isEmpty && !isLoading {
                    emptyStateSection
                } else {
                    ForEach(conversations) { conversation in
                        DMConversationRow(conversation: conversation)
                            .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .onTapGesture {
                                selectedConversation = conversation
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteConversation(conversation)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    markAsRead(conversation)
                                } label: {
                                    Label("Read", systemImage: "checkmark")
                                }
                                .tint(themeManager.accentColor.color)
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
            .sheet(item: $selectedConversation) { conversation in
                NavigationStack {
                    ChatView(
                        channel: Channel.dmChannel(
                            id: conversation.id,
                            name: conversation.user.formattedName
                        )
                    )
                }
            }
            .sheet(isPresented: $showNewMessageSheet) {
                NewMessageView()
            }
            .onAppear {
                loadConversations()
            }
            .refreshable {
                await refreshConversations()
            }
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
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("New Message")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.accentColor.color)
                    )
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
    private func loadConversations() {
        // Use preview data for now
        if conversations.isEmpty {
            conversations = DMConversation.previewConversations
        }
    }
    
    private func refreshConversations() async {
        // TODO: Implement API call to fetch DMs
        // let fetched = try? await APIService.shared.getDMConversations()
        // await MainActor.run { conversations = fetched ?? [] }
    }
    
    private func deleteConversation(_ conversation: DMConversation) {
        withAnimation {
            conversations.removeAll { $0.id == conversation.id }
        }
    }
    
    private func markAsRead(_ conversation: DMConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            var updated = conversation
            updated.unreadCount = 0
            withAnimation {
                conversations[index] = updated
            }
        }
        updateUnreadCount()
    }
    
    private func updateUnreadCount() {
        let total = conversations.reduce(0) { $0 + $1.unreadCount }
        appState.unreadMessages = total
    }
}

// MARK: - DM Conversation Model
struct DMConversation: Identifiable, Equatable {
    let id: String
    let user: User
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
    var isRead: Bool { unreadCount == 0 }
    
    static let previewConversations = [
        DMConversation(
            id: "dm1",
            user: User(
                id: "u2",
                username: "bob",
                displayName: "Bob Smith",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: nil,
                status: .online,
                customStatus: nil,
                bot: false,
                createdAt: Date()
            ),
            lastMessage: "Hey, are we still on for tonight?",
            lastMessageTime: Date().addingTimeInterval(-300),
            unreadCount: 2
        ),
        DMConversation(
            id: "dm2",
            user: User(
                id: "u3",
                username: "charlie",
                displayName: "Charlie Davis",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: "Designer",
                status: .idle,
                customStatus: "AFK",
                bot: false,
                createdAt: Date()
            ),
            lastMessage: "The designs look great! 🎨",
            lastMessageTime: Date().addingTimeInterval(-1800),
            unreadCount: 0
        ),
        DMConversation(
            id: "dm3",
            user: User(
                id: "u4",
                username: "david",
                displayName: "David Wilson",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: "iOS Developer",
                status: .dnd,
                customStatus: "Focus mode",
                bot: false,
                createdAt: Date()
            ),
            lastMessage: "Can you review my PR?",
            lastMessageTime: Date().addingTimeInterval(-3600),
            unreadCount: 1
        ),
        DMConversation(
            id: "dm4",
            user: User(
                id: "u5",
                username: "elias",
                displayName: "Elias Johnson",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: nil,
                status: .offline,
                customStatus: nil,
                bot: false,
                createdAt: Date()
            ),
            lastMessage: "Thanks for the help yesterday!",
            lastMessageTime: Date().addingTimeInterval(-86400),
            unreadCount: 0
        )
    ]
}

// MARK: - DM Conversation Row
struct DMConversationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let conversation: DMConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status indicator
            ZStack(alignment: .bottomTrailing) {
                AvatarView(user: conversation.user, size: 50)
                
                // Status indicator
                Circle()
                    .fill(conversation.user.status.color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.user.formattedName)
                        .font(.system(size: 16, weight: conversation.isRead ? .medium : .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Spacer()
                    
                    Text(conversation.lastMessageTime, style: .relative)
                        .font(.system(size: 13))
                        .foregroundStyle(conversation.isRead ? themeManager.textTertiary(colorScheme) : themeManager.accentColor.color)
                }
                
                HStack(spacing: 4) {
                    Text(conversation.lastMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(conversation.isRead ? themeManager.textSecondary(colorScheme) : themeManager.textPrimary(colorScheme))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        MentionBadge(count: conversation.unreadCount)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(conversation.isRead ? Color.clear : themeManager.accentColor.color.opacity(0.05))
        )
    }
}

// MARK: - New Message View
struct NewMessageView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery: String = ""
    @State private var users: [User] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                    TextField("Search users...", text: $searchQuery)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Results
                List {
                    if users.isEmpty && !searchQuery.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                Text("No users found")
                                    .font(.system(size: 15))
                                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                                Spacer()
                            }
                            .padding(.vertical, 20)
                            .listRowBackground(Color.clear)
                        }
                    } else if !users.isEmpty {
                        Section(header: Text("Users").font(.system(size: 13, weight: .bold))) {
                            ForEach(users) { user in
                                UserRow(user: user)
                                    .onTapGesture {
                                        // Start conversation
                                        dismiss()
                                    }
                            }
                        }
                    } else {
                        // Suggested users
                        Section(header: Text("Suggested").font(.system(size: 13, weight: .bold))) {
                            ForEach([
                                User.preview,
                                User(id: "u2", username: "bob", displayName: "Bob Smith", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .online, customStatus: nil, bot: false, createdAt: Date()),
                                User(id: "u3", username: "charlie", displayName: "Charlie Davis", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .idle, customStatus: "AFK", bot: false, createdAt: Date())
                            ]) { user in
                                UserRow(user: user)
                                    .onTapGesture {
                                        dismiss()
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(themeManager.backgroundPrimary(colorScheme))
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                searchUsers(query: newValue)
            }
        }
    }
    
    private func searchUsers(query: String) {
        // TODO: Implement API search
        if query.isEmpty {
            users = []
        } else {
            // Preview search
            let allUsers = [
                User.preview,
                User(id: "u2", username: "bob", displayName: "Bob Smith", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .online, customStatus: nil, bot: false, createdAt: Date()),
                User(id: "u3", username: "charlie", displayName: "Charlie Davis", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .idle, customStatus: "AFK", bot: false, createdAt: Date()),
                User(id: "u4", username: "david", displayName: "David Wilson", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .dnd, customStatus: nil, bot: false, createdAt: Date())
            ]
            users = allUsers.filter {
                $0.username.lowercased().contains(query.lowercased()) ||
                $0.formattedName.lowercased().contains(query.lowercased())
            }
        }
    }
}

// MARK: - User Row
struct UserRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(user: user, size: 44)
                
                Circle()
                    .fill(user.status.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 2)
                    )
                    .offset(x: 1, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.formattedName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                Text(user.displayUsername)
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
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
        Channel(
            id: id,
            serverId: "",
            name: name,
            topic: nil,
            type: .text,
            position: 0,
            parentId: nil,
            unreadCount: 0,
            mentionCount: 0,
            lastMessageAt: Date()
        )
    }
}

// MARK: - Preview
#Preview {
    MessagesView()
        .environment(ThemeManager())
        .environment(AppState())
}
