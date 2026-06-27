//
//  MfaView.swift
//  Multi-factor authentication method selection and code entry
//

import SwiftUI

struct MfaView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    @State private var selectedMethod: MfaMethod?
    @State private var code: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 28) {
                header

                if let error = vm.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.12))
                    )
                }

                if let method = selectedMethod {
                    codeEntry(method: method)
                } else {
                    methodSelector
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 34)
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Two-Factor Auth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    if selectedMethod != nil {
                        selectedMethod = nil
                        code = ""
                    } else {
                        vm.clearMfaChallenge()
                    }
                }
                .foregroundStyle(themeManager.textPrimary(colorScheme))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.accentColor.color)

            Text("Two-factor authentication")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            Text("Choose how you want to verify your identity.")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)
        }
    }

    private var methodSelector: some View {
        VStack(spacing: 12) {
            if let challenge = viewModel.mfaChallenge {
                if challenge.totp {
                    methodButton(
                        icon: "shield.checkerboard",
                        title: "Authenticator app",
                        method: .totp
                    )
                }
                if challenge.sms {
                    methodButton(
                        icon: "message.fill",
                        title: "SMS code",
                        method: .sms
                    )
                }
                if challenge.webauthn {
                    methodButton(
                        icon: "key.fill",
                        title: "Security key",
                        method: .webauthn
                    )
                }
            }
        }
    }

    private func methodButton(icon: String, title: String, method: MfaMethod) -> some View {
        Button(action: {
            if method == .webauthn {
                Task { await viewModel.startMfaWebauthn() }
            } else {
                selectedMethod = method
                if method == .sms {
                    viewModel.sendMfaSms()
                }
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(themeManager.accentColor.color)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.backgroundSecondary(colorScheme))
            )
        }
        .buttonStyle(.plain)
    }

    private func codeEntry(method: MfaMethod) -> some View {
        VStack(spacing: 20) {
            Text(methodDescription(method))
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
                .multilineTextAlignment(.center)

            TextField("000000", text: $code)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )

            Button(action: {
                isLoading = true
                viewModel.verifyMfa(code: code, method: method)
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify")
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

            if method == .sms {
                Button("Resend SMS") {
                    viewModel.sendMfaSms()
                }
                .font(.system(size: 15))
                .foregroundStyle(themeManager.accentColor.color)
            }
        }
        .onChange(of: viewModel.isLoggingIn) { _, loading in
            if !loading { isLoading = false }
        }
    }

    private var canSubmit: Bool {
        code.count >= 4 && !viewModel.isLoggingIn
    }

    private func methodDescription(_ method: MfaMethod) -> String {
        switch method {
        case .totp:
            return "Enter the 6-digit code from your authenticator app."
        case .sms:
            return "Enter the code sent to your phone."
        case .webauthn:
            return "Use your security key to continue."
        }
    }
}
