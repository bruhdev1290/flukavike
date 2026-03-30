//
//  ProfileView.swift
//  User profile
//

import SwiftUI

struct ProfileView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var user: User = User.preview
    @State private var selectedTab: ProfileTab = .posts
    
    enum ProfileTab: String, CaseIterable, Identifiable {
        case posts = "Posts"
        case media = "Media"
        case replies = "Replies"
        case likes = "Likes"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with Banner
                    profileHeader
                    
                    // Bio Section
                    bioSection
                    
                    // Stats Row
                    statsSection
                    
                    // Action Buttons
                    actionButtons
                    
                    Divider()
                        .padding(.top, 16)
                        .background(themeManager.separator(colorScheme))
                    
                    // Content Tabs
                    contentSection
                }
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Share Profile") {}
                        Button("Copy Link") {}
                        Divider()
                        Button("Settings") {}
                        Button("Log Out", role: .destructive) {}
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            if let bannerUrl = user.bannerUrl {
                AsyncImage(url: URL(string: bannerUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    bannerPlaceholder
                }
            } else {
                bannerPlaceholder
            }
            
            // Avatar (overlapping banner)
            AvatarView(user: user, size: 80)
                .overlay(
                    Circle()
                        .stroke(themeManager.backgroundPrimary(colorScheme), lineWidth: 4)
                )
                .offset(x: 16, y: 40)
        }
        .frame(height: 120)
        .padding(.bottom, 40)
    }
    
    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: [
                themeManager.accentColor.color.opacity(0.8),
                themeManager.accentColor.color.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Bio Section
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.formattedName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Text(user.displayUsername)
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
                
                Spacer()
                
                if let customStatus = user.customStatus {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(user.status.color)
                            .frame(width: 8, height: 8)
                        
                        Text(customStatus)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeManager.backgroundSecondary(colorScheme))
                    )
                }
            }
            
            if let bio = user.bio {
                Text(bio)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .lineSpacing(4)
            }
            
            HStack(spacing: 16) {
                Label("Joined \(user.createdAt, style: .date)", systemImage: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                
                if user.bot {
                    BotBadge()
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 24) {
            StatView(count: 1_247, label: "Posts")
            StatView(count: 892, label: "Following")
            StatView(count: 3_421, label: "Followers")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Text("Edit Profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeManager.separator(colorScheme), lineWidth: 1)
                    )
            }
            
            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(width: 44, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeManager.separator(colorScheme), lineWidth: 1)
                    )
            }
            
            Button(action: {}) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(themeManager.accentColor.color)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Tab Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(ProfileTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundStyle(selectedTab == tab ? themeManager.textPrimary(colorScheme) : themeManager.textSecondary(colorScheme))
                                
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(themeManager.accentColor.color)
                                        .frame(height: 3)
                                        .cornerRadius(1.5)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 3)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            
            // Content based on selected tab
            VStack(spacing: 0) {
                switch selectedTab {
                case .posts:
                    postsContent
                case .media:
                    mediaContent
                case .replies:
                    repliesContent
                case .likes:
                    likesContent
                }
            }
            .padding(.top, 16)
        }
    }
    
    private var postsContent: some View {
        VStack(spacing: 0) {
            ForEach(Message.previewMessages) { message in
                MessageBubble(message: message)
                
                if message.id != Message.previewMessages.last?.id {
                    Divider()
                        .padding(.leading, 68)
                        .background(themeManager.separator(colorScheme))
                }
            }
        }
    }
    
    private var mediaContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 2) {
            ForEach(0..<12) { index in
                RoundedRectangle(cornerRadius: 0)
                    .fill(themeManager.backgroundTertiary(colorScheme))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    )
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var repliesContent: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Replies Yet",
            message: "Your replies to other posts will appear here."
        )
        .padding(.top, 40)
    }
    
    private var likesContent: some View {
        EmptyStateView(
            icon: "heart",
            title: "No Likes Yet",
            message: "Posts you like will appear here."
        )
        .padding(.top, 40)
    }
}

// MARK: - Stat View
struct StatView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let count: Int
    let label: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Text(formattedCount)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedCount: String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Bot Badge
struct BotBadge: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text("BOT")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(themeManager.accentColor.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(themeManager.accentColor.color.opacity(0.15))
            )
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
        .environment(ThemeManager())
}
