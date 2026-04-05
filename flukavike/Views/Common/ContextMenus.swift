//
//  ContextMenus.swift
//  Context menus for channels and servers
//

import SwiftUI

// MARK: - Channel Context Menu
struct ChannelContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let channel: Channel
    let server: Server?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Channel Header
                HStack(spacing: 12) {
                    Image(systemName: channelIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.accentColor.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(channel.name)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        if let server = server {
                            Text(server.name)
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Mark as Read
                        MenuButton(icon: "eye", title: "Mark as Read", color: themeManager.textPrimary(colorScheme)) {
                            dismiss()
                        }
                        
                        // Section: Notifications
                        VStack(spacing: 0) {
                            MenuButton(icon: "bell", title: "Notification Settings", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Channel Options
                        VStack(spacing: 0) {
                            if channel.type != .voice {
                                MenuButton(icon: "pin", title: "Pin Channel", color: themeManager.textPrimary(colorScheme)) {
                                    dismiss()
                                }
                                
                                Divider()
                                    .background(themeManager.separator(colorScheme))
                                    .padding(.leading, 56)
                            }
                            
                            MenuButton(icon: "bell.slash", title: "Mute Channel", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            if channel.type != .voice {
                                Divider()
                                    .background(themeManager.separator(colorScheme))
                                    .padding(.leading, 56)
                                
                                MenuButton(icon: "person.badge.plus", title: "Invite Friends", color: themeManager.textPrimary(colorScheme)) {
                                    dismiss()
                                }
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Danger Zone
                        VStack(spacing: 0) {
                            MenuButton(icon: "xmark.circle", title: "Leave Channel", color: .red) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "flag", title: "Report Channel", color: .red) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .text:
            return "number"
        case .voice:
            return "speaker.wave.2"
        case .category:
            return "folder"
        case .announcement:
            return "megaphone"
        }
    }
}

// MARK: - Server Context Menu
struct ServerContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let server: Server
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Server Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeManager.accentColor.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(String(server.name.prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("\(server.memberCount) Members")
                                .font(.system(size: 13))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Section: Quick Actions
                        VStack(spacing: 0) {
                            MenuButton(icon: "eye", title: "Mark as Read", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Settings
                        VStack(spacing: 0) {
                            MenuButton(icon: "bell", title: "Notification Settings", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "shield", title: "Privacy Settings", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "person.circle", title: "Edit Community Profile", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Mute/Hide
                        VStack(spacing: 0) {
                            MenuButtonWithChevron(icon: "bell.slash", title: "Mute Community") {
                                dismiss()
                            }
                            
                            HStack {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 20))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                    .frame(width: 24)
                                
                                Text("Hide Muted Channels")
                                    .font(.system(size: 16))
                                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                                
                                Spacer()
                                
                                Toggle("", isOn: .constant(false))
                                    .toggleStyle(SwitchToggleStyle(tint: themeManager.accentColor.color))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Danger Zone
                        VStack(spacing: 0) {
                            MenuButton(icon: "arrow.left.square", title: "Leave Community", color: .red) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "flag", title: "Report Community", color: .red) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Debug option (for development)
                        VStack(spacing: 0) {
                            MenuButton(icon: "ant", title: "Debug Community", color: themeManager.textSecondary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
}

// MARK: - DM Context Menu
struct DMContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    let user: User
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // User Header
                HStack(spacing: 12) {
                    AvatarView(user: user, size: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.formattedName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                        
                        if let status = user.customStatus {
                            Text(status)
                                .font(.system(size: 15))
                                .foregroundStyle(themeManager.textSecondary(colorScheme))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Section: Pin
                        VStack(spacing: 0) {
                            MenuButton(icon: "pin.fill", title: "Pin DM", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Actions
                        VStack(spacing: 0) {
                            MenuButton(icon: "person", title: "View Profile", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "phone", title: "Start Voice Call", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "note.text", title: "Add Note", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "xmark.circle", title: "Close DM", color: .red) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Invite
                        VStack(spacing: 0) {
                            MenuButtonWithChevron(icon: "person.badge.plus", title: "Invite to Community") {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "person.plus", title: "Add Friend", color: themeManager.textPrimary(colorScheme)) {
                                dismiss()
                            }
                            
                            Divider()
                                .background(themeManager.separator(colorScheme))
                                .padding(.leading, 56)
                            
                            MenuButton(icon: "nosign", title: "Block", color: .red) {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Section: Mute
                        VStack(spacing: 0) {
                            MenuButtonWithChevron(icon: "bell.slash", title: "Mute DM") {
                                dismiss()
                            }
                        }
                        .background(themeManager.backgroundSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundPrimary(colorScheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
        }
    }
}

// MARK: - Menu Button Components
struct MenuButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MenuButtonWithChevron: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Context Menus Preview")
    }
    .sheet(isPresented: .constant(true)) {
        ChannelContextMenu(channel: Channel.previewChannels[0], server: Server.preview)
            .environment(ThemeManager())
    }
}
