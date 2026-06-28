//
//  PinSetupView.swift
//  PIN enrollment / change flow for the app lock.
//

import SwiftUI

struct PinSetupView: View {
    @Environment(BiometricLockService.self) private var lock
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case enroll
        case change
    }

    let mode: Mode
    var onComplete: (() -> Void)? = nil

    @State private var stage: Stage = .enter
    @State private var firstPin: String = ""
    @State private var confirmPin: String = ""
    @State private var input: String = ""
    @State private var error: String = ""
    @State private var shake: Bool = false
    /// True while the PIN verifier (PBKDF2) is computing; disables the keypad.
    @State private var isSaving: Bool = false

    private enum Stage { case enter, confirm, done }

    private var cs: ColorScheme {
        switch themeManager.currentTheme {
        case .dark, .oled, .ocean, .forest: return .dark
        case .light, .sandstone, .solarized: return .light
        case .system: return colorScheme
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundSecondary(cs).ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    Text(headerText)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(cs))

                    Text(subHeaderText)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(cs))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { idx in
                            Circle()
                                .fill(idx < input.count
                                      ? themeManager.accentColor.color
                                      : themeManager.separator(cs))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .offset(x: shake ? -12 : 0)
                    .animation(.easeInOut(duration: 0.05).repeatCount(3, autoreverses: true), value: shake)

                    if !error.isEmpty {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }

                    keypad

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(mode == .change ? "Change PIN" : "Set Up PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }

    private var headerText: String {
        switch stage {
        case .enter: return mode == .change ? "Enter a New PIN" : "Create a PIN"
        case .confirm: return "Confirm Your PIN"
        case .done: return "PIN Saved"
        }
    }

    private var subHeaderText: String {
        switch stage {
        case .enter: return "This PIN protects your app data if biometrics are unavailable."
        case .confirm: return "Re-enter the same 4 digits to confirm."
        case .done: return "Your app lock is now enabled."
        }
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            ForEach([["1","2","3"],["4","5","6"],["7","8","9"],["delete","0","confirm"]], id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(cs))
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(themeManager.backgroundTertiary(cs)))
                        }
                        .accessibilityLabel(key)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func tap(_ key: String) {
        guard !isSaving else { return }
        switch key {
        case "delete":
            if !input.isEmpty { input.removeLast() }
        case "confirm":
            advance()
        default:
            guard input.count < 4 else { return }
            input.append(key)
            if input.count == 4 { advance() }
        }
    }

    private func advance() {
        error = ""
        // Enforce the required PIN length before progressing; `setPin` also
        // rejects short PINs, but guarding here gives immediate feedback and
        // prevents an empty/short firstPin from being captured.
        guard input.count == 4 else {
            error = "PIN must be 4 digits."
            shake.toggle()
            input = ""
            return
        }
        switch stage {
        case .enter:
            firstPin = input
            input = ""
            stage = .confirm
        case .confirm:
            confirmPin = input
            if firstPin == confirmPin {
                savePin(firstPin)
            } else {
                error = "PINs do not match. Start again."
                shake.toggle()
                firstPin = ""
                input = ""
                stage = .enter
            }
        case .done:
            dismiss()
        }
    }

    /// Saves the PIN by running the PBKDF2 derivation off the main thread so
    /// enrollment doesn't block the UI.
    private func savePin(_ pin: String) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            let ok = await lock.setPin(pin)
            await MainActor.run {
                isSaving = false
                if ok {
                    onComplete?()
                    dismiss()
                } else {
                    error = "PIN could not be saved. Try again."
                    shake.toggle()
                    firstPin = ""
                    input = ""
                    stage = .enter
                }
            }
        }
    }
}

#Preview {
    PinSetupView(mode: .enroll)
        .environment(BiometricLockService.shared)
        .environment(ThemeManager())
}
