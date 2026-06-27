//
//  ForgotPasswordView.swift
//  Password reset request
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    @State private var email: String = ""

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.accentColor.color)

            Text("Reset your password")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            if vm.forgotPasswordEmailSent {
                Text("If an account exists for \(email), you'll receive a reset link shortly.")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text("Enter your email and we'll send you a link to reset your password.")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("name@example.com", text: $email)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.backgroundTertiary(colorScheme))
                    )
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 20)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: {
                    viewModel.submitForgotPassword(email: email)
                }) {
                    HStack {
                        if vm.isLoggingIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send reset link")
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
            }

            Spacer()

            Button("Back to login") {
                vm.backFromForgotPassword()
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(themeManager.accentColor.color)
            .padding(.bottom, 34)
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isLoggingIn
    }
}
