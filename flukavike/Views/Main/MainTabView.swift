//
//  MainTabView.swift
//  Discord-style tab bar
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
        case notifications = "Notifications"
        case you = "You"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .chat: return "bubble.left.fill"
            case .notifications: return "bell.fill"
            case .you: return "person.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tag(Tab.home)
                .tabItem {
                    Image(systemName: Tab.home.icon)
                    Text(Tab.home.rawValue)
                }
                
                NavigationStack {
                    MessagesView()
                }
                .tag(Tab.chat)
                .tabItem {
                    Image(systemName: Tab.chat.icon)
                    Text(Tab.chat.rawValue)
                }
                .badge(appState.unreadMessages > 0 ? appState.unreadMessages : 0)
                
                NavigationStack {
                    NotificationsView()
                }
                .tag(Tab.notifications)
                .tabItem {
                    Image(systemName: Tab.notifications.icon)
                    Text(Tab.notifications.rawValue)
                }
                .badge(appState.unreadNotifications > 0 ? appState.unreadNotifications : 0)
                
                NavigationStack {
                    ProfileView()
                }
                .tag(Tab.you)
                .tabItem {
                    Image(systemName: Tab.you.icon)
                    Text(Tab.you.rawValue)
                }
            }
            .tint(themeManager.textPrimary(colorScheme))
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environment(ThemeManager())
        .environment(AppState())
}
