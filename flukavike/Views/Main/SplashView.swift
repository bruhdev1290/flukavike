//
//  SplashView.swift
//  Startup / loading placeholder
//

import SwiftUI

struct SplashView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            themeManager.backgroundPrimary(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    HexagonShape()
                        .fill(themeManager.accentColor.color.opacity(0.3))
                        .frame(width: 80, height: 80)
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(themeManager.accentColor.color)
                }

                ProgressView()
                    .tint(themeManager.accentColor.color)
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(ThemeManager())
}
