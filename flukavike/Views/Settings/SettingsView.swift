//
//  SettingsView.swift
//  Settings with extensive customization
//

import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    
    private func signOut() {
        Task {
            await AuthService.shared.logout()
            WebSocketService.shared.disconnect()
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    SettingsRow(
                        icon: "person.fill",
                        iconColor: themeManager.accentColor.color,
                        title: "Account",
                        subtitle: "@alice@fluxer.app"
                    ) {}
                    
                    SettingsRow(
                        icon: "lock.fill",
                        iconColor: .green,
                        title: "Privacy & Security",
                        subtitle: "2FA, Sessions, Privacy"
                    ) {}
                }
                
                // Appearance Section
                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "paintbrush.fill",
                            iconColor: .purple,
                            title: "Theme & Colors",
                            subtitle: "\(themeManager.currentTheme.rawValue) · \(themeManager.accentColor.rawValue)",
                            showArrow: false
                        ) {}
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                    
                    SettingsRow(
                        icon: "textformat.size",
                        iconColor: .blue,
                        title: "Text Size",
                        subtitle: "Default"
                    ) {}
                    
                    SettingsRow(
                        icon: "sparkles",
                        iconColor: .orange,
                        title: "Custom CSS",
                        subtitle: "Personalize your experience"
                    ) {}
                }
                
                // Notifications Section
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .red,
                            title: "Push Notifications",
                            subtitle: "3 apps configured",
                            showArrow: false
                        ) {}
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                    
                    ToggleRow(
                        icon: "speaker.wave.2.fill",
                        iconColor: .pink,
                        title: "Sounds",
                        subtitle: "Play sounds for notifications",
                        isOn: .constant(true)
                    )
                    
                    ToggleRow(
                        icon: "hand.tap.fill",
                        iconColor: .cyan,
                        title: "Haptic Feedback",
                        subtitle: "Vibrate on interactions",
                        isOn: .constant(true)
                    )
                    
                    ToggleRow(
                        icon: "phone.fill",
                        iconColor: .green,
                        title: "Incoming Calls",
                        subtitle: "Show call notifications",
                        isOn: .constant(true)
                    )
                }
                
                // Messaging Section
                Section("Messaging") {
                    SettingsRow(
                        icon: "photo.stack.fill",
                        iconColor: .indigo,
                        title: "Media",
                        subtitle: "Auto-download, quality"
                    ) {}
                    
                    ToggleRow(
                        icon: "eye.fill",
                        iconColor: .teal,
                        title: "Read Receipts",
                        subtitle: "Let others see when you've read messages",
                        isOn: .constant(true)
                    )
                    
                    ToggleRow(
                        icon: "text.quote",
                        iconColor: .brown,
                        title: "Markdown Formatting",
                        subtitle: "Enable rich text formatting",
                        isOn: .constant(true)
                    )
                }
                
                // Instances Section
                Section("Instances") {
                    NavigationLink {
                        InstanceSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "server.rack",
                            iconColor: .gray,
                            title: "Manage Instances",
                            subtitle: "3 connected servers",
                            showArrow: false
                        ) {}
                    }
                    .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                    
                    SettingsRow(
                        icon: "plus.circle.fill",
                        iconColor: themeManager.accentColor.color,
                        title: "Add Instance",
                        subtitle: nil
                    ) {}
                }
                
                // Advanced Section
                Section("Advanced") {
                    ToggleRow(
                        icon: "bolt.fill",
                        iconColor: .yellow,
                        title: "Reduced Motion",
                        subtitle: "Minimize animations",
                        isOn: .constant(false)
                    )
                    
                    SettingsRow(
                        icon: "wand.and.stars",
                        iconColor: .mint,
                        title: "Developer Options",
                        subtitle: "Debug tools, logs"
                    ) {}
                }
                
                // About Section
                Section("About") {
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        iconColor: .blue,
                        title: "Help & Support",
                        subtitle: nil
                    ) {}
                    
                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: .gray,
                        title: "Terms of Service",
                        subtitle: nil
                    ) {}
                    
                    SettingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .gray,
                        title: "Privacy Policy",
                        subtitle: nil
                    ) {}
                    
                    HStack {
                        Text("Version")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        Spacer()
                        
                        Text("1.0.0 (Build 42)")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    .padding(.vertical, 4)
                }
                
                // Sign Out Section
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
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .searchable(text: $searchText)
        }
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        List {
            // Theme Selection
            Section("Theme") {
                ForEach(ThemeManager.AppTheme.allCases) { theme in
                    Button(action: { themeManager.currentTheme = theme }) {
                        HStack {
                            Text(theme.rawValue)
                                .font(.system(size: 17))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(themeManager.accentColor.color)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Accent Color Selection
            Section("Accent Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                    ForEach(ThemeManager.AccentColor.allCases) { color in
                        Button(action: { themeManager.accentColor = color }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(themeManager.textPrimary(colorScheme), lineWidth: themeManager.accentColor == color ? 3 : 0)
                                    )
                                
                                Text(color.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Preview
            Section("Preview") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Sample Text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
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
                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notification Settings
struct NotificationSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        List {
            Section {
                ToggleRow(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: "Enable Push Notifications",
                    subtitle: nil,
                    isOn: .constant(true)
                )
            }
            
            Section("Notification Types") {
                ToggleRow(
                    icon: "at",
                    iconColor: .blue,
                    title: "Mentions",
                    subtitle: "When someone mentions you",
                    isOn: .constant(true)
                )
                
                ToggleRow(
                    icon: "bubble.left.fill",
                    iconColor: .green,
                    title: "Direct Messages",
                    subtitle: "New private messages",
                    isOn: .constant(true)
                )
                
                ToggleRow(
                    icon: "face.smiling.fill",
                    iconColor: .yellow,
                    title: "Reactions",
                    subtitle: "When someone reacts to your posts",
                    isOn: .constant(true)
                )
                
                ToggleRow(
                    icon: "person.badge.plus.fill",
                    iconColor: .purple,
                    title: "Follows",
                    subtitle: "New followers",
                    isOn: .constant(false)
                )
            }
            
            Section("Quiet Hours") {
                ToggleRow(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    title: "Enable Quiet Hours",
                    subtitle: "Pause notifications during set times",
                    isOn: .constant(false)
                )
                
                DatePicker("From", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                DatePicker("To", selection: .constant(Date()), displayedComponents: .hourAndMinute)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Instance Settings
struct InstanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var instances: [Server] = Server.previewServers
    
    var body: some View {
        List {
            Section {
                ForEach(instances) { instance in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.accentColor.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Text(String(instance.name.prefix(1)))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(themeManager.accentColor.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instance.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(themeManager.textPrimary(colorScheme))
                            
                            Text(instance.instance)
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                        
                        Spacer()
                        
                        // Connection Status
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteInstance)
            }
            
            Section {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.accentColor.color)
                        
                        Text("Add Instance")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("Instances")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteInstance(at offsets: IndexSet) {
        instances.remove(atOffsets: offsets)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environment(ThemeManager())
}
