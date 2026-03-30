# Fluxer Mobile - Preview Guide

This document helps you understand the mockup and what to look for when previewing.

---

## 🎬 How to Preview

### In Xcode Previews

Most views have a `#Preview` block at the bottom. Simply:

1. Open any view file
2. Look for the canvas on the right (or press ⌥⌘↵ to show it)
3. See the live preview

### On Simulator/Device

1. Build and run the project
2. The app starts in "authenticated" mode for demo purposes
3. Explore all tabs and features

---

## 🎯 Key Features to Try

### 1. Theme Switching
**Location**: Settings → Appearance

Try different combinations:
- System / Light / Dark / OLED themes
- 10 different accent colors
- Watch the app adapt instantly

### 2. Floating Compose Button
**Location**: All tabs

- Notice the hexagonal button in the bottom-right
- Tapping it opens the composer sheet
- Draggable button concept (visual only in mockup)

### 3. Long-Press Context Menu
**Location**: Chat view, tap a message

- Long-press any message bubble
- See the custom context menu appear
- Options: Reply, React, Copy, Pin, Remind, Report

### 4. Notification Filtering
**Location**: Notifications tab → "All" dropdown

- Tap the filter dropdown
- Switch between All, Mentions, Reactions, Messages
- Try "Mark All as Read"

### 5. Profile Tabs
**Location**: Profile tab

- Switch between Posts, Media, Replies, Likes
- See different content layouts
- Notice the sliding tab indicator

### 6. Onboarding Flow
**Location**: Log out first (Profile → menu → not implemented)

For preview, modify `AppState.swift`:
```swift
var isAuthenticated: Bool = false
```

Then restart to see:
- Welcome screens
- Login form
- Instance picker
- QR code option

---

## 🎨 Design Details to Notice

### Typography
- Uses SF Pro throughout
- Careful hierarchy: Large Title for nav, Body for content
- Timestamps in secondary color, smaller size

### Colors
- Dynamic backgrounds: Primary, Secondary, Tertiary
- Text hierarchy: Primary, Secondary, Tertiary
- Accent color applied consistently
- OLED theme uses pure black (#000000)

### Spacing
- 4pt grid system
- Consistent 16pt horizontal padding
- 8-12pt vertical spacing between elements
- Generous whitespace (content-first approach)

### Icons
- SF Symbols with custom styling
- 24x24pt base size
- 1.5pt effective stroke
- Color changes based on state

### Animations
- Spring-based transitions
- Scale effects on buttons
- Smooth tab switching
- Subtle opacity changes

---

## 🔍 Code Patterns

### Theme Usage
```swift
@Environment(ThemeManager.self) private var themeManager
@Environment(\.colorScheme) private var colorScheme

// Then use:
themeManager.backgroundPrimary(colorScheme)
themeManager.accentColor.color
themeManager.textPrimary(colorScheme)
```

### Button Styles
```swift
Button(action: {}) {
    Label("Text", systemImage: "icon")
}
.buttonStyle(ScaleButtonStyle()) // Custom animation
```

### Lists
```swift
List {
    Section("Header") {
        ForEach(items) { item in
            RowView(item: item)
                .listRowBackground(themeManager.backgroundPrimary(colorScheme))
                .listRowSeparator(.hidden)
        }
    }
}
.listStyle(.plain)
```

---

## 🐛 Known Limitations

This is a mockup, so:

1. **No Real Data**: All data is hardcoded/mock
2. **No Network**: No actual API calls
3. **No Persistence**: Settings don't save between launches
4. **Limited Interactions**: Some buttons are visual only
5. **No Auth**: Login form accepts anything

These are intentional - focus is on UI/UX exploration.

---

## 💡 Next Steps

To turn this into a real app:

1. **Add API Client**
   - Create `APIService.swift`
   - Define endpoints for Fluxer API
   - Handle authentication

2. **Add State Management**
   - Use `@Observable` for reactive updates
   - Implement proper ViewModels
   - Add error handling

3. **Add Persistence**
   - UserDefaults for settings
   - Core Data/SwiftData for messages
   - Keychain for credentials

4. **Add Real-time**
   - WebSocket client
   - Push notification handling
   - Message sync

5. **Polish**
   - Custom app icon
   - Launch screen
   - Error states
   - Loading skeletons

---

## 📸 Screenshot Checklist

When showcasing the app, capture:

- [ ] Home screen with server pills
- [ ] Chat with message bubbles
- [ ] Reactions on a message
- [ ] Context menu (long-press)
- [ ] Notifications list
- [ ] Profile with tabs
- [ ] Settings → Appearance with different themes
- [ ] Dark mode variant
- [ ] OLED mode (true black)
- [ ] Different accent colors
- [ ] Composer sheet
- [ ] Onboarding screens

---

## 🎤 Presentation Tips

When showing this to others:

1. **Start with the story**: "I wanted to learn SwiftUI by building something real"
2. **Show the inspiration**: "Designed with attention to detail and polish"
3. **Demonstrate themes**: Live switch between light/dark/OLED
4. **Highlight interactions**: Long-press, swipe actions, haptics
5. **Explain the architecture**: SwiftUI + Observation pattern
6. **Share next steps**: What you'd add with real API integration

---

Enjoy exploring the mockup! 🚀
