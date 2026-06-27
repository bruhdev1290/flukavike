//
//  LoginFormView.swift
//  flukavike
//
//  Email/password login form with passkey, SSO, and instance selector
//

import SwiftUI

struct LoginFormView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    @State private var showInstanceSheet: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 28) {
                header

                if let error = vm.errorMessage {
                    errorBanner(error)
                }

                VStack(spacing: 20) {
                    inputField(
                        title: "Email",
                        text: $vm.email,
                        prompt: "name@example.com",
                        keyboard: .emailAddress,
                        contentType: .emailAddress,
                        submit: { focusedField = .password }
                    )
                    .focused($focusedField, equals: .email)

                    passwordField(vm: vm)
                }

                if vm.showCaptchaChallenge && !vm.captchaSiteKey.isEmpty {
                    HCaptchaWidgetCard(
                        siteKey: vm.captchaSiteKey,
                        provider: vm.captchaProvider,
                        token: vm.captchaToken,
                        onToken: { vm.applyCaptchaToken($0) },
                        onReset: { vm.resetCaptcha() }
                    )
                }

                Button(action: { vm.login() }) {
                    HStack {
                        if vm.isLoggingIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Log In")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(vm.canSubmit ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                    )
                }
                .disabled(!vm.canSubmit)

                Button("Forgot your password?") {
                    vm.showForgotPasswordScreen()
                }
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textTertiary(colorScheme))

                orDivider

                Button(action: { vm.loginWithPasskey() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 18))
                        Text("Log in with Passkey")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.backgroundSecondary(colorScheme))
                    )
                }
                .disabled(vm.isLoggingIn || vm.isStartingSso)

                Button(action: { vm.startSsoLogin() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                        Text("Log in with SSO")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.backgroundSecondary(colorScheme))
                    )
                }
                .disabled(vm.isLoggingIn || vm.isStartingSso)

                HStack(spacing: 4) {
                    Text("Need an account?")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                    Button("Register") {
                        vm.showRegisterScreen()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor.color)
                }

                instanceSelector(vm: vm)

                Spacer(minLength: 40)

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 34)
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                HexagonShape()
                    .fill(themeManager.accentColor.color.opacity(0.3))
                    .frame(width: 70, height: 70)
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(themeManager.accentColor.color)
            }

            Text("Welcome back")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            Text("Sign in to continue to Flukavike")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textSecondary(colorScheme))
        }
    }

    private func passwordField(vm: LoginViewModel) -> some View {
        @Bindable var vm = vm

        return VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.textSecondary(colorScheme))

            HStack(spacing: 12) {
                Group {
                    if vm.isPasswordVisible {
                        TextField("Password", text: $vm.password)
                    } else {
                        SecureField("Password", text: $vm.password)
                    }
                }
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { vm.login() }
                .focused($focusedField, equals: .password)

                Button(action: { vm.togglePasswordVisibility() }) {
                    Image(systemName: vm.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.backgroundTertiary(colorScheme))
            )
        }
    }

    private func instanceSelector(vm: LoginViewModel) -> some View {
        @Bindable var vm = vm

        return Button(action: { showInstanceSheet = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Instance")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    Text(vm.instance.isEmpty ? "fluxer.app" : vm.instance)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.backgroundSecondary(colorScheme))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showInstanceSheet) {
            InstanceSelectorSheet(instance: $vm.instance)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Divider()
                .background(themeManager.separator(colorScheme))
            Text("or")
                .font(.system(size: 13))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            Divider()
                .background(themeManager.separator(colorScheme))
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Powered by Fluxer")
                .font(.system(size: 13))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            HStack(spacing: 16) {
                Link("Privacy", destination: URL(string: "https://fluxer.app/privacy")!)
                Text("·")
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                Link("Terms", destination: URL(string: "https://fluxer.app/terms")!)
            }
            .font(.system(size: 13))
            .foregroundStyle(themeManager.accentColor.color)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
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

    private func inputField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType,
        submit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.textSecondary(colorScheme))

            TextField(prompt, text: text)
                .font(.system(size: 17))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )
                .keyboardType(keyboard)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .onSubmit(submit)
        }
    }
}
