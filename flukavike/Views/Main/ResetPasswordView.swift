//
//  ResetPasswordView.swift
//  Reset password from email token
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    let token: String

    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.rotation")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.accentColor.color)

            Text("Choose a new password")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            VStack(spacing: 16) {
                SecureField("New password", text: $password)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.backgroundTertiary(colorScheme))
                    )

                SecureField("Confirm password", text: $confirmPassword)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.backgroundTertiary(colorScheme))
                    )
            }
            .padding(.horizontal, 20)

            if password != confirmPassword && !confirmPassword.isEmpty {
                Text("Passwords do not match.")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: {
                viewModel.submitResetPassword(token: token, password: password)
            }) {
                HStack {
                    if vm.isLoggingIn {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Reset password")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canSubmit ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                )
            }
            .disabled(!canSubmit)
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        !password.isEmpty
            && password == confirmPassword
            && !viewModel.isLoggingIn
    }
}
