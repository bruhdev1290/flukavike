# Fluxer Mobile Client - Design System

---

## 🎨 Design Philosophy

### Core Principles
- **Polished & Refined**: Every pixel matters, smooth 120fps animations
- **Playful but Professional**: Delightful micro-interactions without being childish
- **Customizable**: Multiple themes, accent colors, and layout options
- **Unique Iconography**: Custom line-style icons, not SF Symbols
- **Content First**: Clean typography, generous whitespace

---

## 📱 Layout Structure

### Primary Navigation (Bottom Tab Bar)
Customizable tab bar design:

```
┌─────────────────────────────────────────┐
│  🏠    💬    ➕    🔔    👤            │
│ Home  Chats  New   Notif  Profile      │
└─────────────────────────────────────────┘
```

**Tab Bar Features:**
- Custom line-art icons with animated selection states
- Long-press to customize which tabs appear
- Subtle haptic feedback on selection
- Floating compose button option (draggable)

---

## 🎨 Color System

### Light Mode
```
Background Primary:   #FFFFFF
Background Secondary: #F2F2F7 (iOS system gray6)
Background Tertiary:  #E5E5EA (iOS system gray5)

Text Primary:         #000000
Text Secondary:       #6C6C70 (iOS system gray)
Text Tertiary:        #9CA3AF

Separator:            #E5E5EA
Overlay:              rgba(0, 0, 0, 0.4)
```

### Dark Mode - "Midnight"
```
Background Primary:   #000000
Background Secondary: #1C1C1E
Background Tertiary:  #2C2C2E

Text Primary:         #FFFFFF
Text Secondary:       #98989F
Text Tertiary:        #636366

Separator:            #38383A
```

### Dark Mode - "OLED"
```
Background Primary:   #000000 (Pure black)
Background Secondary: #0A0A0A
Background Tertiary:  #141414
```

### Accent Colors (Selectable)
```
Blueberry:   #007AFF  (Default)
Strawberry:  #FF3B30
Orange:      #FF9500
Banana:      #FFCC00
Green:       #34C759
Mint:        #00C7BE
Teal:        #30B0C7
Grape:       #AF52DE
Pink:        #FF2D55
Platinum:    #8E8E93
```

---

## 🔤 Typography

### Font Family
- **Primary**: SF Pro (System font)
- **Monospace**: SF Mono (for code blocks)

### Type Scale
```
Large Title:  34pt / Bold      (Navigation titles)
Title 1:      28pt / Bold      (Screen headers)
Title 2:      22pt / Bold      (Section headers)
Title 3:      20pt / Semibold  (Card titles)
Headline:     17pt / Semibold  (List item titles)
Body:         17pt / Regular   (Primary content)
Callout:      16pt / Regular   (Secondary content)
Subhead:      15pt / Regular   (Metadata)
Footnote:     13pt / Regular   (Timestamps, captions)
Caption:      12pt / Regular   (Labels)
```

---

## 🎯 Iconography Style

### Characteristics
- **Line weight**: 1.5pt consistent stroke
- **Corner radius**: 2pt for sharp corners, 4pt for rounded
- **Style**: Outlined, not filled (when unselected)
- **Grid**: 24x24px base with 2px padding

### Custom Icons Needed
1. **Home** - Hexagon with inner lines (Fluxer logo style)
2. **Channels** - # symbol with rounded corners
3. **Messages** - Speech bubble with subtle tail
4. **Notifications** - Bell with unique clapper design
5. **Profile** - User silhouette with hexagon badge
6. **Settings** - Gear with 8 teeth, rounded
7. **Search** - Magnifying glass with thicker ring
8. **Compose** - Plus in hexagon (draggable button)
9. **Reply** - Curved arrow pointing left
10. **React** - Heart with unique curve style
11. **Share** - Arrow with curved shaft
12. **More** - Three dots with equal spacing

---

## 🧩 Components

### 1. Message Bubble
```
┌─────────────────────────────────────────┐
│  ┌───┐                                  │
│  │ 👤│  Username            10:42 AM   │
│  └───┘                                  │
│       This is a message with markdown   │
│       support for **bold** and          │
│       `code` formatting.                │
│                                         │
│       ┌─────┐ ┌─────┐                   │
│       │ 👍 2│ │ ❤️ 1│  (Reactions)      │
│       └─────┘ └─────┘                   │
└─────────────────────────────────────────┘
```

**Specs:**
- Corner radius: 12pt (bubble), 18pt (avatar)
- Avatar size: 36x36pt
- Padding: 12pt all sides
- Background: Surface Secondary
- Shadow: None (clean flat design)

### 2. Channel List Item
```
┌─────────────────────────────────────────┐
│  #  general                    🔊 42   │
│     Last message preview...             │
│     ━━━━━━━━━━━━━━━━━━━━━━━━ (unread)  │
└─────────────────────────────────────────┘
```

**States:**
- Unread: Accent color indicator, bold text
- Mention: Red dot badge, @ symbol
- Muted: Grayed out, bell-slash icon
- Active: Subtle background highlight

### 3. Server/Instance Pills
```
┌─────────────────────────────────────────┐
│  ┌────┐ ┌────┐ ┌────┐                  │
│  │ F  │ │+   │ │ ⌄  │  (Server switch)  │
│  └────┘ └────┘ └────┘                  │
└─────────────────────────────────────────┘
```

### 4. Floating Compose Button
- Hexagonal shape (Fluxer brand)
- Draggable to any screen corner
- Spring animation on drag release
- Haptic feedback on snap

