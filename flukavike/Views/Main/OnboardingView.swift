//
//  OnboardingView.swift
//  Welcome carousel shown on first launch
//

import SwiftUI

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentPage: Int = 0
    @State private var showLogin: Bool = false

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "hexagon.fill",
            title: "Welcome to Flukavike",
            description: "A modern, open-source platform for communities. Self-hostable, customizable, and built for the future."
        ),
        OnboardingPage(
            icon: "person.3.fill",
            title: "Your Communities",
            description: "Join multiple servers, each with their own channels, roles, and personality. All in one seamless app."
        ),
        OnboardingPage(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Rich Messaging",
            description: "Markdown support, reactions, threads, and file sharing. Express yourself with voice and video too."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Privacy First",
            description: "Self-hosting options, transparent data practices, and tools that keep your community in control. You own your data."
        )
    ]

    var body: some View {
        ZStack {
            themeManager.backgroundPrimary(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { showLogin = true }) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? themeManager.accentColor.color : themeManager.separator(colorScheme))
                            .frame(width: currentPage == index ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button(action: { currentPage += 1 }) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.accentColor.color)
                                )
                        }
                    } else {
                        Button(action: { showLogin = true }) {
                            Text("Get Started")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(themeManager.accentColor.color)
                                )
                        }
                    }

                    if currentPage == pages.count - 1 {
                        Button(action: { showLogin = true }) {
                            Text("I already have an account")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(themeManager.accentColor.color)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

private struct OnboardingPageView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(themeManager.accentColor.color.opacity(0.1))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(themeManager.accentColor.color.opacity(0.2))
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundStyle(themeManager.accentColor.color)
                    .symbolRenderingMode(.multicolor)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(ThemeManager())
        .environment(AppState())
}
