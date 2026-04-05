//
//  ChatView.swift
//  Discord-style chat interface
//

import SwiftUI
import Combine
import PhotosUI

struct ChatView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    let channel: Channel
    
    @State private var messages: [Message] = []
    @State private var messageText: String = ""
    @State private var isTyping: Bool = false
    @State private var isLoading: Bool = false
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var typingUsers: [String: Date] = [:]
    @State private var isRecordingVoice: Bool = false
    @State private var voiceRecording: VoiceMessageRecording?
    @FocusState private var isInputFocused: Bool

    // Image / attachment picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker: Bool = false

    // Lightbox
    @State private var lightboxURL: IdentifiableURL?

    // In-channel search
    @State private var showChannelSearch: Bool = false
    @State private var channelSearchQuery: String = ""
    
    // Reply to message
    @State private var replyingToMessage: Message? = nil
    
    // Edit message
    @State private var editingMessage: Message? = nil
    @State private var originalMessageContent: String = ""
    
    // Message context menu
    @State private var selectedMessageForMenu: Message? = nil

    // Starred state (backed by StarredChannelsManager)
    @State private var isPinned: Bool = false

    /// Server name resolved via REST servers (proper names) then gateway guilds as fallback.
    private var resolvedServerName: String {
        let name = appState.serverName(for: channel.serverId)
        return name.isEmpty ? channel.serverId : name
    }
    
    private let audioRecorder = AudioRecorderService.shared
    private let audioPlayer = AudioPlayerService.shared
    
    private let apiService = APIService.shared
    private let webSocketService = WebSocketService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading && messages.isEmpty {
                            ProgressView()
                                .padding(.vertical, 32)
                        }

                        if let errorMessage, messages.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 24)
                        }
                        
                        // Date Header
                        if !messages.isEmpty {
                            Text("Today")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                                .padding(.vertical, 16)
                        }
                        
                        let visibleMessages = channelSearchQuery.isEmpty ? messages :
                            messages.filter { $0.content.localizedCaseInsensitiveContains(channelSearchQuery) ||
                                $0.author.formattedName.localizedCaseInsensitiveContains(channelSearchQuery) }
                        ForEach(visibleMessages) { message in
                            DiscordMessageBubble(
                                message: message,
                                currentUserId: appState.currentUser?.id,
                                channelId: channel.id,
                                onImageTap: { url in
                                    lightboxURL = IdentifiableURL(url)
                                },
                                onReply: {
                                    replyingToMessage = message
                                    editingMessage = nil
                                    isInputFocused = true
                                    HapticFeedback.medium()
                                },
                                onEdit: {
                                    editingMessage = message
                                    originalMessageContent = message.content
                                    messageText = message.content
                                    replyingToMessage = nil
                                    isInputFocused = true
                                    HapticFeedback.medium()
                                },
                                onDelete: {
                                    deleteMessage(message)
                                },
                                onReactionToggle: { emoji in
                                    toggleReaction(on: message, emoji: emoji)
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Typing Indicator
                        if !activeTypingUsers.isEmpty {
                            DiscordTypingIndicator(users: activeTypingUsers)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        
                        // Bottom spacing
                        Color.clear
                            .frame(height: 8)
                            .id("bottom")
                    }
                    .padding(.horizontal, 12)
                }
                .onAppear {
                    loadMessages()
                    setupWebSocketHandlers()
                    scrollToBottom(proxy: proxy)
                }
                .onDisappear {
                    removeWebSocketHandlers()
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // In-channel search bar
            if showChannelSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    TextField("Search messages...", text: $channelSearchQuery)
                        .font(.system(size: 15))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    if !channelSearchQuery.isEmpty {
                        Button(action: { channelSearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                        }
                    }
                    Button(action: { showChannelSearch = false; channelSearchQuery = "" }) {
                        Text("Cancel").font(.system(size: 15))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeManager.backgroundSecondary(colorScheme))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Reply Preview
            if let replyingTo = replyingToMessage {
                ReplyPreviewView(
                    message: replyingTo,
                    onCancel: { replyingToMessage = nil }
                )
                .environment(themeManager)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Edit Preview
            if let editing = editingMessage {
                EditPreviewView(
                    message: editing,
                    onCancel: {
                        editingMessage = nil
                        messageText = ""
                    }
                )
                .environment(themeManager)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input Area
            DiscordInputView(
                text: $messageText,
                isTyping: $isTyping,
                isSending: $isSending,
                isRecording: $isRecordingVoice,
                replyingTo: $replyingToMessage,
                editingMessage: $editingMessage,
                onSend: sendMessage,
                onEdit: saveEditedMessage,
                onTyping: sendTypingIndicator,
                onVoiceRecording: handleVoiceRecording,
                onVoiceRecordingCancelled: cancelVoiceRecording,
                onAttachPhoto: { showPhotoPicker = true }
            )
            .focused($isInputFocused)
            
            // Voice Recording Overlay
            if isRecordingVoice {
                VoiceRecordingOverlay(
                    duration: audioRecorder.recordingDuration,
                    onCancel: cancelVoiceRecording,
                    onSend: sendVoiceMessage
                )
            }
        }
        .background(themeManager.backgroundPrimary(colorScheme))
        .navigationTitle("#\(channel.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isPinned = StarredChannelsManager.shared.isStarred(channel.id) }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .any(of: [.images, .videos]))
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let mimeType = data.sniffMimeType()
                    let ext = mimeType.components(separatedBy: "/").last ?? "jpg"
                    let filename = "attachment.\(ext)"
                    let msg = try? await apiService.sendMessageWithAttachment(
                        channelId: channel.id,
                        content: messageText,
                        imageData: data,
                        filename: filename,
                        mimeType: mimeType
                    )
                    await MainActor.run {
                        messageText = ""
                        selectedPhotoItem = nil
                        if let msg { messages.append(msg) }
                    }
                }
            }
        }
        .sheet(item: $lightboxURL) { item in
            ImageLightboxView(url: item.url)
                .environment(themeManager)
        }
        .animation(.easeInOut(duration: 0.2), value: showChannelSearch)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        isPinned = StarredChannelsManager.shared.toggle(channelId: channel.id, serverName: resolvedServerName)
                        HapticFeedback.light()
                    }) {
                        Image(systemName: isPinned ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundStyle(isPinned ? .yellow : themeManager.textPrimary(colorScheme))
                    }

                    Button(action: { showChannelSearch.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    }
                }
            }
        }
    }
    
    private var activeTypingUsers: [User] {
        let now = Date()
        let threshold: TimeInterval = 10
        return typingUsers
            .filter { $0.value.addingTimeInterval(threshold) > now }
            .compactMap { _ in User.preview }
    }
    
    // MARK: - Messages
    
    private func loadMessages() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let fetched = try await apiService.getMessages(channelId: channel.id, limit: 50)
                await MainActor.run {
                    self.messages = fetched
                    self.isLoading = false
                }
            } catch {
                NSLog("[flukavike] loadMessages failed for channel %@: %@", channel.id, String(describing: error))
                await MainActor.run {
                    self.isLoading = false
                    self.messages = []
                    switch error as? APIError {
                    case .forbidden:
                        self.errorMessage = "You don't have permission to view this channel's history."
                    case .notFound:
                        self.errorMessage = "Channel not found."
                    case .unauthorized:
                        self.errorMessage = "Session expired. Please log in again."
                    case .serverError(let code, let msg):
                        self.errorMessage = "Server error \(code)\(msg.map { ": \($0)" } ?? "")."
                    default:
                        self.errorMessage = "Failed to load message history."
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        // If we're editing, save the edit instead
        if editingMessage != nil {
            saveEditedMessage()
            return
        }
        
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let content = messageText
        let replyToId = replyingToMessage?.id
        messageText = ""
        replyingToMessage = nil
        isSending = true
        
        Task {
            do {
                let message = try await apiService.sendMessage(
                    channelId: channel.id,
                    content: content,
                    replyToId: replyToId
                )
                await MainActor.run {
                    self.messages.append(message)
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    self.messageText = content
                }
            }
        }
    }
    
    private func saveEditedMessage() {
        guard let editing = editingMessage else { return }
        let newContent = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newContent.isEmpty else { return }
        
        // Optimistically update the message locally
        if let index = messages.firstIndex(where: { $0.id == editing.id }) {
            let updatedMessage = Message(
                id: editing.id,
                channelId: editing.channelId,
                author: editing.author,
                content: newContent,
                timestamp: editing.timestamp,
                editedTimestamp: Date(),
                replyToId: editing.replyToId,
                reactions: editing.reactions,
                attachments: editing.attachments,
                isPinned: editing.isPinned
            )
            messages[index] = updatedMessage
        }
        
        let editingId = editing.id
        messageText = ""
        editingMessage = nil
        isSending = true
        
        Task {
            do {
                _ = try await apiService.editMessage(
                    channelId: channel.id,
                    messageId: editingId,
                    content: newContent
                )
                await MainActor.run {
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    // Revert on error by reloading messages
                    self.loadMessages()
                }
            }
        }
    }
    
    private func deleteMessage(_ message: Message) {
        Task {
            do {
                try await apiService.deleteMessage(channelId: channel.id, messageId: message.id)
                await MainActor.run {
                    messages.removeAll { $0.id == message.id }
                    ToastManager.shared.show("Message deleted")
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.show("Failed to delete message")
                }
            }
        }
    }
    
    private func toggleReaction(on message: Message, emoji: String) {
        let hasReacted = message.reactions.contains { $0.emoji == emoji && $0.me }
        
        // Optimistically update the UI immediately
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updatedReactions = messages[index].reactions
            if let reactionIndex = updatedReactions.firstIndex(where: { $0.emoji == emoji }) {
                var reaction = updatedReactions[reactionIndex]
                if hasReacted {
                    reaction = Reaction(emoji: emoji, count: max(0, reaction.count - 1), me: false)
                    if reaction.count == 0 {
                        updatedReactions.remove(at: reactionIndex)
                    } else {
                        updatedReactions[reactionIndex] = reaction
                    }
                } else {
                    reaction = Reaction(emoji: emoji, count: reaction.count + 1, me: true)
                    updatedReactions[reactionIndex] = reaction
                }
            } else if !hasReacted {
                updatedReactions.append(Reaction(emoji: emoji, count: 1, me: true))
            }
            
            let updatedMessage = Message(
                id: message.id,
                channelId: message.channelId,
                author: message.author,
                content: message.content,
                timestamp: message.timestamp,
                editedTimestamp: message.editedTimestamp,
                replyToId: message.replyToId,
                reactions: updatedReactions,
                attachments: message.attachments,
                isPinned: message.isPinned
            )
            messages[index] = updatedMessage
        }
        
        Task {
            do {
                if hasReacted {
                    try await apiService.removeReaction(channelId: channel.id, messageId: message.id, emoji: emoji)
                } else {
                    try await apiService.addReaction(channelId: channel.id, messageId: message.id, emoji: emoji)
                }
                await MainActor.run {
                    HapticFeedback.light()
                }
            } catch {
                // Revert on error
                loadMessages()
                await MainActor.run {
                    ToastManager.shared.show("Failed to update reaction")
                }
            }
        }
    }
    
    private func sendTypingIndicator() {
        webSocketService.sendTyping(channelId: channel.id)
    }
    
    // MARK: - Voice Messages
    
    private func handleVoiceRecording(isRecording: Bool) {
        Task {
            if isRecording {
                do {
                    _ = try await audioRecorder.startRecording()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            } else {
                if let recording = audioRecorder.stopRecording() {
                    voiceRecording = recording
                }
            }
        }
    }
    
    private func cancelVoiceRecording() {
        audioRecorder.cancelRecording()
        voiceRecording = nil
        isRecordingVoice = false
    }
    
    private func sendVoiceMessage() {
        guard let recording = voiceRecording, let url = recording.url else {
            cancelVoiceRecording()
            return
        }
        
        isSending = true
        isRecordingVoice = false
        voiceRecording = nil
        
        Task {
            do {
                let message = try await apiService.sendVoiceMessage(
                    channelId: channel.id,
                    audioURL: url,
                    duration: recording.duration,
                    waveform: recording.waveform
                )
                await MainActor.run {
                    self.messages.append(message)
                    self.isSending = false
                }
                audioRecorder.deleteRecording(at: url)
            } catch {
                await MainActor.run {
                    self.isSending = false
                }
                print("Failed to send voice message: \(error)")
            }
        }
    }
    
    // MARK: - WebSocket Handlers
    
    private func setupWebSocketHandlers() {
        webSocketService.onMessageCreate = { message in
            guard message.channelId == channel.id else { return }
            DispatchQueue.main.async {
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
                typingUsers.removeValue(forKey: message.author.id)
            }
        }
        
        webSocketService.onMessageUpdate = { message in
            guard message.channelId == channel.id else { return }
            DispatchQueue.main.async {
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[index] = message
                }
            }
        }
        
        webSocketService.onMessageDelete = { messageId in
            DispatchQueue.main.async {
                messages.removeAll { $0.id == messageId }
            }
        }
        
        webSocketService.onTypingStart = { event in
            guard event.channelId == channel.id else { return }
            DispatchQueue.main.async {
                typingUsers[event.userId] = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    typingUsers.removeValue(forKey: event.userId)
                }
            }
        }
    }
    
    private func removeWebSocketHandlers() {
        webSocketService.onMessageCreate = nil
        webSocketService.onMessageUpdate = nil
        webSocketService.onMessageDelete = nil
        webSocketService.onTypingStart = nil
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Discord Message Bubble
struct DiscordMessageBubble: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    var currentUserId: String?
    var channelId: String
    var onImageTap: ((URL) -> Void)?
    var onReply: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onReactionToggle: ((String) -> Void)?
    @State private var showContextMenu: Bool = false
    
    private var isOwnMessage: Bool {
        message.author.id == currentUserId
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AvatarView(user: message.author, size: 40)
                .onTapGesture {}
            
            VStack(alignment: .leading, spacing: 4) {
                // Header - Name and timestamp inline
                HStack(spacing: 8) {
                    Text(message.author.formattedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                    
                    Text(formattedTimestamp(message.timestamp))
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                }
                
                // Reply Reference
                if message.isReply, let _ = message.replyToId {
                    ReplyReferenceView()
                }
                
                // Content (or Voice Message or Images)
                if let voiceAttachment = message.attachments.first(where: { $0.isVoiceMessage }) {
                    VoiceMessageBubble(attachment: voiceAttachment, isFromCurrentUser: false)
                } else {
                    if !message.content.isEmpty {
                        MessageContentView(content: message.content)
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                    let imageAttachments = message.attachments.filter { $0.isImage }
                    if !imageAttachments.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(imageAttachments, id: \.id) { att in
                                AttachmentImageView(attachment: att, onTap: onImageTap)
                            }
                        }
                    }
                }
                
                // Reactions
                if !message.reactions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(message.reactions, id: \.emoji) { reaction in
                            ReactionBubble(
                                reaction: reaction,
                                messageId: message.id,
                                channelId: message.channelId,
                                onToggle: onReactionToggle
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {}
        .onLongPressGesture {
            showContextMenu = true
            HapticFeedback.medium()
        }
        .sheet(isPresented: $showContextMenu) {
            MessageContextMenu(
                message: message,
                channelId: channelId,
                onReply: onReply,
                onEdit: isOwnMessage ? onEdit : nil,
                onDelete: isOwnMessage ? onDelete : nil,
                onReactionToggle: { emoji in
                    onReactionToggle?(emoji)
                }
            )
            .environment(themeManager)
        }
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Reaction Bubble
struct ReactionBubble: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let reaction: Reaction
    let messageId: String?
    let channelId: String?
    let onToggle: ((String) -> Void)?
    
    var body: some View {
        Button(action: {
            onToggle?(reaction.emoji)
        }) {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(.system(size: 14))
                
                Text("\(reaction.count)")
                    .font(.system(size: 12, weight: reaction.me ? .semibold : .medium))
                    .foregroundStyle(reaction.me ? themeManager.accentColor.color : themeManager.textSecondary(colorScheme))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(reaction.me ? themeManager.accentColor.color.opacity(0.15) : themeManager.backgroundTertiary(colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(reaction.me ? themeManager.accentColor.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Discord Typing Indicator
struct DiscordTypingIndicator: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationStep: Int = 0
    
    let users: [User]
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    private var typingText: String {
        let names = users.map { $0.formattedName }
        switch names.count {
        case 1:
            return "\(names[0]) is typing..."
        case 2:
            return "\(names[0]) and \(names[1]) are typing..."
        case 3:
            return "\(names[0]), \(names[1]) and \(names[2]) are typing..."
        default:
            return "Several people are typing..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let firstUser = users.first {
                AvatarView(user: firstUser, size: 32)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(themeManager.textTertiary(colorScheme))
                        .frame(width: 6, height: 6)
                        .opacity(animationStep == index ? 1.0 : 0.4)
                        .offset(y: animationStep == index ? -2 : 0)
                        .animation(.easeInOut(duration: 0.2), value: animationStep)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.backgroundTertiary(colorScheme))
            )
            
            Text(typingText)
                .font(.system(size: 12))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Spacer()
        }
        .onReceive(timer) { _ in
            animationStep = (animationStep + 1) % 3
        }
    }
}

// MARK: - Message Content View (with Channel Mentions)
struct MessageContentView: View {
    @Environment(AppState.self) private var appState
    let content: String
    var font: Font = .system(size: 15)
    
    @State private var selectedChannelId: String?
    
    // Regex pattern for Discord-style channel mentions: <#channelId>
    private static let channelMentionPattern = try! NSRegularExpression(pattern: "<#(\\d+)>", options: [])
    
    var body: some View {
        textWithChannelMentions
            .font(font)
            .lineSpacing(2)
            .sheet(item: $selectedChannelId) { channelId in
                if let channel = findChannel(id: channelId) {
                    NavigationStack {
                        ChatView(channel: channel)
                    }
                }
            }
    }
    
    @ViewBuilder
    private var textWithChannelMentions: some View {
        // Build an attributed string with channel mentions highlighted
        let parsed = parseContent()
        
        if parsed.mentions.isEmpty {
            // No mentions, just show plain text
            Text(content)
        } else {
            // Show text with channel mention buttons overlay
            Text(parsed.displayText)
                .overlay(
                    mentionOverlays(for: parsed.mentions)
                )
        }
    }
    
    private func mentionOverlays(for mentions: [ChannelMention]) -> some View {
        GeometryReader { geo in
            // This is a simplified approach - for a production app,
            // we'd use UITextView with NSTextAttachment for proper inline buttons
            // For now, we'll show channel mentions as separate tappable elements below the text
            EmptyView()
        }
    }
    
    private func parseContent() -> (displayText: String, mentions: [ChannelMention]) {
        var mentions: [ChannelMention] = []
        var displayText = content
        
        let nsRange = NSRange(content.startIndex..., in: content)
        let matches = MessageContentView.channelMentionPattern.matches(in: content, options: [], range: nsRange)
        
        // Process matches in reverse order to preserve string indices
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: content),
                  let channelIdRange = Range(match.range(at: 1), in: content) else { continue }
            
            let channelId = String(content[channelIdRange])
            let mention = ChannelMention(
                id: channelId,
                range: matchRange,
                channelName: findChannel(id: channelId)?.name ?? "unknown-channel"
            )
            mentions.append(mention)
            
            // Replace the mention with a readable format
            let replacement = "#\(mention.channelName)"
            displayText.replaceSubrange(matchRange, with: replacement)
        }
        
        return (displayText, mentions.reversed())
    }
    
    private func findChannel(id: String) -> Channel? {
        for server in appState.gatewayGuilds {
            if let channel = server.channels.first(where: { $0.id == id }) {
                return channel
            }
        }
        return nil
    }
    
    struct ChannelMention: Identifiable {
        let id: String
        let range: Range<String.Index>
        let channelName: String
    }
}

// Extension to make String conform to Identifiable for sheet presentation
extension String: Identifiable {
    public var id: String { self }
}

// MARK: - Channel Mention Pill
struct ChannelMentionPill: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    let channelId: String
    
    @State private var showChannelSheet = false
    
    private var channel: Channel? {
        // Search in all guilds for this channel
        for server in appState.gatewayGuilds {
            if let channel = server.channels.first(where: { $0.id == channelId }) {
                return channel
            }
        }
        return nil
    }
    
    private var server: Server? {
        for server in appState.gatewayGuilds {
            if server.channels.contains(where: { $0.id == channelId }) {
                return server
            }
        }
        return nil
    }
    
    var body: some View {
        Button(action: {
            if channel != nil {
                showChannelSheet = true
                HapticFeedback.light()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: channel?.type == .voice ? "speaker.wave.2.fill" : "number")
                    .font(.system(size: 12))
                Text(channel?.name ?? "unknown-channel")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(themeManager.accentColor.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.accentColor.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(themeManager.accentColor.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showChannelSheet) {
            if let channel = channel {
                NavigationStack {
                    ChatView(channel: channel)
                }
            }
        }
    }
}

// MARK: - Reply Preview View
struct ReplyPreviewView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Reply icon and line
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.accentColor.color)
                Rectangle()
                    .fill(themeManager.accentColor.color.opacity(0.5))
                    .frame(width: 2, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.author.formattedName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.accentColor.color)
                
                Text(message.content.prefix(60))
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.backgroundSecondary(colorScheme))
    }
}

// MARK: - Edit Preview View
struct EditPreviewView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Edit icon and line
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.accentColor.color)
                Rectangle()
                    .fill(themeManager.accentColor.color.opacity(0.5))
                    .frame(width: 2, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.accentColor.color)
                
                Text(message.content.prefix(60))
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.textSecondary(colorScheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(themeManager.textTertiary(colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.backgroundSecondary(colorScheme))
    }
}

// MARK: - Reply Reference View (shown on replied messages)
struct ReplyReferenceView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(themeManager.textTertiary(colorScheme).opacity(0.5))
                .frame(width: 2, height: 20)
            
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 10))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Text("Replying to message")
                .font(.system(size: 12))
                .foregroundStyle(themeManager.textTertiary(colorScheme))
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Discord Input View
struct DiscordInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @Binding var isTyping: Bool
    @Binding var isSending: Bool
    @Binding var isRecording: Bool
    @Binding var replyingTo: Message?
    @Binding var editingMessage: Message?
    
    var onSend: () -> Void
    var onEdit: () -> Void
    var onTyping: () -> Void
    var onVoiceRecording: (Bool) -> Void
    var onVoiceRecordingCancelled: () -> Void
    var onAttachPhoto: () -> Void = {}

    @State private var showEmojiPicker: Bool = false
    
    @State private var lastTypingSent: Date = .distantPast
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeManager.separator(colorScheme))
            
            HStack(spacing: 12) {
                // Plus/Attachment Button
                Button(action: onAttachPhoto) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(themeManager.accentColor.color)
                }
                
                // Text Field Container
                HStack(spacing: 8) {
                    TextField(editingMessage != nil ? "Edit message" : "Message #general", text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .onChange(of: text) { _, newValue in
                            if !newValue.isEmpty && editingMessage == nil {
                                let now = Date()
                                if now.timeIntervalSince(lastTypingSent) > 3 {
                                    lastTypingSent = now
                                    onTyping()
                                }
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )
                
                // Emoji Button
                Button(action: { showEmojiPicker.toggle() }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 24))
                        .foregroundStyle(showEmojiPicker ? themeManager.accentColor.color : themeManager.textTertiary(colorScheme))
                }
                .sheet(isPresented: $showEmojiPicker) {
                    EmojiPickerPopover { emoji in
                        text += emoji
                        showEmojiPicker = false
                    }
                    .environment(themeManager)
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
                }

                // Send button when typing, mic button when empty
                if text.isEmpty {
                    Button(action: {}) {
                        Image(systemName: "mic")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                isRecording = true
                                onVoiceRecording(true)
                                HapticFeedback.medium()
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                if isRecording {
                                    isRecording = false
                                    onVoiceRecording(false)
                                }
                            }
                    )
                } else if editingMessage != nil {
                    // Editing mode - show save button
                    Button(action: onEdit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(themeManager.backgroundSecondary(colorScheme))
        }
    }
}

