//
//  ChatView.swift
//  Chat interface
//

import SwiftUI

struct ChatView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let channel: Channel
    
    @State private var messages: [Message] = Message.previewMessages
    @State private var messageText: String = ""
    @State private var isTyping: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Date Header
                        Text("Today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(themeManager.textTertiary(colorScheme))
                            .padding(.vertical, 16)
                        
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Typing Indicator
                        if isTyping {
                            TypingIndicator()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Input Area
            MessageInputView(text: $messageText, isTyping: $isTyping)
                .focused($isInputFocused)
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
                
                // Content
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.textPrimary(colorScheme))
                    .lineSpacing(2)
                    
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
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: User.preview, size: 32)
            
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
                    Button(action: {}) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.textSecondary(colorScheme))
                    }
                } else {
                    Button(action: {}) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeManager.backgroundSecondary(colorScheme))
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
