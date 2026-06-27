//
//  RegisterView.swift
//  Account creation
//

import SwiftUI

struct RegisterView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var dateOfBirth: Date = Date()

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 24) {
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

                VStack(spacing: 16) {
                    inputField(title: "Display name", text: $displayName, prompt: "How you appear to others")
                        .onChange(of: displayName) { _, value in
                            viewModel.fetchUsernameSuggestions(displayName: value)
                        }

                    if !viewModel.usernameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.usernameSuggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        username = suggestion
                                    }
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(themeManager.backgroundTertiary(colorScheme))
                                    )
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                }
                            }
                        }
                    }

                    inputField(title: "Username", text: $username, prompt: "unique-username")
                    inputField(title: "Email", text: $email, prompt: "name@example.com", keyboard: .emailAddress, contentType: .emailAddress)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                        SecureField("Create a password", text: $password)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of birth")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                        DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .colorMultiply(themeManager.accentColor.color)
                    }
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

                Button(action: submit) {
                    HStack {
                        if vm.isLoggingIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canRegister ? themeManager.accentColor.color : themeManager.accentColor.color.opacity(0.5))
                    )
                }
                .disabled(!canRegister)

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                    Button("Sign in") {
                        vm.backFromRegister()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor.color)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 34)
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus.fill")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.accentColor.color)
            Text("Create your account")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
        }
    }

    private var canRegister: Bool {
        !username.isEmpty
            && !email.isEmpty
            && !password.isEmpty
            && !viewModel.isLoggingIn
            && (!viewModel.showCaptchaChallenge || viewModel.captchaToken != nil)
    }

    private func submit() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        viewModel.register(
            username: username,
            displayName: displayName,
            email: email,
            password: password,
            dateOfBirth: formatter.string(from: dateOfBirth)
        )
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
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
        }
    }
}