// MARK: - Voice Recording Overlay
struct VoiceRecordingOverlay: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let duration: TimeInterval
    var onCancel: () -> Void
    var onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeManager.separator(colorScheme))
            
            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    RecordingDot()
                    
                    HStack(spacing: 3) {
                        ForEach(0..<20) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(themeManager.accentColor.color)
                                .frame(width: 3, height: CGFloat.random(in: 8...32))
                        }
                    }
                    .frame(height: 40)
                    
                    Text(formattedDuration)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                
                Spacer()
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(themeManager.accentColor.color)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.backgroundSecondary(colorScheme))
        }
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Dot
struct RecordingDot: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .opacity(isAnimating ? 1.0 : 0.5)
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Voice Message Bubble
struct VoiceMessageBubble: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    let attachment: Attachment
    let isFromCurrentUser: Bool
    
    @State private var audioPlayer = AudioPlayerService.shared
    @State private var localURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: audioPlayer.isPlaying && audioPlayer.currentURL == localURL ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(themeManager.accentColor.color)
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                WaveformView(
                    waveform: attachment.waveform ?? [],
                    progress: audioPlayer.currentURL == localURL ? audioPlayer.progress : 0,
                    color: isFromCurrentUser ? .white.opacity(0.8) : themeManager.accentColor.color
                )
                .frame(height: 32)
                
                HStack {
                    Text(audioPlayer.currentURL == localURL ? audioPlayer.currentTimeString : "0:00")
                        .font(.system(size: 12, design: .monospaced))
                    
                    Spacer()
                    
                    Text(formattedDuration)
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundStyle(isFromCurrentUser ? .white.opacity(0.8) : themeManager.textSecondary(colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFromCurrentUser ? themeManager.accentColor.color : themeManager.backgroundTertiary(colorScheme))
        )
        .onAppear {
            if let url = URL(string: attachment.url) {
                localURL = url
            }
        }
    }
    
    private var formattedDuration: String {
        guard let duration = attachment.duration else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func togglePlayback() {
        guard let url = localURL else { return }
        audioPlayer.togglePlayback(url: url)
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let waveform: [UInt8]
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let barWidth: CGFloat = 3
            let spacing: CGFloat = 2
            let totalBars = min(Int(width / (barWidth + spacing)), waveform.count)
            let step = max(1, waveform.count / totalBars)
            
            HStack(spacing: spacing) {
                ForEach(0..<totalBars, id: \.self) { index in
                    let dataIndex = min(index * step, waveform.count - 1)
                    let amplitude = CGFloat(waveform[dataIndex]) / 255.0
                    let barHeight = max(4, 32 * amplitude)
                    let isPlayed = Double(index) / Double(totalBars) < progress
                    
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isPlayed ? color : color.opacity(0.3))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Haptic Feedback
enum HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Attachment Image View (handles static images; GIF note below)
// GIFs: AsyncImage renders only the first frame (SwiftUI limitation).
// Full GIF animation requires a UIViewRepresentable wrapping UIImageView with animatedImage.
// For now, GIFs are shown as static — the first frame is still useful context.
struct AttachmentImageView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let attachment: Attachment
    var onTap: ((URL) -> Void)?

    // If the direct URL fails, retry with the proxy URL
    @State private var useProxy: Bool = false

    private var imageURL: URL? {
        let raw = useProxy ? (attachment.proxyUrl ?? attachment.url) : attachment.url
        return URL(string: raw) ?? URL(string: raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw)
    }

    private var aspectRatio: CGFloat {
        if let w = attachment.width, let h = attachment.height, h > 0 {
            return CGFloat(w) / CGFloat(h)
        }
        return 16 / 9
    }

    private var displayHeight: CGFloat { min(260 / aspectRatio, 320) }
    private var isGIF: Bool { attachment.contentType == "image/gif" }

    var body: some View {
        Group {
            if let url = imageURL {
                if isGIF {
                    // Use UIImageView for GIF animation support
                    AnimatedGIFView(url: url, useProxy: useProxy, proxyUrl: attachment.proxyUrl)
                        .frame(maxWidth: 260)
                        .frame(height: displayHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { onTap?(url) }
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(maxWidth: 260)
                                .frame(height: displayHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { onTap?(url) }
                        case .failure:
                            if !useProxy, attachment.proxyUrl != nil {
                                // Retry with proxy URL
                                Color.clear.frame(height: 0).onAppear { useProxy = true }
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.backgroundTertiary(colorScheme))
                                    .frame(maxWidth: 260).frame(height: 80)
                                    .overlay(HStack(spacing: 6) {
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                                        Text(attachment.filename).font(.system(size: 12))
                                            .foregroundStyle(themeManager.textTertiary(colorScheme)).lineLimit(1)
                                    })
                            }
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.backgroundTertiary(colorScheme))
                                .frame(maxWidth: 260).frame(height: displayHeight)
                                .overlay(ProgressView())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Animated GIF via UIImageView
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL
    let useProxy: Bool
    let proxyUrl: String?

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        load(into: iv, from: url)
        return iv
    }

    func updateUIView(_ iv: UIImageView, context: Context) {}

    private func load(into iv: UIImageView, from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, _ in
            if let data, let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                DispatchQueue.main.async { iv.image = animatedImage(from: data) }
            } else if let fallback = proxyUrl.flatMap({ URL(string: $0) }), fallback != url {
                // Retry with proxy
                URLSession.shared.dataTask(with: fallback) { data2, _, _ in
                    if let data2 {
                        DispatchQueue.main.async { iv.image = animatedImage(from: data2) }
                    }
                }.resume()
            }
        }.resume()
    }

    private func animatedImage(from data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(src)
        guard count > 1 else { return UIImage(data: data) }
        var frames: [UIImage] = []
        var duration: Double = 0
        for i in 0..<count {
            guard let cgImg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(UIImage(cgImage: cgImg))
            let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any]
            let gifDict = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delay = (gifDict?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                ?? (gifDict?[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
            duration += max(delay, 0.02)
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}

// MARK: - Emoji Picker Popover
struct EmojiPickerPopover: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let onSelect: (String) -> Void

    private let categories: [(name: String, emojis: [String])] = [
        ("Smileys", ["😀","😂","😍","🥰","😎","🤔","😅","😭","😤","🥺","😊","🙂","😋","😜","🤩","🥳","😴","🤯","😡","👻"]),
        ("Gestures", ["👍","👎","❤️","🔥","✨","🎉","👏","🙌","💪","🤝","✌️","🤞","👋","🫶","💯","🎯","🚀","⭐","💡","🎊"]),
        ("Animals", ["🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯","🦁","🐸","🐵","🐔","🐧","🐦","🦆","🦅","🦉","🦋"]),
        ("Food", ["🍕","🍔","🌮","🌯","🍣","🍜","🍦","🎂","🍩","🍪","🍫","🍿","☕","🧋","🥤","🍺","🥂","🍷","🥃","🍵"]),
        ("Symbols", ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","❤️‍🔥","💔","✅","❌","⚡","💥","🌈","🌟","💫","❄️","🌊","🎵"])
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories, id: \.name) { cat in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(cat.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                                .padding(.horizontal, 12)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 4) {
                                ForEach(cat.emojis, id: \.self) { emoji in
                                    Button(action: { onSelect(emoji) }) {
                                        Text(emoji).font(.system(size: 26))
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }
}

// MARK: - Identifiable URL wrapper
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}

// MARK: - Image Lightbox
struct ImageLightboxView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(MagnificationGesture()
                            .onChanged { scale = max(1, $0) }
                            .onEnded { _ in withAnimation { if scale < 1.1 { scale = 1; offset = .zero } } }
                        )
                        .gesture(DragGesture()
                            .onChanged { if scale > 1 { offset = $0.translation } }
                            .onEnded { _ in if scale <= 1 { withAnimation { offset = .zero } } }
                        )
                default:
                    ProgressView().tint(.white)
                }
            }
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

// MARK: - Data MIME sniffing
extension Data {
    func sniffMimeType() -> String {
        var b: UInt8 = 0
        copyBytes(to: &b, count: 1)
        switch b {
        case 0xFF: return "image/jpeg"
        case 0x89: return "image/png"
        case 0x47: return "image/gif"
        case 0x52 where count >= 12:
            let str = String(bytes: prefix(12), encoding: .ascii) ?? ""
            if str.hasPrefix("RIFF") && str.dropFirst(8).hasPrefix("WEBP") { return "image/webp" }
        default: break
        }
        return "application/octet-stream"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ChatView(channel: Channel.previewChannels[1])
    }
    .environment(ThemeManager())
    .environment(AppState())
}
