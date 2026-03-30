//
//  ChatView.swift
//  Chat interface
//

import SwiftUI
import Combine

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
    @State private var typingUsers: [String: Date] = [:]
    @State private var isRecordingVoice: Bool = false
    @State private var voiceRecording: VoiceMessageRecording?
    @FocusState private var isInputFocused: Bool
    
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
                        
                        // Date Header
                        if !messages.isEmpty {
                            Text("Today")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                                .padding(.vertical, 16)
                        }
                        
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Typing Indicator
                        if !activeTypingUsers.isEmpty {
                            TypingIndicator(users: activeTypingUsers)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 8)
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
            
            // Input Area
            MessageInputView(
                text: $messageText,
                isTyping: $isTyping,
                isSending: $isSending,
                isRecording: $isRecordingVoice,
                onSend: sendMessage,
                onTyping: sendTypingIndicator,
                onVoiceRecording: handleVoiceRecording,
                onVoiceRecordingCancelled: cancelVoiceRecording
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17))
                            .foregroundStyle(themeManager.textPrimary(colorScheme))
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "person.2")
                            .font(.system(size: 17))
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
            .compactMap { _ in User.preview } // In real app, look up users by ID
    }
    
    // MARK: - Messages
    
    private func loadMessages() {
        Task {
            isLoading = true
            do {
                let fetched = try await apiService.getMessages(channelId: channel.id, limit: 50)
                await MainActor.run {
                    self.messages = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Fallback to preview messages for mockup
                    self.messages = Message.previewMessages
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let content = messageText
        messageText = ""
        isSending = true
        
        Task {
            do {
                let message = try await apiService.sendMessage(channelId: channel.id, content: content)
                await MainActor.run {
                    self.messages.append(message)
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    // Restore text on failure
                    self.messageText = content
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
                // Start recording
                do {
                    _ = try await audioRecorder.startRecording()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            } else {
                // Stop recording
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
                // Clean up the temporary file
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
                // Remove typing indicator for this user
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
                // Auto-clear after 10 seconds
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
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    @State private var showActions: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AvatarView(user: message.author, size: 40)
                .onTapGesture {
                    // Show user profile
                }
            
            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack(spacing: 8) {
                    Text(message.author.formattedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.accentColor.color)
                    
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textTertiary(colorScheme))
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                    }
                }
                
                // Content (or Voice Message)
                if let voiceAttachment = message.attachments.first(where: { $0.isVoiceMessage }) {
                    VoiceMessageBubble(
                        attachment: voiceAttachment,
                        isFromCurrentUser: false
                    )
                } else {
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .lineSpacing(2)
                }
                    
                // Reactions
                if !message.reactions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(message.reactions, id: \.emoji) { reaction in
                            ReactionBubble(reaction: reaction)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(showActions ? themeManager.backgroundSecondary(colorScheme) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.3)) {
                showActions = true
            }
            HapticFeedback.light()
        }
        .overlay {
            if showActions {
                MessageContextMenu(message: message, isShowing: $showActions)
            }
        }
    }
}

// MARK: - Reaction Bubble
struct ReactionBubble: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let reaction: Reaction
    
    var body: some View {
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
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
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

// MARK: - Message Input View
struct MessageInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @Binding var isTyping: Bool
    @Binding var isSending: Bool
    @Binding var isRecording: Bool
    
    var onSend: () -> Void
    var onTyping: () -> Void
    var onVoiceRecording: (Bool) -> Void
    var onVoiceRecordingCancelled: () -> Void
    
    @State private var lastTypingSent: Date = .distantPast
    @State private var isPressing: Bool = false
    @State private var longPressTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(themeManager.separator(colorScheme))
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.accentColor.color)
                }
                
                // Text Field
                HStack(spacing: 8) {
                    TextField("Message #general", text: $text, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                        .lineLimit(1...6)
                        .onChange(of: text) { _, newValue in
                            if !newValue.isEmpty {
                                let now = Date()
                                if now.timeIntervalSince(lastTypingSent) > 3 {
                                    lastTypingSent = now
                                    onTyping()
                                }
                            }
                        }
                    
                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.textTertiary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.backgroundTertiary(colorScheme))
                )
                
                // Send/Action Buttons
                if text.isEmpty {
                    // Microphone button for voice messages
                    Button(action: {}) {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isRecording ? themeManager.accentColor.color : themeManager.textSecondary(colorScheme))
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
                } else {
                    Button(action: onSend) {
                        if isSending {
                            ProgressView()
                                .tint(themeManager.accentColor.color)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(themeManager.accentColor.color)
                        }
                    }
                    .disabled(isSending)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                // Cancel Button
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                // Recording Indicator
                HStack(spacing: 12) {
                    // Recording dot animation
                    RecordingDot()
                    
                    // Waveform placeholder
                    HStack(spacing: 3) {
                        ForEach(0..<20) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(themeManager.accentColor.color)
                                .frame(width: 3, height: CGFloat.random(in: 8...32))
                                .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: duration)
                        }
                    }
                    .frame(height: 40)
                    
                    // Duration
                    Text(formattedDuration)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundStyle(themeManager.textPrimary(colorScheme))
                }
                
                Spacer()
                
                // Send Button
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
            // Play/Pause Button
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
            
            // Waveform & Progress
            VStack(alignment: .leading, spacing: 6) {
                // Waveform visualization
                WaveformView(
                    waveform: attachment.waveform ?? [],
                    progress: audioPlayer.currentURL == localURL ? audioPlayer.progress : 0,
                    color: isFromCurrentUser ? .white.opacity(0.8) : themeManager.accentColor.color
                )
                .frame(height: 32)
                
                // Duration text
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
            // Download audio file if needed
            // For now, use a local placeholder
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

// MARK: - Message Context Menu
struct MessageContextMenu: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let message: Message
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuButton(icon: "arrowshape.turn.up.left", title: "Reply", color: themeManager.textPrimary(colorScheme)) {}
            MenuButton(icon: "face.smiling", title: "Add Reaction", color: themeManager.textPrimary(colorScheme)) {}
            MenuButton(icon: "doc.on.doc", title: "Copy Text", color: themeManager.textPrimary(colorScheme)) {}
            Divider().background(themeManager.separator(colorScheme))
            MenuButton(icon: "pin", title: "Pin Message", color: themeManager.textPrimary(colorScheme)) {}
            MenuButton(icon: "bell", title: "Remind Me", color: themeManager.textPrimary(colorScheme)) {}
            Divider().background(themeManager.separator(colorScheme))
            MenuButton(icon: "exclamationmark.triangle", title: "Report", color: .red) {}
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.backgroundSecondary(colorScheme))
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
        .frame(width: 180)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .onTapGesture {
            isShowing = false
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - Menu Button
struct MenuButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 16))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Preview
#Preview {
    NavigationStack {
        ChatView(channel: Channel.previewChannels[1])
    }
    .environment(ThemeManager())
    .environment(AppState())
}
