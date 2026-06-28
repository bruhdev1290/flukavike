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
        case messages = "Messages"
        case notifications = "Notifications"
        case you = "You"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .messages: return "bubble.left.fill"
            case .notifications: return "bell.fill"
            case .you: return "person.fill"
            }
        }
    }

    private var quickSwitcherBinding: Binding<Bool> {
        Binding(
            get: { appState.isQuickSwitcherPresented },
            set: { appState.isQuickSwitcherPresented = $0 }
        )
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeShellView()
                    .tag(Tab.home)
                    .tabItem { Image(systemName: Tab.home.icon); Text(Tab.home.rawValue) }

                MessagesView()
                    .tag(Tab.messages)
                    .tabItem { Image(systemName: Tab.messages.icon); Text(Tab.messages.rawValue) }
                    .badge(appState.unreadMessages > 0 ? appState.unreadMessages : 0)

                NotificationsView()
                    .tag(Tab.notifications)
                    .tabItem { Image(systemName: Tab.notifications.icon); Text(Tab.notifications.rawValue) }
                    .badge(appState.unreadNotifications > 0 ? appState.unreadNotifications : 0)

                ProfileView()
                    .tag(Tab.you)
                    .tabItem { Image(systemName: Tab.you.icon); Text(Tab.you.rawValue) }
            }
            .tint(themeManager.textPrimary(colorScheme))
            .onChange(of: appState.pendingChannelNavigation) { _, pending in
                guard pending != nil else { return }
                selectedTab = .home
            }
            .onChange(of: appState.pendingDMNavigation) { _, pending in
                guard pending != nil else { return }
                selectedTab = .messages
            }

            // Hidden trigger for the hardware-keyboard ⌘-K shortcut.
            Button { appState.isQuickSwitcherPresented = true } label: { EmptyView() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .sheet(isPresented: quickSwitcherBinding) {
            QuickSwitcherView()
                .environment(themeManager)
                .environment(appState)
                .environment(StarredChannelsStore.shared)
                .presentationDetents([.fraction(0.7), .large])
        }
    }
}

#Preview {
    MainTabView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(PresenceStore.shared)
        .environment(StarredChannelsStore.shared)
}
