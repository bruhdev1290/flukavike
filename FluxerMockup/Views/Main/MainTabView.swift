//
//  MainTabView.swift
//  Customizable tab bar
//

import SwiftUI

struct MainTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .home
    @State private var showComposeSheet = false
    
    enum Tab: String, CaseIterable, Identifiable {
        case home = "Home"
        case channels = "Channels"
        case compose = "Compose"
        case notifications = "Notifications"
        case profile = "Profile"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .home: return "hexagon.fill"
            case .channels: return "number"
            case .compose: return "plus.circle.fill"
            case .notifications: return "bell.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    var body: some View {
        @Bindable var appState = appState
        
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .tabItem {
                        Image(systemName: Tab.home.icon)
                        Text(Tab.home.rawValue)
                    }
                
                ChannelListView()
                    .tag(Tab.channels)
                    .tabItem {
                        Image(systemName: Tab.channels.icon)
                        Text(Tab.channels.rawValue)
                    }
                
                // Placeholder for compose tab (handled separately)
                Text("")
                    .tag(Tab.compose)
                
                NotificationsView()
                    .tag(Tab.notifications)
                    .tabItem {
                        Image(systemName: Tab.notifications.icon)
                        Text(Tab.notifications.rawValue)
                    }
                    .badge(appState.unreadNotifications)
                
                ProfileView()
                    .tag(Tab.profile)
                    .tabItem {
                        Image(systemName: Tab.profile.icon)
                        Text(Tab.profile.rawValue)
                    }
            }
            .tint(themeManager.accentColor.color)
            
            // Floating Compose Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingComposeButton {
                        showComposeSheet = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // Above tab bar
                }
            }
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposeView()
        }
    }
}

// MARK: - Floating Compose Button
struct FloatingComposeButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    HexagonShape()
                        .fill(themeManager.accentColor.color)
                        .shadow(color: themeManager.accentColor.color.opacity(0.4), 
                                radius: 12, x: 0, y: 4)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Hexagon Shape (Fluxer brand element)
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let side = min(width, height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        for i in 0..<6 {
            let angle = Double(i) * 60.0 - 30.0
            let x = center.x + side/2 * CGFloat(cos(angle * .pi / 180))
            let y = center.y + side/2 * CGFloat(sin(angle * .pi / 180))
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environment(ThemeManager())
        .environment(AppState())
}