### 5. Context Menu (Long-press)
```
┌─────────────────────────────────────────┐
│         ┌───────────────┐               │
│         │ 💬 Reply      │               │
│         │ ❤️ React      │               │
│         │ 📋 Copy       │               │
│         │ 🔖 Pin        │               │
│         │ 🔔 Remind     │               │
│         │ 👤 Profile    │               │
│         │ ⚠️ Report     │               │
│         └───────────────┘               │
└─────────────────────────────────────────┘
```

---

## 🌊 Animations & Interactions

### Micro-interactions

| Action | Animation | Duration | Easing |
|--------|-----------|----------|--------|
| Tab switch | Icon scale + color fade | 200ms | Spring(0.7, 0.8) |
| Pull to refresh | Elastic rotation indicator | Variable | Elastic |
| Message send | Slide up + fade in | 300ms | Ease out |
| New message | Slide from bottom + spring | 400ms | Spring(0.6, 0.9) |
| Like/React | Scale burst + color fill | 250ms | Spring(0.5, 0.7) |
| Long press | Scale down 0.95 | 100ms | Ease in |
| Menu appear | Scale from anchor point | 200ms | Ease out |
| Compose drag | Follow finger + rotation | Real-time | None |
| Snap to corner | Spring settle | 400ms | Spring(0.6, 0.8) |

### Page Transitions
- Push: Slide from right with parallax
- Modal: Scale up from source + backdrop fade
- Pop: Slide to right with fade

---

## 📐 Spacing System

```
4pt   - Tight (icon padding, inline spacing)
8pt   - Default (element gaps)
12pt  - Comfortable (section padding)
16pt  - Standard (screen edges)
20pt  - Relaxed (section breaks)
24pt  - Large (major separators)
32pt  - XL (header spacing)
48pt  - XXL (hero elements)
```

---

## 🎭 Themes

### Available Themes
1. **Default** - Light/Dark auto
2. **OLED** - Pure black dark mode
3. **Low Contrast** - Softer colors, easier on eyes
4. **High Contrast** - Maximum accessibility

### Custom CSS Support
- Allow users to inject custom CSS
- Safe CSS sandbox (no external resources)
- Theme sharing via QR code

---

## 🔊 Sound Design (Optional)

- Send message: Subtle "whoosh"
- Receive: Soft "pop"
- Reaction: Tiny "click"
- Notification: Subtle chime
- All sounds: Toggle off in settings

---

## 📱 Screen Specifications

### Home Screen
```
┌─────────────────────────────────────────┐
│  Fluxer              ⚙️  🔍            │
├─────────────────────────────────────────┤
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐          │
│  │ HQ │ │Dev │ │Art │ │+   │          │
│  └────┘ └────┘ └────┘ └────┘          │
├─────────────────────────────────────────┤
│  📌 Pinned                              │
│  ┌─────────────────────────────────┐    │
│  │ #announcements                 │    │
│  │ Latest: Server maintenance...   │    │
│  └─────────────────────────────────┘    │
├─────────────────────────────────────────┤
│  💬 Recent Conversations                │
│  ┌─────────────────────────────────┐    │
│  │ 👤 Alice        Hey! Did you...│    │
│  │ 👤 Bob Team     Meeting at 3pm │    │
│  └─────────────────────────────────┘    │
├─────────────────────────────────────────┤
│  🔔 Notifications          3 unread    │
│  ┌─────────────────────────────────┐    │
│  │ @Charlie mentioned you in #dev │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Channel Screen
```
┌─────────────────────────────────────────┐
│  ←  Fluxer HQ  #general        👤 👥    │
├─────────────────────────────────────────┤
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│  Today                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│                                         │
│  Alice              9:30 AM            │
│  Good morning everyone! ☀️             │
│                                         │
│  Bob                9:32 AM            │
│  Morning! Ready for the release?       │
│                                 👍 3   │
│                                         │
│  You                9:35 AM            │
│  Almost done with the final testing    │
│                                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │
│  ┌─────────────────────────────────┐    │
│  │  Type a message...        📎 😊 │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

---

## 🚀 Onboarding Flow

### Welcome Screens (4 slides)
1. **Welcome to Fluxer** - App mascot animation
2. **Your Communities** - Server/instance concept
3. **Rich Messaging** - Markdown, reactions, threads
4. **Privacy First** - Self-hosting, encryption

### Login/Register
- Instance selector (with popular suggestions)
- QR code login option
- Biometric auth setup

---

## 🛠 Settings Screen

```
┌─────────────────────────────────────────┐
│  Settings                    ←         │
├─────────────────────────────────────────┤
│  👤 Account                             │
│     @username@instance.com             │
├─────────────────────────────────────────┤
│  🎨 Appearance                          │
│     Theme · Accent · Font Size         │
├─────────────────────────────────────────┤
│  🔔 Notifications                       │
│     Push · Sounds · Mentions           │
├─────────────────────────────────────────┤
│  💬 Messaging                           │
│     Media · Markdown · Threads         │
├─────────────────────────────────────────┤
│  🔒 Privacy & Security                  │
│     Encryption · Sessions · 2FA        │
├─────────────────────────────────────────┤
│  ⚙️ Advanced                            │
│     Instances · CSS · Developer        │
├─────────────────────────────────────────┤
│  ❓ Help & Support                      │
│  ℹ️ About Fluxer                        │
└─────────────────────────────────────────┘
```

---

## 📋 Implementation Notes

### SwiftUI Considerations
- Use `ScrollView` with `LazyVStack` for message lists
- Custom `TabView` with `PageTabViewStyle` for bottom nav
- `matchedGeometryEffect` for smooth transitions
- `Canvas` for custom icon drawing
- `UIViewControllerRepresentable` for complex gestures

### Performance Targets
- 60fps minimum, 120fps on ProMotion devices
- <100ms response to user input
- <2s initial load time
- Smooth scrolling with 1000+ messages

---

*Design system for Fluxer Mobile Client*
