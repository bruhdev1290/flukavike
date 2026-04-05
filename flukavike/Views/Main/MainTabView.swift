//
//  MainTabView.swift
//

import SwiftUI

struct MainTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable, Identifiable {
        case home = "Home"
        case chat = "Chat"
        case starred = "Starred"
        case notifications = "Notifications"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .chat: return "bubble.left.fill"
            case .starred: return "star.fill"
            case .notifications: return "bell.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tag(Tab.home)
                .tabItem { Image(systemName: Tab.home.icon); Text(Tab.home.rawValue) }

            NavigationStack { MessagesView() }
                .tag(Tab.chat)
                .tabItem { Image(systemName: Tab.chat.icon); Text(Tab.chat.rawValue) }
                .badge(appState.unreadMessages > 0 ? appState.unreadMessages : 0)

            NavigationStack { 
                StarredChannelsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                .tag(Tab.starred)
                .tabItem { Image(systemName: Tab.starred.icon); Text(Tab.starred.rawValue) }

            NavigationStack { NotificationsView() }
                .tag(Tab.notifications)
                .tabItem { Image(systemName: Tab.notifications.icon); Text(Tab.notifications.rawValue) }
                .badge(appState.unreadNotifications > 0 ? appState.unreadNotifications : 0)
        }
        .tint(themeManager.textPrimary(colorScheme))
    }
}

#Preview {
    MainTabView()
        .environment(ThemeManager())
        .environment(AppState())
}
