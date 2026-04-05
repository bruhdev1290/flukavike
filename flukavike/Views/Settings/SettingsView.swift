//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func signOut() {
        Task {
            await WebAuthService.shared.logout()
            WebSocketService.shared.disconnect()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Profile
                if let user = WebAuthService.shared.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor.color.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                Text(String(user.username.prefix(1).uppercased()))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(themeManager.accentColor.color)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.displayName ?? user.username)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                Text("@\(user.username)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                            }
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                    }
                }

                // MARK: Appearance
                Section("Appearance") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        SettingsNavRow(
                            icon: "paintbrush.fill",
                            iconColor: .purple,
                            title: "Theme & Colors",
                            subtitle: "\(themeManager.currentTheme.rawValue) · \(themeManager.accentColor.rawValue)"
                        )
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }

                // MARK: Notifications
                Section("Notifications") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        SettingsNavRow(
                            icon: "bell.fill",
                            iconColor: .red,
                            title: "Notification Settings",
                            subtitle: "Manage in iOS Settings",
                            showChevron: false
                        )
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }

                // MARK: Support
                Section("Support") {
                    NavigationLink(destination: ContactSupportView()) {
                        SettingsNavRow(
                            icon: "envelope.fill",
                            iconColor: .blue,
                            title: "Contact Support",
                            subtitle: "Report issues or send feedback"
                        )
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }

                // MARK: Source Code
                Section("Development") {
                    Button {
                        if let url = URL(string: "https://github.com/bruhdev1290/flukavike") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        SettingsNavRow(
                            icon: "curlybraces",
                            iconColor: .gray,
                            title: "Source Code",
                            subtitle: "View on GitHub"
                        )
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        Spacer()
                        Text(appVersion)
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }

                // MARK: Sign Out
                Section {
                    Button(action: signOut) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundSecondary(colorScheme))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
}

// MARK: - Settings Nav Row (plain view, safe inside NavigationLink)
private struct SettingsNavRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
        }
        .padding(.vertical, subtitle != nil ? 6 : 0)
        .contentShape(Rectangle())
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var systemColorScheme

    private var cs: ColorScheme {
        switch themeManager.currentTheme {
        case .dark, .oled: return .dark
        case .light: return .light
        case .system: return systemColorScheme
        }
    }

    var body: some View {
        List {
            Section("Theme") {
                ForEach(ThemeManager.AppTheme.allCases) { theme in
                    Button(action: {
                        themeManager.currentTheme = theme
                    }) {
                        HStack {
                            Text(theme.rawValue)
                                .font(.system(size: 17))
                                .foregroundStyle(themeManager.textPrimary(cs))
                            Spacer()
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(themeManager.accentColor.color)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(themeManager.backgroundPrimary(cs))
                }
            }

            Section("Accent Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                    ForEach(ThemeManager.AccentColor.allCases) { color in
                        Button(action: { themeManager.accentColor = color }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle().stroke(themeManager.textPrimary(cs),
                                                        lineWidth: themeManager.accentColor == color ? 3 : 0)
                                    )
                                Text(color.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(themeManager.textSecondary(cs))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(themeManager.backgroundPrimary(cs))
            }

            Section("Preview") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Sample Text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(cs))
                        Spacer()
                        Capsule()
                            .fill(themeManager.accentColor.color)
                            .frame(width: 60, height: 30)
                            .overlay(
                                Text("Button")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            )
                    }
                    Text("This is how your interface will look with the selected theme and accent color.")
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textSecondary(cs))
                }
                .padding(.vertical, 8)
                .listRowBackground(themeManager.backgroundPrimary(cs))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundSecondary(cs))
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact Support
struct ContactSupportView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    enum SupportCategory: String, CaseIterable, Identifiable {
        case error = "Error Report"
        case featureRequest = "Feature Request"
        case securityPrivacy = "Security or Privacy Inquiry"
        var id: String { rawValue }
    }

    @State private var category: SupportCategory = .error
    @State private var description: String = ""
    @State private var includeLogs: Bool = false
    @State private var didSend: Bool = false

    private var deviceInfo: String {
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return """
        App Version: \(version) (\(build))
        iOS: \(device.systemVersion)
        Device: \(device.model)
        """
    }

    private func sendEmail() {
        let subject = "[\(category.rawValue)] Flukavike Support"
        var body = ""
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body += description + "\n\n"
        }
        if includeLogs {
            body += "--- Device Info ---\n" + deviceInfo + "\n"
        }

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:correspondencesandrew@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
            didSend = true
        }
    }

    var body: some View {
        List {
            // Category picker
            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(SupportCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
            }

            // Description
            Section {
                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Describe your issue or request...")
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $description)
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                }
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
            } header: {
                Text("Description")
            } footer: {
                Text("Optional — the more detail you provide, the faster we can help.")
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }

            // Include logs toggle
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Include Device Info")
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        Text("App version, iOS version, device model")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                    Spacer()
                    Toggle("", isOn: $includeLogs)
                        .labelsHidden()
                        .tint(themeManager.accentColor.color)
                }
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))

                if includeLogs {
                    Text(deviceInfo)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                        .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                }
            } header: {
                Text("Logs")
            }

            // Send button
            Section {
                Button(action: sendEmail) {
                    HStack {
                        Spacer()
                        Label("Open Email App", systemImage: "envelope.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(themeManager.accentColor.color)
            } footer: {
                if didSend {
                    Text("Your email app should have opened. Send the draft to submit your request.")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundSecondary(colorScheme))
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environment(ThemeManager())
        .environment(AppState())
}
