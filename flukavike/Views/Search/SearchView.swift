//
//  SearchView.swift
//  Global search across servers, channels, messages, and users
//

import SwiftUI

// MARK: - Search Result Types
enum SearchResultCategory: String, CaseIterable {
    case servers = "Servers"
    case channels = "Channels"
    case messages = "Messages"
    case users = "Users"
    
    var icon: String {
        switch self {
        case .servers: return "server.rack"
        case .channels: return "number"
        case .messages: return "bubble.left"
        case .users: return "person"
        }
    }
}

struct SearchResult: Identifiable {
    let id: String
    let category: SearchResultCategory
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let metadata: SearchResultMetadata
}

enum SearchResultMetadata {
    case server(Server)
    case channel(Channel, serverName: String?)
    case message(Message, channelName: String, serverName: String?)
    case user(User)
}

// MARK: - Search View
struct SearchView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var selectedCategory: SearchResultCategory? = nil
    
    private var filteredResults: [SearchResult] {
        if let category = selectedCategory {
            return searchResults.filter { $0.category == category }
        }
        return searchResults
    }
    
    private var groupedResults: [(category: SearchResultCategory, results: [SearchResult])] {
        let grouped = Dictionary(grouping: filteredResults) { $0.category }
        return SearchResultCategory.allCases.compactMap { category in
            guard let results = grouped[category], !results.isEmpty else { return nil }
            return (category, results)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filters
                categoryFilterSection

                // Results
                resultsList
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchQuery, prompt: "Search servers, channels, messages, users...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    // MARK: - Category Filter Section
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All button
                FilterChip(
                    title: "All",
                    icon: "line.3.horizontal.decrease",
                    isSelected: selectedCategory == nil,
                    count: searchResults.count
                ) {
                    selectedCategory = nil
                }
                
                ForEach(SearchResultCategory.allCases, id: \.self) { category in
                    let count = searchResults.filter { $0.category == category }.count
                    FilterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        count: count
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Results List
    @ViewBuilder
    private var resultsList: some View {
        if searchQuery.isEmpty {
            emptyStateView
        } else if isSearching {
            loadingView
        } else if searchResults.isEmpty {
            noResultsView
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedResults, id: \.category) { group in
                        Section {
                            ForEach(group.results) { result in
                                SearchResultRow(result: result)
                                    .onTapGesture {
                                        handleResultTap(result)
                                    }
                            }
                        } header: {
                            categoryHeader(group.category, count: group.results.count)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Category Header
    private func categoryHeader(_ category: SearchResultCategory, count: Int) -> some View {
        HStack {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundStyle(themeManager.accentColor.color)
            
            Text(category.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            
            Text("(\(count))")
                .font(.system(size: 13))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.backgroundPrimary(colorScheme))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Text("Search Everything")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            
            Text("Search across all your servers, channels, messages, and users")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Quick suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching for:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                ForEach(["general", "Alice", "update", "help"], id: \.self) { suggestion in
                    Button(action: { searchQuery = suggestion }) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                            Text(suggestion)
                                .font(.system(size: 15))
                            Spacer()
                        }
                        .foregroundStyle(themeManager.accentColor.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.accentColor.color.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        }
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Text("No Results")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            
            Text("We couldn't find anything matching '\(searchQuery)'")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Search Logic
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Simulate async search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var results: [SearchResult] = []
            let lowerQuery = query.lowercased()
            
            // Search Servers
            for server in Server.previewServers {
                if server.name.lowercased().contains(lowerQuery) ||
                   (server.description?.lowercased().contains(lowerQuery) ?? false) {
                    results.append(SearchResult(
                        id: "server-\(server.id)",
                        category: .servers,
                        title: server.name,
                        subtitle: server.description ?? "\(server.memberCount) members",
                        icon: "server.rack",
                        iconColor: themeManager.accentColor.color,
                        metadata: .server(server)
                    ))
                }
            }
            
            // Search Channels
            for server in Server.previewServers {
                for channel in server.channels {
                    if channel.name.lowercased().contains(lowerQuery) ||
                       (channel.topic?.lowercased().contains(lowerQuery) ?? false) {
                        results.append(SearchResult(
                            id: "channel-\(channel.id)",
                            category: .channels,
                            title: channel.name,
                            subtitle: "#\(channel.name) in \(server.name)",
                            icon: channel.type.icon,
                            iconColor: themeManager.textSecondary(colorScheme),
                            metadata: .channel(channel, serverName: server.name)
                        ))
                    }
                }
            }
            
            // Search Messages (preview data)
            let previewMessages = [
                (content: "Hey everyone! The new update is looking great!", author: "Alice", channel: "general", server: "Flukavike HQ"),
                (content: "When is the beta dropping? Can't wait!", author: "Bob", channel: "development", server: "Fluxer Developers"),
                (content: "Check out the new design system", author: "Charlie", channel: "design", server: "Design"),
                (content: "Help needed with SwiftUI animation", author: "David", channel: "help", server: "Flukavike HQ"),
                (content: "Updated the server rules", author: "Elias", channel: "announcements", server: "Flukavike HQ"),
                (content: "General discussion about updates", author: "Alice", channel: "general", server: "Fluxer Developers")
            ]
            
            for (index, msg) in previewMessages.enumerated() {
                if msg.content.lowercased().contains(lowerQuery) ||
                   msg.author.lowercased().contains(lowerQuery) {
                    results.append(SearchResult(
                        id: "msg-\(index)",
                        category: .messages,
                        title: msg.content,
                        subtitle: "\(msg.author) in #\(msg.channel) • \(msg.server)",
                        icon: "bubble.left",
                        iconColor: .green,
                        metadata: .message(
                            Message(
                                id: "m\(index)",
                                channelId: "c\(index)",
                                author: User(
                                    id: "u\(index)",
                                    username: msg.author.lowercased(),
                                    displayName: msg.author,
                                    avatarUrl: nil,
                                    bannerUrl: nil,
                                    bio: nil,
                                    status: .online,
                                    customStatus: nil,
                                    bot: false,
                                    createdAt: Date()
                                ),
                                content: msg.content,
                                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                                editedTimestamp: nil,
                                replyToId: nil,
                                reactions: [],
                                attachments: [],
                                isPinned: false
                            ),
                            channelName: msg.channel,
                            serverName: msg.server
                        )
                    ))
                }
            }
            
            // Search Users
            let previewUsers = [
                User(id: "u1", username: "alice", displayName: "Alice Chen", avatarUrl: nil, bannerUrl: nil, bio: "Building things with Swift", status: .online, customStatus: "Coding...", bot: false, createdAt: Date()),
                User(id: "u2", username: "bob", displayName: "Bob Smith", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .online, customStatus: nil, bot: false, createdAt: Date()),
                User(id: "u3", username: "charlie", displayName: "Charlie Davis", avatarUrl: nil, bannerUrl: nil, bio: "Designer", status: .idle, customStatus: "AFK", bot: false, createdAt: Date()),
                User(id: "u4", username: "david", displayName: "David Wilson", avatarUrl: nil, bannerUrl: nil, bio: "iOS Developer", status: .dnd, customStatus: "Focus mode", bot: false, createdAt: Date()),
                User(id: "u5", username: "elias", displayName: "Elias Johnson", avatarUrl: nil, bannerUrl: nil, bio: nil, status: .offline, customStatus: nil, bot: false, createdAt: Date())
            ]
            
            for user in previewUsers {
                if user.username.lowercased().contains(lowerQuery) ||
                   user.formattedName.lowercased().contains(lowerQuery) ||
                   (user.bio?.lowercased().contains(lowerQuery) ?? false) {
                    results.append(SearchResult(
                        id: "user-\(user.id)",
                        category: .users,
                        title: user.formattedName,
                        subtitle: user.displayUsername + (user.bio != nil ? " • \(user.bio!)" : ""),
                        icon: "person",
                        iconColor: user.status.color,
                        metadata: .user(user)
                    ))
                }
            }
            
            searchResults = results
            isSearching = false
        }
    }
    
    private func handleResultTap(_ result: SearchResult) {
        switch result.metadata {
        case .server(let server):
            // Navigate to the server's first channel via pending navigation
            if let firstChannel = server.channels.first {
                NotificationCenter.default.post(
                    name: .init("ViewChannelIntent"),
                    object: nil,
                    userInfo: ["serverId": server.id, "channelId": firstChannel.id]
                )
            }
            dismiss()
        case .channel(let channel, _):
            NotificationCenter.default.post(
                name: .init("ViewChannelIntent"),
                object: nil,
                userInfo: ["serverId": channel.serverId, "channelId": channel.id]
            )
            dismiss()
        case .message(let message, _, _):
            NotificationCenter.default.post(
                name: .init("ViewChannelIntent"),
                object: nil,
                userInfo: ["serverId": "", "channelId": message.channelId]
            )
            dismiss()
        case .user:
            dismiss()
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : themeManager.textTertiary(colorScheme).opacity(0.2))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : themeManager.textPrimary(colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? themeManager.accentColor.color : themeManager.backgroundTertiary(colorScheme))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(result.iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: result.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(result.iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .lineLimit(1)
                
                Text(result.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(themeManager.backgroundPrimary(colorScheme))
    }
}

// MARK: - Preview
#Preview {
    SearchView()
        .environment(ThemeManager())
        .environment(AppState())
}
