# Running Fluxer Mobile on iOS Simulator

## Quick Start

The iOS Simulator has been booted and is ready:

```
✅ iPhone 17 Pro Simulator - Booted and Ready
   iOS Version: 26.4
   Device ID: BE39EAB0-46C7-4EDA-BA62-9A08D6D41443
```

## How to Run the App

Since this is a SwiftUI mockup project, you need to create an Xcode project and build the app.

### Step 1: Create Xcode Project

1. **Open Xcode** on your Mac
2. **File → New → Project** → Select **iOS** → **App**
3. **Configure**:
   - **Name**: `FluxerMockup`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Team**: Your Apple ID (or None for simulator only)
   - **Organization Identifier**: `com.yourname`
   - **Bundle Identifier**: `com.yourname.fluxermockup` (auto-generated)

### Step 2: Add Source Files

1. In the Project Navigator, **delete** the default files:
   - `ContentView.swift`
   - `<YourAppName>App.swift`

2. **Right-click** the project folder → **Add Files to "FluxerMockup"...**
3. Select **all files** from the `FluxerMockup/` folder in this repo
4. Make sure **"Copy items if needed"** is checked
5. Click **Add**

### Step 3: Build and Run

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
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FluxerMockup.app

# Launch app
xcrun simctl launch booted com.yourname.fluxermockup

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

### Call UI (Mock)
1. In code, modify `AppState.swift`:
   ```swift
   var isAuthenticated = true  // Already set
   ```
2. To test incoming call, the CallService is set up but requires actual API

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

1. Implement OAuth/login flow
2. Add actual API base URL
3. Configure WebRTC for voice/video
4. Test on physical device (requires Apple Developer Program)

---

**Enjoy building with SwiftUI!** 🚀
