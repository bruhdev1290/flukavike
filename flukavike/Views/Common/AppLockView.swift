//
//  AppLockView.swift
//  Full-screen lock overlay (biometric + PIN fallback).
//

import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Environment(BiometricLockService.self) private var lock
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var pinInput: String = ""
    @State private var showPinPad: Bool = false
    @State private var shake: Bool = false
    @State private var statusMessage: String = ""
    /// True while the PIN verifier (PBKDF2) is computing; disables the keypad.
    @State private var isVerifying: Bool = false

    private var cs: ColorScheme {
        switch themeManager.currentTheme {
        case .dark, .oled, .ocean, .forest: return .dark
        case .light, .sandstone, .solarized: return .light
        case .system: return colorScheme
        }
    }

    var body: some View {
        ZStack {
            themeManager.backgroundPrimary(cs)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: lockIcon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(themeManager.accentColor.color)
                    .accessibilityHidden(true)

                Text("Flukavike Locked")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(themeManager.textPrimary(cs))

                if lock.isInLockout {
                    Text("Too many attempts. Try again in \(lock.lockoutRemainingSeconds)s.")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(cs))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else if lock.canUseBiometrics && lock.isBiometricEnabled && !showPinPad {
                    Text(statusMessage.isEmpty ? "Use \(biometryLabel) to unlock." : statusMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(cs))
                } else {
                    Text(statusMessage.isEmpty ? "Enter your PIN to unlock." : statusMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(cs))
                }

                if lock.isInLockout {
                    // No input during lockout.
                    EmptyView()
                } else if showPinPad || !lock.canUseBiometrics || !lock.isBiometricEnabled {
                    pinPad
                } else {
                    Button(action: attemptBiometric) {
                        Label("Unlock with \(biometryLabel)", systemImage: lockIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.accentColor.color)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(themeManager.accentColor.color.opacity(0.15))
                            )
                    }
                    .accessibilityLabel("Unlock with \(biometryLabel)")

                    Button("Use PIN Instead") {
                        showPinPad = true
                        statusMessage = ""
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(themeManager.textSecondary(cs))
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            if lock.canUseBiometrics && lock.isBiometricEnabled && !lock.isInLockout {
                attemptBiometric()
            }
        }
    }

    // MARK: - PIN Pad

    private var pinPad: some View {
        VStack(spacing: 20) {
            // Dots
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { idx in
                    Circle()
                        .fill(idx < pinInput.count
                              ? themeManager.accentColor.color
                              : themeManager.separator(cs))
                        .frame(width: 14, height: 14)
                }
            }
            .offset(x: shake ? -12 : 0)
            .animation(.easeInOut(duration: 0.05).repeatCount(3, autoreverses: true), value: shake)

            // Keypad
            VStack(spacing: 12) {
                ForEach(keypadRows, id: \.self) { row in
                    HStack(spacing: 16) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                tapKey(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(themeManager.textPrimary(cs))
                                    .frame(width: 64, height: 64)
                                    .background(
                                        Circle()
                                            .fill(themeManager.backgroundTertiary(cs))
                                    )
                            }
                            .accessibilityLabel(key)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private var keypadRows: [[String]] {
        [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["delete", "0", "confirm"]]
    }

    private func tapKey(_ key: String) {
        guard !isVerifying else { return }
        switch key {
        case "delete":
            if !pinInput.isEmpty { pinInput.removeLast() }
        case "confirm":
            tryUnlock()
        default:
            guard pinInput.count < 4 else { return }
            pinInput.append(key)
            if pinInput.count == 4 {
                tryUnlock()
            }
        }
    }

    private func tryUnlock() {
        guard !isVerifying else { return }
        isVerifying = true
        let pin = pinInput
        Task {
            let ok = await lock.unlockWithPin(pin)
            await MainActor.run {
                isVerifying = false
                if ok {
                    pinInput = ""
                    statusMessage = ""
                } else {
                    shake.toggle()
                    pinInput = ""
                    statusMessage = lock.isInLockout
                        ? "Too many attempts. Locked for \(lock.lockoutRemainingSeconds)s."
                        : "Incorrect PIN. Try again."
                }
            }
        }
    }

    // MARK: - Biometric

    private func attemptBiometric() {
        Task {
            let ok = await lock.tryBiometric()
            if !ok {
                await MainActor.run {
                    if lock.isInLockout {
                        statusMessage = "Locked. Try again in \(lock.lockoutRemainingSeconds)s."
                    } else {
                        showPinPad = true
                        statusMessage = "Enter your PIN to unlock."
                    }
                }
            }
        }
    }

    private var biometryLabel: String {
        switch lock.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    private var lockIcon: String {
        switch lock.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }
}

#Preview {
    AppLockView()
        .environment(BiometricLockService.shared)
        .environment(ThemeManager())
}
