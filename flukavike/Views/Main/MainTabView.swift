//
//  MainTabView.swift
//  3-branch shell matching the Flutter client: Home / Notifications / You
//

import SwiftUI

struct MainTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable, Identifiable {
        case home = "Home"
        case notifications = "Notifications"
        case you = "You"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .notifications: return "bell.fill"
            case .you: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeShellView()
                .tag(Tab.home)
                .tabItem { Image(systemName: Tab.home.icon); Text(Tab.home.rawValue) }

            NotificationsView()
                .tag(Tab.notifications)
                .tabItem { Image(systemName: Tab.notifications.icon); Text(Tab.notifications.rawValue) }
                .badge(appState.unreadNotifications > 0 ? appState.unreadNotifications : 0)

            ProfileView()
                .tag(Tab.you)
                .tabItem { Image(systemName: Tab.you.icon); Text(Tab.you.rawValue) }
        }
        .tint(themeManager.textPrimary(colorScheme))
    }
}

#Preview {
    MainTabView()
        .environment(ThemeManager())
        .environment(AppState())
}
