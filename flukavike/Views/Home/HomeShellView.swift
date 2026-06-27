//
//  HomeShellView.swift
//  Home branch shell: DMs / Favorites / Guilds sidebar + content
//

import SwiftUI

struct HomeShellView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var selectedSection: HomeSection? = .guilds

    enum HomeSection: Hashable {
        case dms
        case favorites
        case guilds
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .background(themeManager.backgroundPrimary(colorScheme))
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Home") {
                NavigationLink(value: HomeSection.dms) {
                    sidebarRow(
                        icon: "bubble.left.fill",
                        title: "Direct Messages",
                        color: .green
                    )
                }

                NavigationLink(value: HomeSection.favorites) {
                    sidebarRow(
                        icon: "star.fill",
                        title: "Favorites",
                        color: .yellow
                    )
                }

                NavigationLink(value: HomeSection.guilds) {
                    sidebarRow(
                        icon: "number",
                        title: "Servers",
                        color: themeManager.accentColor.color
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundSecondary(colorScheme))
        .navigationTitle("Home")
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .dms:
            MessagesView()
                .background(themeManager.backgroundPrimary(colorScheme))
        case .favorites:
            StarredChannelsView()
                .background(themeManager.backgroundPrimary(colorScheme))
        case .guilds, .none:
            HomeView()
        }
    }

    private func sidebarRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeShellView()
        .environment(ThemeManager())
        .environment(AppState())
}
