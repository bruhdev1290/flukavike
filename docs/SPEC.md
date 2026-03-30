# Fluxer Mobile - Technical Specification

---

## 🏗 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      FluxerApp (App Entry)                  │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Views      │  │   Models     │  │   Services   │      │
│  │  (SwiftUI)   │  │  (Observable)│  │  (Network)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Utils      │  │   Stores     │  │   Extensions │      │
│  │  (Helpers)   │  │  (AppState)  │  │  (Swift+UI)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Project Structure

```
FluxerMockup/
├── App/
│   ├── FluxerApp.swift
│   └── Info.plist
├── Views/
│   ├── Main/
│   │   ├── MainTabView.swift
│   │   └── SplitView.swift (iPad)
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── ServerPillView.swift
│   │   └── QuickActionsView.swift
│   ├── Channel/
│   │   ├── ChannelListView.swift
│   │   ├── ChannelRowView.swift
│   │   └── CategorySectionView.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubbleView.swift
│   │   ├── MessageInputView.swift
│   │   └── TypingIndicatorView.swift
│   ├── Compose/
│   │   ├── ComposeView.swift
│   │   └── FloatingComposeButton.swift
│   ├── Notifications/
│   │   ├── NotificationsView.swift
│   │   └── NotificationRowView.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── EditProfileView.swift
│   │   └── StatusIndicatorView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── AppearanceSettingsView.swift
│   │   ├── NotificationSettingsView.swift
│   │   └── InstanceSettingsView.swift
│   └── Common/
│       ├── CustomIcons.swift
│       ├── AvatarView.swift
│       ├── BadgeView.swift
│       ├── ContextMenuView.swift
│       └── LoadingView.swift
├── Models/
│   ├── User.swift
│   ├── Server.swift
│   ├── Channel.swift
│   ├── Message.swift
│   ├── Reaction.swift
│   ├── Notification.swift
│   └── Attachment.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── ChatViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── APIService.swift
│   ├── WebSocketService.swift
│   ├── AuthService.swift
│   └── MediaService.swift
├── Stores/
│   ├── AppState.swift
│   ├── ThemeManager.swift
│   └── UserDefaultsStore.swift
├── Utils/
│   ├── Constants.swift
│   ├── Color+Extensions.swift
│   ├── Date+Extensions.swift
│   ├── String+Extensions.swift
│   └── MarkdownParser.swift
└── Resources/
    ├── Assets.xcassets/
    ├── Sounds/
    └── PreviewContent/
```

---

## 📱 Feature Set (MVP)

### Phase 1: Core Messaging
- [x] Server/instance connection
- [x] Channel list browsing
- [x] Real-time messaging
- [x] Markdown support (basic)
- [x] Message reactions
- [x] File attachments

### Phase 2: Social Features
- [x] User profiles
- [x] Presence/status indicators
- [x] Direct messages
- [x] Notifications
- [x] Search

### Phase 3: Power User Features
- [x] Multiple account support
- [x] Threaded replies
- [x] Pinned messages
- [x] Message search
- [x] Custom themes/CSS
- [x] Keyboard shortcuts

### Phase 4: Advanced
- [ ] Screen sharing view
- [ ] Voice channel UI
- [ ] Bot integration
- [ ] Webhook management
- [ ] Admin tools

---

## 🔌 API Integration

### Fluxer API Endpoints
```swift
enum FluxerAPI {
    // Authentication
    case login(instance: String, username: String, password: String)
    case logout
    case refreshToken
    
    // Servers
    case getServers
    case getServer(id: String)
    case joinServer(code: String)
    
    // Channels
    case getChannels(serverId: String)
    case getChannel(id: String)
    case createChannel(serverId: String, name: String)
    
    // Messages
    case getMessages(channelId: String, before: String?)
    case sendMessage(channelId: String, content: String)
    case deleteMessage(id: String)
    case editMessage(id: String, content: String)
    case addReaction(messageId: String, emoji: String)
    
    // Users
    case getUser(id: String)
    case getMe
    case updateProfile
    case getPresence
    
    // Notifications
    case getNotifications
    case markRead(id: String)
    case markAllRead
}
```

### WebSocket Events
```swift
enum WebSocketEvent {
    case messageReceived(Message)
    case messageUpdated(Message)
    case messageDeleted(id: String)
    case userTyping(channelId: String, user: User)
    case presenceUpdate(userId: String, status: UserStatus)
    case reactionAdded(messageId: String, reaction: Reaction)
    case reactionRemoved(messageId: String, emoji: String, userId: String)
    case notificationReceived(Notification)
}
```

