//
//  SuspendedAccountView.swift
//  Displays account suspension / ban information
//

import SwiftUI

struct SuspendedAccountView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Account suspended")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            Text("This account has been suspended or banned. If you believe this is a mistake, please contact support.")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button("Back to login") {
                viewModel.clearBanView()
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(themeManager.accentColor.color)
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 20)
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Suspended")
        .navigationBarTitleDisplayMode(.inline)
    }
}
