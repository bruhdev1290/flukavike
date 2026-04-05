//
//  ComposeView.swift
//  Message composer
//

import SwiftUI

struct ComposeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText: String = ""
    @State private var selectedServer: Server?
    @State private var selectedChannel: Channel?
    @State private var showChannelPicker: Bool = false
    @State private var attachments: [String] = []
    @State private var contentWarning: String = ""
    @State private var showContentWarning: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Server/Channel Selector
                destinationSelector
                
                Divider()
                    .background(themeManager.separator(colorScheme))
                
                // Text Editor
                ScrollView {
                    TextEditor(text: $messageText)
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .frame(minHeight: 200)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                }
                .background(themeManager.backgroundPrimary(colorScheme))
                
                // Content Warning (if enabled)
                if showContentWarning {
                    contentWarningField
                }
                
                // Attachments Preview
                if !attachments.isEmpty {
                    attachmentsPreview
                }
                
                Divider()
                    .background(themeManager.separator(colorScheme))
                
                // Toolbar
                composeToolbar
            }
            .background(themeManager.backgroundSecondary(colorScheme))
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        sendMessage()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSend ? themeManager.accentColor.color : themeManager.textTertiary(colorScheme))
                    .disabled(!canSend)
                }
            }
            .sheet(isPresented: $showChannelPicker) {
                ChannelPickerView(selectedServer: $selectedServer, selectedChannel: $selectedChannel)
            }
        }
    }
    
    // MARK: - Destination Selector
    private var destinationSelector: some View {
        Button(action: { showChannelPicker = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.accentColor.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "number")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.accentColor.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let server = selectedServer, let channel = selectedChannel {
                        Text(server.name)
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                        Text("#\(channel.name)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    } else {
                        Text("Select Channel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.backgroundPrimary(colorScheme))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Content Warning Field
    private var contentWarningField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                
                Text("Content Warning")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                
                Spacer()
                
                Button(action: { showContentWarning = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                }
            }
            
            TextField("Describe the content", text: $contentWarning)
                .font(.system(size: 16))
                .foregroundStyle(themeManager.textPrimary(colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )
        }
        .padding(12)
        .background(themeManager.backgroundSecondary(colorScheme))
    }
    
    // MARK: - Attachments Preview
    private var attachmentsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(attachments, id: \.self) { attachment in
                    AttachmentPreview(filename: attachment) {
                        attachments.removeAll { $0 == attachment }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(themeManager.backgroundSecondary(colorScheme))
    }
    
    // MARK: - Compose Toolbar
    private var composeToolbar: some View {
        HStack(spacing: 20) {
            ToolbarButton(icon: "photo", action: {})
            ToolbarButton(icon: "camera", action: {})
            ToolbarButton(icon: "doc", action: {})
            ToolbarButton(icon: "number", action: {})
            ToolbarButton(icon: "exclamationmark.triangle", isActive: showContentWarning) {
                showContentWarning.toggle()
            }
            
            Spacer()
            
            // Character Count
            Text("\(messageText.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(messageText.count > 2000 ? .red : themeManager.textTertiary(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.backgroundSecondary(colorScheme))
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedChannel != nil
    }
    
    private func sendMessage() {
        // Handle send
        dismiss()
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(isActive ? themeManager.accentColor.color : themeManager.textSecondary(colorScheme))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? themeManager.accentColor.color.opacity(0.15) : Color.clear)
                )
        }
    }
}

// MARK: - Attachment Preview
struct AttachmentPreview: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let filename: String
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.backgroundTertiary(colorScheme))
                .frame(width: 80, height: 80)
                .overlay(
                    VStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(themeManager.accentColor.color)
                        
                        Text(filename)
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 4)
                    }
                )
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
                    .background(
                        Circle()
                            .fill(themeManager.backgroundPrimary(colorScheme))
                    )
            }
            .offset(x: 8, y: -8)
        }
    }
}

// MARK: - Channel Picker View
struct ChannelPickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedServer: Server?
    @Binding var selectedChannel: Channel?

    @State private var searchText: String = ""

    private var filteredServers: [Server] {
        let servers = appState.gatewayGuilds
        guard !searchText.isEmpty else { return servers }
        let q = searchText.lowercased()
        return servers.compactMap { server in
            let matchingChannels = server.channels.filter {
                ($0.type == .text || $0.type == .announcement) &&
                $0.name.lowercased().contains(q)
            }
            if server.name.lowercased().contains(q) || !matchingChannels.isEmpty {
                return server
            }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredServers) { server in
                    Section(header: Text(server.name).font(.system(size: 11, weight: .semibold))) {
                        let channels = searchText.isEmpty
                            ? server.channels.filter { $0.type == .text || $0.type == .announcement }
                            : server.channels.filter { ($0.type == .text || $0.type == .announcement) && $0.name.lowercased().contains(searchText.lowercased()) }
                        ForEach(channels) { channel in
                            Button(action: {
                                selectedServer = server
                                selectedChannel = channel
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: channel.type == .announcement ? "megaphone" : "number")
                                        .font(.system(size: 16))
                                        .foregroundStyle(themeManager.textSecondary(colorScheme))
                                        .frame(width: 24)
                                    
                                    Text(channel.name)
                                        .font(.system(size: 17))
                                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                                    
                                    Spacer()
                                    
                                    if selectedServer?.id == server.id && selectedChannel?.id == channel.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(themeManager.accentColor.color)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}

// MARK: - Preview
#Preview {
    ComposeView()
        .environment(ThemeManager())
        .environment(AppState())
}