---

## 💾 Data Models

### Message
```swift
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let author: User
    let content: String
    let timestamp: Date
    let editedTimestamp: Date?
    let replyTo: Message?
    let reactions: [Reaction]
    let attachments: [Attachment]
    let embeds: [Embed]
    let mentions: [User]
    let pinned: Bool
    
    var isEdited: Bool { editedTimestamp != nil }
    var isReply: Bool { replyTo != nil }
}
```

### Channel
```swift
struct Channel: Identifiable, Codable, Equatable {
    let id: String
    let serverId: String
    let name: String
    let topic: String?
    let type: ChannelType
    let position: Int
    let parentId: String?
    let lastMessageId: String?
    let unreadCount: Int
    let mentionCount: Int
    let nsfw: Bool
    
    enum ChannelType: String, Codable {
        case text
        case voice
        case category
        case announcement
        case thread
    }
}
```

### User
```swift
struct User: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let bannerUrl: String?
    let bio: String?
    let status: UserStatus
    let customStatus: String?
    let badges: [UserBadge]
    let bot: Bool
    let createdAt: Date
    
    var displayUsername: String { "@\(username)" }
    var formattedName: String { displayName ?? username }
}

enum UserStatus: String, Codable {
    case online
    case idle
    case dnd // Do not disturb
    case offline
    case invisible
}
```

---

## 🎨 Theme System

### Theme Manager
```swift
@Observable
class ThemeManager {
    var currentTheme: Theme = .default
    var accentColor: AccentColor = .blueberry
    
    enum Theme: String, CaseIterable {
        case `default`
        case oled
        case lowContrast
        case highContrast
    }
    
    enum AccentColor: String, CaseIterable {
        case blueberry, strawberry, orange, banana
        case green, mint, teal, grape, pink, platinum
    }
    
    var backgroundPrimary: Color { /* computed */ }
    var backgroundSecondary: Color { /* computed */ }
    var textPrimary: Color { /* computed */ }
    var accent: Color { /* computed from accentColor */ }
}
```

---

## 🔄 State Management

### App State
```swift
@Observable
class AppState {
    // Authentication
    var isAuthenticated: Bool = false
    var currentUser: User?
    
    // Current context
    var selectedServer: Server?
    var selectedChannel: Channel?
    
    // UI State
    var isShowingSettings: Bool = false
    var isShowingCompose: Bool = false
    var unreadNotifications: Int = 0
    
    // Connection
    var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
    }
}
```

---

## 📱 Platform-Specific Features

### iPhone
- Bottom tab navigation
- Full-screen chat view
- Swipe gestures for quick actions
- Pull-to-refresh

### iPad
- Sidebar navigation (3-column)
- Drag and drop support
- Multi-window support
- Keyboard shortcut support

### macOS (Catalyst/AppKit)
- Menu bar integration
- Keyboard shortcuts
- Multiple windows
- Touch Bar support

---

## 🧪 Testing Strategy

### Unit Tests
- Model serialization
- ViewModel logic
- Service mocks
- Utility functions

### UI Tests
- Navigation flows
- Message composition
- Settings changes
- Login/logout

### Performance Tests
- Message list scrolling
- Image loading
- WebSocket reconnection
- Theme switching

---

## 🚀 Build & Distribution

### Development
```bash
# Run on simulator
xcodebuild -scheme FluxerMockup -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run tests
xcodebuild test -scheme FluxerMockup -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Distribution
- TestFlight for beta testing
- App Store for release
- AltStore for sideloading (optional)

---

## 📚 Dependencies (Optional)

### Core
- **SwiftUI** - Native UI framework
- **Foundation** - Core utilities

### Networking
- **URLSession** - Native networking
- **Starscream** - WebSocket client (if needed)

### Media
- **Nuke** - Image loading/caching
- **AVFoundation** - Audio/Video

### Utilities
- **KeychainAccess** - Secure storage
- **SwiftLint** - Code style

---

## 🎯 Success Metrics

- 60fps scrolling performance
- <500ms message send time
- <2s app launch time
- <50MB memory usage (normal usage)
- 4.5+ App Store rating

---

*Technical Specification for Fluxer Mobile Client*
