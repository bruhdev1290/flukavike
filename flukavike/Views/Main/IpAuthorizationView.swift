//
//  IpAuthorizationView.swift
//  Email-approval login polling screen
//

import SwiftUI

struct IpAuthorizationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LoginViewModel.self) private var viewModel

    @State private var status: String = "Waiting for approval..."
    @State private var isPolling: Bool = false
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "envelope.badge.shield.half.filled.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.accentColor.color)

            Text("Approve this login")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(themeManager.textPrimary(colorScheme))

            if let challenge = viewModel.ipAuthChallenge {
                Text("We sent an email to \(challenge.email). Open it and approve this login request to continue.")
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text(status)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(themeManager.accentColor.color)
                .padding(.top, 8)

            if isPolling {
                ProgressView()
                    .tint(themeManager.accentColor.color)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Resend email") {
                    viewModel.resendIpAuthorization()
                    status = "Email resent."
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(themeManager.accentColor.color)

                Button("Use a different method") {
                    stopPolling()
                    viewModel.clearIpAuthChallenge()
                }
                .font(.system(size: 15))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 20)
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Approve Login")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func startPolling() {
        isPolling = true
        pollTask = Task {
            while !Task.isCancelled {
                let result = await viewModel.pollIpAuthorization()
                await MainActor.run {
                    switch result {
                    case .pending:
                        status = "Waiting for approval..."
                    case .expired:
                        status = "Login request expired. Please try again."
                        isPolling = false
                    case .completed:
                        status = "Approved!"
                        isPolling = false
                    }
                }
                if case .expired = result { break }
                if case .completed = result { break }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }
}
