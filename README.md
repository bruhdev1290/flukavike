# Fluxer Mobile

An iOS client for [Fluxer](https://fluxer.app) — a modern messaging platform for communities.


---

## ✨ Design Philosophy

This project follows these design principles:

- **Polished & Refined**: Every pixel matters, smooth 120fps animations
- **Playful but Professional**: Delightful micro-interactions without being childish
- **Customizable**: Multiple themes including OLED Dark mode, 10 accent colors
- **Content First**: Clean typography, generous whitespace
- **Native Feel**: Built with SwiftUI for optimal performance

---

## 🎨 Features

### Implemented

| Feature | Description |
|---------|-------------|
| 🎨 **Theme System** | Light, Dark, OLED Dark modes with 10 accent colors |
| 🏠 **Home Screen** | Server pills, pinned channels, recent conversations |
| 💬 **Chat Interface** | Message bubbles, reactions, typing indicators, voice messages, rich attachments |
| 📱 **Navigation** | Customizable tab bar with floating compose button |
| 🔔 **Notifications** | Push notifications with mentions, DMs, calls |
| 📞 **Voice/Video Calls** | CallKit integration for calls |
| 🖥 **Screen Sharing** | Broadcast extension for screen sharing |
| 🔊 **Voice Channels** | Join voice channels with video support, Siri voice commands |
| 👤 **Profile** | User profiles with stats, tabs, and customization |
| ⚙️ **Settings** | Comprehensive settings with appearance options |
| 🚀 **Onboarding** | Welcome flow with instance selection |
| 🎤 **Siri Integration** | Send messages, start calls, join voice channels via voice |
| 📤 **Share Extension** | Share content from any app to Fluxer |
| ✍️ **Composer** | Rich message composer with attachments |

### Design Highlights

- **Hexagon Branding**: Fluxer logo-inspired shapes throughout
- **Custom Context Menus**: Long-press to reveal actions
- **Smooth Animations**: Spring-based transitions
- **Haptic Feedback**: Tactile responses for interactions
- **Adaptive Colors**: Dynamic text and background colors
- **Push Notifications**: APNs integration for messages and calls
- **CallKit**: Native iOS call handling via Fluxer API
- **Screen Share**: Broadcast upload extension + Fluxer SFU
- **Voice Channels**: Join channels via Fluxer Gateway
- **Real-time**: WebSocket events for messages, calls, presence

---

## 📁 Project Structure

```
FluxerMockup/
├── FluxerApp.swift              # App entry point with push setup
├── Services/
│   ├── PushNotificationService.swift  # APNs handling
│   ├── APIService.swift         # Fluxer REST API client
│   ├── WebSocketService.swift   # Real-time Gateway connection
│   ├── AuthService.swift        # Authentication management
│   ├── FluxerCallService.swift  # CallKit & voice calls
│   ├── AudioRecorderService.swift # Voice message recording
│   ├── AudioPlayerService.swift # Voice message playback
│   └── SiriDonationService.swift # Siri intent donation
├── Stores/
│   └── ThemeManager.swift       # Theme & state management
├── Models/
│   └── Models.swift             # Data models (User, Message, Call, etc.)
├── Views/
│   ├── Main/
│   │   ├── MainTabView.swift    # Bottom tab navigation
│   │   └── OnboardingView.swift # Welcome & login flow
│   ├── Home/
│   │   ├── HomeView.swift       # Home dashboard
│   │   └── ChannelListView.swift # Channel browser
│   ├── Chat/
│   │   └── ChatView.swift       # Message interface
│   ├── Call/
│   │   ├── CallView.swift       # Active call UI
│   │   └── VoiceChannelView.swift # Voice channel grid
│   ├── Compose/
│   │   └── ComposeView.swift    # Message composer
│   ├── Notifications/
│   │   └── NotificationsView.swift
│   ├── Profile/
│   │   └── ProfileView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Common/
│       └── CommonViews.swift    # Shared UI components
├── FluxerBroadcastExtension/    # Screen sharing extension
│   ├── SampleHandler.swift
│   └── Info.plist
├── FluxerIntentExtension/       # Siri intent handling
│   ├── IntentHandler.swift
│   └── Info.plist
├── FluxerShareExtension/        # Share sheet extension
│   ├── ShareViewController.swift
│   └── Info.plist
└── docs/
    ├── DESIGN.md                # Design system documentation
    ├── SPEC.md                  # Technical specification
    ├── API_REFERENCE.md         # Fluxer API documentation
    ├── API_INTEGRATION.md       # Integration guide
    ├── SIRI_INTEGRATION.md      # Siri setup guide
    └── PUSH_CALL_SETUP.md       # Push notification setup
```

---

## 🚀 Getting Started

### Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Running the Project

1. Open `FluxerMockup` folder in Xcode
2. Select an iOS Simulator or device
3. Build and run (⌘+R)

### Project Setup

If you want to start fresh with your own project:

1. Create a new SwiftUI project in Xcode
2. Copy the files from this mockup
3. Update bundle identifier and team
4. Build and run

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
| Server pills, recent conversations | Message bubbles, reactions | User stats, tabs | Themes, accent colors |

---

## 🛠 Roadmap

### Phase 1: Core (Current)
- [x] Basic UI structure
- [x] Theme system
- [x] Navigation
- [x] Mock data

### Phase 2: Integration
- [x] Fluxer API client
- [x] WebSocket connection
- [x] Real-time messaging
- [x] Authentication

### Phase 3: Polish
- [x] Custom app icons
- [x] Push notifications
- [x] CallKit integration
- [x] Screen sharing
- [ ] Sound effects
- [ ] Widgets

### Phase 4: Advanced
- [ ] iPad multi-column support
- [x] Share extension
- [x] Siri integration

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
