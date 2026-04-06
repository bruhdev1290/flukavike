# Running Flukavike on iOS Simulator

## Quick Start

The iOS Simulator has been booted and is ready:

```
✅ iPhone 17 Pro Simulator - Booted and Ready
   iOS Version: 26.4
   Device ID: BE39EAB0-46C7-4EDA-BA62-9A08D6D41443
```

## How to Run the App

### Build and Run

1. Run `pod install` to install dependencies
2. Open `flukavike.xcworkspace` in Xcode
3. Select an iOS Simulator or device
4. Build and run (⌘+R)

1. Select **iPhone 17 Pro** simulator from the device dropdown
2. Press **Cmd+R** or click the **Play** button ▶️

The app will build and launch in the simulator!

---

## What You'll See

### 1. Onboarding Screen
- Welcome slides explaining Fluxer
- Login screen with instance selection
- QR code login option

### 2. Main App Interface

**Home Tab** (`🏠`):
- Server pills at top
- Pinned channels section
- Recent conversations
- Recent notifications

**Channels Tab** (`#`):
- Channel list by category
- Unread badges
- Mention indicators

**Compose Button** (floating hexagon):
- Tap to create new message
- Rich composer with attachments

**Notifications Tab** (`🔔`):
- Filterable notification list
- Swipe to mark read/delete

**Profile Tab** (`👤`):
- User profile with banner
- Stats (posts, following, followers)
- Tabbed content (Posts, Media, Replies, Likes)

**Settings** (gear icon):
- Theme selection (System/Light/Dark/OLED)
- 10 accent colors
- Notification settings
- Call settings

### 3. Chat Interface
- Message bubbles with avatars
- Reactions (👍❤️)
- Typing indicators
- Long-press for context menu (Reply, React, Copy, Pin)

### 4. Call Features
- Incoming call screen
- Active call with video/audio controls
- Screen sharing button
- Voice channel grid view

---

## Simulator Commands

```bash
# Boot simulator (already done)
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl boot BE39EAB0-46C7-4EDA-BA62-9A08D6D41443

# Install app (after building)
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/flukavike.app

# Launch app
xcrun simctl launch booted app.fluxer.flukavike

# Take screenshot
xcrun simctl io booted screenshot screenshot.png

# Shutdown simulator
xcrun simctl shutdown booted
```

---

## Testing Features

Once the app is running, try these:

### Theme Switching
1. Go to **Profile** tab
2. Tap **Settings** (gear icon)
3. Tap **Theme & Colors**
4. Try different themes and accent colors

### Chat Interactions
1. Go to **Channels** tab
2. Tap any text channel
3. Long-press a message
4. Try **Reply**, **Add Reaction**, **Copy**

### Authentication Flow
1. Use **Skip** or complete onboarding to reach the **Login** screen
2. Enter instance, username, and password
3. On successful login, the auth token is stored in Keychain
4. WebSocket connects automatically
5. Use **Settings → Sign Out** to clear the token

### Voice Messages
1. Go to **Channels** tab and enter a chat
2. Long-press the **microphone** button (right side of input)
3. Record your voice message (0.5s minimum, 5 minutes maximum)
4. Release to see the recording preview
5. Tap **send** to send, or **X** to cancel
6. Voice messages display with waveform visualization and playback controls

### Voice Messages
1. Go to **Messages** tab or enter a chat channel
2. Long-press the **microphone** button (right side of input)
3. Record your voice message (0.5s minimum, 5 minutes maximum)
4. Release to see the recording preview
5. Tap **send** to send, or **X** to cancel
6. Voice messages display with waveform visualization and playback controls

### Search
1. Go to **Search** tab
2. Enter search terms to find messages, users, or content

---

## Troubleshooting

### "CommandLineTools" error
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Build Errors
- Make sure **all Swift files** are added to the target
- Check **Deployment Target** is iOS 17.0+
- Clean build folder: **Shift+Cmd+K**

### Simulator Issues
```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all  # ⚠️ Deletes all simulator data
```

---

## Requirements

- **macOS**: 14.0+
- **Xcode**: 15.0+
- **iOS Simulator**: 17.0+
- **Apple ID**: Free account works for simulator builds

---

## Next Steps

To connect to real Fluxer servers:

1. The app connects to `web.fluxer.app` by default
2. Configure your own Fluxer instance URL in settings
3. Test on physical device (requires Apple Developer Program)

---

**Enjoy building with SwiftUI!** 🚀
