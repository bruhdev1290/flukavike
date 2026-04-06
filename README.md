# Flukavike

An iOS client for [Fluxer](https://fluxer.app) — a modern messaging platform for communities.

[**Join the TestFlight Beta →**](https://testflight.apple.com/join/xfZsJx31)

---

## ✨ Design Philosophy

This project follows these design principles:

- **Polished & Refined**: Every pixel matters, smooth 120fps animations
- **Playful but Professional**: Delightful micro-interactions without being childish
- **Customizable**: Multiple themes including OLED Dark mode, 11 accent colors
- **Content First**: Clean typography, generous whitespace
- **Native Feel**: Built with SwiftUI for optimal performance

---

## 🎨 Features

### Implemented

| Feature | Description |
|---------|-------------|
| 🎨 **Theme System** | Light, Dark, OLED Dark modes with 11 accent colors |
| 🏠 **Home Screen** | Server pills, pinned channels, recent conversations |
| 💬 **Chat Interface** | Message bubbles, reactions, typing indicators, voice messages, rich attachments, inline replies |
| 📱 **Navigation** | Customizable tab bar with floating compose button |
| 🔔 **Notifications** | Push notifications with mentions, DMs, calls |
| 📞 **Voice/Video Calls** | CallKit integration for calls |
| 🔊 **Voice Channels** | Join voice channels with participant tracking, speaking indicators |
| 👤 **Profile** | User profiles with stats and customization |
| ⚙️ **Settings** | Comprehensive settings with appearance options |
| 🚀 **Onboarding** | Welcome flow with web-based OAuth login |
| 🔐 **Authentication** | Secure token storage in Keychain with web OAuth flow |
| 📤 **Composer** | Rich message composer with attachments and voice recording |
| 🔍 **Search** | Global search for messages and content |
| 📝 **Messages View** | Dedicated messages/DMs interface |

### Design Highlights

- **Hexagon Branding**: Fluxer logo-inspired shapes throughout
- **Inline Replies**: Long-press any message to reply
- **Custom Context Menus**: Long-press channels/servers for quick actions
- **Toast Notifications**: Visual feedback for actions
- **Smooth Animations**: Spring-based transitions
- **Haptic Feedback**: Tactile responses for interactions
- **Adaptive Colors**: Dynamic text and background colors
- **Real-time**: WebSocket events for messages, calls, presence

---

## 📁 Project Structure

```
flukavike/
├── FluxerApp.swift              # App entry point with push setup
├── Services/
│   ├── APIService.swift         # Fluxer REST API client
│   ├── WebSocketService.swift   # Real-time Gateway connection
│   ├── AuthService.swift        # Authentication management (legacy)
│   ├── WebAuthService.swift     # Web-based OAuth authentication
│   ├── KeychainTokenStore.swift # Secure token storage
│   ├── FluxerCallService.swift  # CallKit & voice calls
│   ├── AudioRecorderService.swift # Voice message recording
│   ├── AudioPlayerService.swift # Voice message playback
│   ├── PushNotificationService.swift # APNs handling
│   └── SiriDonationService.swift # Siri intent donation
├── Stores/
│   └── ThemeManager.swift       # Theme & state management
├── Models/
│   └── Models.swift             # Data models (User, Message, Server, etc.)
├── Views/
│   ├── Main/
│   │   ├── MainTabView.swift    # Bottom tab navigation
│   │   ├── OnboardingView.swift # Welcome & login flow
│   │   ├── WebLoginView.swift   # Web-based OAuth login
│   │   └── WebAPILoginView.swift # API-based login fallback
│   ├── Home/
│   │   ├── HomeView.swift       # Home dashboard
│   │   ├── ChannelListView.swift # Channel browser
│   │   └── StarredChannelsView.swift # Starred channels list
│   ├── Messages/
│   │   └── MessagesView.swift   # Direct messages view
│   ├── Chat/
│   │   └── ChatView.swift       # Message interface with inline replies
│   ├── Call/
│   │   ├── CallView.swift       # Active call UI
│   │   └── VoiceChannelView.swift # Voice channel grid
│   ├── Compose/
│   │   └── ComposeView.swift    # Message composer
│   ├── Search/
│   │   └── SearchView.swift     # Global search
│   ├── Notifications/
│   │   └── NotificationsView.swift
│   ├── Profile/
│   │   └── ProfileView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Common/
│       ├── CommonViews.swift    # Shared UI components
│       ├── ContextMenus.swift   # Channel/server/DM context menus
│       └── HCaptchaView.swift   # hCaptcha verification
├── Intents/
│   └── FlukavikeIntents.swift   # Siri intent definitions
└── docs/
    ├── DESIGN.md                # Design system documentation
    ├── SPEC.md                  # Technical specification
    ├── API_REFERENCE.md         # Fluxer API documentation
    ├── API_INTEGRATION.md       # Integration guide
    ├── SIRI_INTEGRATION.md      # Siri setup guide
    ├── PUSH_CALL_SETUP.md       # Push notification setup
    ├── PREVIEW.md               # Preview/testing guide
    └── ACCESSIBILITY.md         # Accessibility features
```

---

## 🚀 Getting Started

### Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- CocoaPods (for dependencies)

### Running the Project

1. Clone the repository
2. Run `pod install` in the project directory
3. Open `flukavike.xcworkspace` in Xcode
4. Select an iOS Simulator or device
5. Build and run (⌘+R)

---

## 🎨 Customization

### Adding a New Theme

Edit `ThemeManager.swift`:

```swift
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case oled = "OLED Dark"
    case yourTheme = "Your Theme" // Add here
}
```

### Adding a New Accent Color

```swift
enum AccentColor: String, CaseIterable, Identifiable {
    // ... existing colors
    case yourColor = "Your Color"
    
    var color: Color {
        switch self {
        // ... existing cases
        case .yourColor: return Color(red: ..., green: ..., blue: ...)
        }
    }
}
```

---

## 📱 Screenshots

| Home | Chat | Profile | Settings |
|------|------|---------|----------|
| Server pills, recent conversations | Message bubbles, reactions | User stats | Themes, accent colors |

---

## ⚠️ Critical: Message Decoding — Mixed-Type Fluxer Objects

**Do not simplify the `MessageReference` or `EmojiObject` structs in `Models.swift`.**

Fluxer's API returns two objects that cannot be decoded as `[String: String]`:

- **`message_reference`** — contains a `type` field with an **integer** value alongside string fields. Decoding as `[String: String]` throws a `typeMismatch` error that propagates up and fails the entire message array, breaking history loading on any channel with replied-to messages.

- **`emoji`** (inside reactions) — contains `id` (integer or null) and `animated` (bool) alongside the `name` string. Same consequence: one bad reaction kills the whole channel decode.

Both are handled with private typed structs (`MessageReference`, `EmojiObject`) that only decode the fields actually needed, with `try?` used at the call sites so any unexpected shape produces a nil rather than a throw.

**File:** `Models/Models.swift` — search for `⚠️ WARNING` to find all three affected sites.

---

## ⚠️ Critical: Channel Loading Architecture

**Do not change how channels are fetched without reading this first.**

Fluxer does **not** return channel data from the REST endpoint `GET /guilds/{id}/channels` — that endpoint always returns an empty array `[]` for regular user tokens, regardless of guild membership or permissions.

Channels are delivered exclusively through the **WebSocket Gateway READY event**, the same pattern Discord uses for large guilds. The READY payload includes a `guilds` array where each guild object contains its full channel list.

The channel loading flow is:

1. `FluxerApp` connects the WebSocket on login
2. When the Gateway sends `READY`, `onReady` stores `ready.guilds` into `AppState.gatewayGuilds`
3. `HomeView.loadChannels(for:)` checks `appState.gatewayGuilds` first and uses the channels from there
4. `HomeView` has an `.onChange(of: appState.gatewayGuilds)` observer that reloads channels if the READY event arrives after the initial server list load
5. The REST call at the bottom of `loadChannels` is a last-resort fallback only (it will return `[]` on Fluxer but may work on other compatible instances)

**Files involved:**
- `FluxerApp.swift` — `webSocketService.onReady` callback
- `Stores/ThemeManager.swift` — `AppState.gatewayGuilds`
- `Views/Home/HomeView.swift` — `loadChannels(for:)` and `.onChange(of: appState.gatewayGuilds)`

---

## 📝 Recent Updates

### Web-Based OAuth Authentication
Replaced direct API login with a secure web-based OAuth flow using `ASWebAuthenticationSession`. Tokens are securely stored in the iOS Keychain.

### Messages View
Dedicated interface for direct messages and conversations, separate from server channels.

### Search Functionality
Global search for finding messages, users, and content across servers.

### Voice Messages
Record and send voice messages with waveform visualization and playback controls.

### Starred Channels
Mark channels as favorites for quick access from the home screen.

### Toast Notification System
All actions provide visual feedback via toast notifications that appear at the bottom of the screen.

---

## 🛠 Roadmap

### Phase 1: Core ✅
- [x] Basic UI structure
- [x] Theme system
- [x] Navigation
- [x] Web-based OAuth authentication

### Phase 2: Integration ✅
- [x] Fluxer API client
- [x] WebSocket connection
- [x] Real-time messaging
- [x] Gateway-based channel loading

### Phase 3: Polish ✅
- [x] Push notifications
- [x] CallKit integration
- [x] Inline message replies
- [x] Voice messages
- [x] Search functionality
- [x] Toast notification system
- [ ] Screen sharing
- [ ] Widgets

### Phase 4: Advanced 🚧
- [ ] iPad multi-column support
- [ ] Siri integration
- [ ] Share extension

---

## 📚 Documentation

- [Design System](docs/DESIGN.md) — UI/UX guidelines and design tokens
- [API Reference](docs/API_REFERENCE.md) — Fluxer API documentation
- [API Integration](docs/API_INTEGRATION.md) — Integration guide
- [Push & Call Setup](docs/PUSH_CALL_SETUP.md) — Push notification configuration
- [Siri Integration](docs/SIRI_INTEGRATION.md) — Siri setup guide
- [Accessibility](docs/ACCESSIBILITY.md) — Accessibility features

---

## 📚 Learning Resources

New to Swift/SwiftUI? Here are some helpful resources:

- [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com/100/swiftui)
- [SwiftUI by Example](https://www.hackingwithswift.com/quick-start/swiftui)
- [Design Code](https://designcode.io/swiftui-handbook)

---

## 🤝 Contributing

This is a learning project! Feel free to:

- Fork and experiment
- Submit improvements
- Report issues
- Share your own versions

---

## 📄 License

MIT License - feel free to use this as a starting point for your own projects.

---

## 🙏 Acknowledgments

- Built for the [Fluxer](https://fluxer.app) platform
- Created for educational purposes

---

Made with ❤️ and SwiftUI
