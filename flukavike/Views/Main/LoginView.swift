//
//  LoginView.swift
//  Unified login flow container
//

import SwiftUI

struct LoginView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let resetToken = viewModel.resetToken {
                    ResetPasswordView(token: resetToken)
                        .environment(viewModel)
                } else if viewModel.showForgotPassword {
                    ForgotPasswordView()
                        .environment(viewModel)
                } else if viewModel.showRegister {
                    RegisterView()
                        .environment(viewModel)
                } else if let _ = viewModel.banViewInfo {
                    SuspendedAccountView()
                        .environment(viewModel)
                } else if let _ = viewModel.mfaChallenge {
                    MfaView()
                        .environment(viewModel)
                } else if let _ = viewModel.ipAuthChallenge {
                    IpAuthorizationView()
                        .environment(viewModel)
                } else {
                    LoginFormView()
                        .environment(viewModel)
                }
            }
            .background(themeManager.backgroundPrimary(colorScheme))
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ResetPasswordIntent"))) { note in
            guard let token = note.userInfo?["token"] as? String else { return }
            viewModel.setResetToken(token)
        }
    }
}

#Preview {
    LoginView()
        .environment(ThemeManager())
        .environment(AppState())
}
