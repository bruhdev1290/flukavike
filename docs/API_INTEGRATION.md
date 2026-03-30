# Fluxer API Integration Guide

This guide explains how to use the Fluxer API for calls, voice channels, and real-time features.

---

## 🏗 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Fluxer Mobile App                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  API Service │  │  WebSocket   │  │ Call Service │      │
│  │  (REST)      │  │  (Gateway)   │  │ (CallKit)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Fluxer Platform                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  HTTP API    │  │   Gateway    │  │ Voice SFU    │      │
│  │  api.fluxer  │  │  WebSocket   │  │  WebRTC      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📡 Services

### APIService

Handles all REST API calls to Fluxer:

```swift
// Get singleton
let api = APIService.shared

// Set auth token (after login)
api.setAuthToken("your_bearer_token")

// Make API calls
do {
    let user = try await api.getCurrentUser()
    let guilds = try await api.getUserGuilds()
} catch {
    print("API Error: \(error)")
}
```

### WebSocketService

Manages real-time connection to Fluxer Gateway:

```swift
// Get singleton
let ws = WebSocketService.shared

// Connect with auth token
ws.connect(token: "your_token")

// Set up event handlers
ws.onMessageCreate = { message in
    // Handle new message
}

ws.onCallCreate = { call in
    // Handle incoming call
}
```

### FluxerCallService

Manages calls using CallKit + Fluxer API:

```swift
// Get singleton
let callService = FluxerCallService.shared

// Configure with API and WebSocket
callService.configure(
    apiService: apiService,
    webSocketService: webSocketService
)

// Start a call
try await callService.startCall(
    channelId: "channel_id",
    type: .voice  // or .video
)

// Answer incoming call
try await callService.answerCall()

// End call
try await callService.endCall()
```

---

## 📞 Call Flow

### Incoming Call

```
1. Push Notification (APNs)
   ↓
2. PushNotificationService.handleIncomingCall()
   ↓
3. FluxerCallService.reportIncomingCall() → CallKit
   ↓
4. User answers → CallKit callback
   ↓
5. API: POST /calls/{id}/accept
   ↓
6. API: GET /channels/{id}/voice-token
   ↓
7. Connect to Fluxer Voice Gateway (WebRTC)
   ↓
8. Call connected!
```

### Outgoing Call

```
1. User initiates call
   ↓
2. API: POST /channels/{id}/calls
   ↓
3. CallKit: Start outgoing call UI
   ↓
4. API: GET /channels/{id}/voice-token
   ↓
5. Connect to Fluxer Voice Gateway
   ↓
6. Remote user answers
   ↓
7. Call connected!
```

---

## 🔊 Voice Channels

### Join Voice Channel

```swift
let callService = FluxerCallService.shared

// Join voice channel
try await callService.joinVoiceChannel("channel_id")

// Now you're in the voice channel
// - Other participants can see you
// - You can hear others
// - You can enable video/mute
```

### Voice Controls

```swift
// Mute/unmute
try await callService.toggleMute()

// Deafen/undeafen
callService.toggleDeafen()

// Enable/disable video (DM calls only)
try await callService.toggleVideo()

// Leave channel
await callService.leaveVoiceChannel()
```

### Screen Sharing

```swift
// Start screen share
try await callService.startScreenSharing()
// Shows system broadcast picker

// Stop screen share
try await callService.stopScreenSharing()
```

---

## 🌐 WebSocket Events

### Message Events

```swift
webSocketService.onMessageCreate = { message in
    // New message received
    // Update UI, play sound
}

webSocketService.onMessageUpdate = { message in
    // Message edited
}

webSocketService.onMessageDelete = { messageId in
    // Message deleted
}
```

### Typing Events

```swift
webSocketService.onTypingStart = { event in
    // User started typing
    // Show "Alice is typing..."
}
```

### Call Events

```swift
webSocketService.onCallCreate = { call in
    // Incoming call
    // Show call UI
}

webSocketService.onCallUpdate = { call in
    // Call state changed
}

webSocketService.onCallDelete = { callId in
    // Call ended
}
```

### Voice Events

```swift
webSocketService.onVoiceStateUpdate = { voiceState in
    // User joined/left/muted in voice channel
}

webSocketService.onSpeaking = { userId, speaking in
    // Update speaking indicator
}
```

---

## 📡 API Endpoints Used

### Authentication
- `POST /auth/login` - Get bearer token
- `POST /users/@me/devices` - Register push token

### Users
- `GET /users/@me` - Current user
- `GET /users/@me/guilds` - User's servers

### Channels
- `GET /channels/{id}` - Channel info
- `GET /channels/{id}/messages` - Messages
- `POST /channels/{id}/messages` - Send message
- `GET /channels/{id}/voice-token` - Get voice token

### Calls
- `POST /channels/{id}/calls` - Create call
- `POST /calls/{id}/accept` - Accept call
- `DELETE /calls/{id}` - End call
- `PATCH /calls/{id}/state` - Update call state
- `POST /calls/{id}/screen-share` - Start screen share
- `DELETE /calls/{id}/screen-share` - Stop screen share

---

## 🔐 Authentication

### Login Flow

```swift
// 1. Login via API
let response = try await apiService.login(
    instance: "fluxer.app",
    username: "user",
    password: "pass"
)

// 2. Store token
apiService.setAuthToken(response.token)

// 3. Connect WebSocket
webSocketService.connect(token: response.token)

// 4. Register for push notifications
let deviceToken = ... // From APNs
await apiService.registerDeviceToken(token: deviceToken)
```

### Token Refresh

The API service automatically handles 401 errors. Your app should:

1. Detect 401 response
2. Refresh token via `POST /auth/refresh`
3. Retry the failed request

---

## 🧪 Testing

### Test Calls (Simulator)

Simulator can't do real calls, but you can test UI:

```swift
// Simulate incoming call
let mockCall = FluxerCall(
    id: "123",
    channelId: "456",
    guildId: nil,
    initiator: User.preview,
    participants: [],
    type: .voice,
    status: .ringing,
    startedAt: Date(),
    endedAt: nil
)

FluxerCallService.shared.activeCall = mockCall
```

### Test Voice Channel (Device)

1. Build to physical device
2. Join voice channel
3. Test with another user on web/desktop

### Screen Share Testing

1. Start call
2. Tap screen share button
3. Select "FluxerBroadcastExtension"
4. Tap "Start Broadcast"
5. Other participants see your screen

---

## 📋 Implementation Checklist

### Phase 1: Basic Connection
- [x] APIService setup
- [x] WebSocketService setup
- [x] Authentication flow
- [ ] Error handling & retry
- [ ] Token refresh

### Phase 2: Messaging
- [x] Send/receive messages
- [x] Typing indicators
- [x] Read receipts
- [x] File uploads (including voice messages)
- [ ] Message reactions

### Phase 3: Calls
- [x] CallKit integration
- [x] Incoming calls
- [x] Outgoing calls
- [ ] Voice connection (WebRTC)
- [ ] Video support
- [ ] Screen sharing

### Phase 4: Voice Channels
- [x] Join/leave channels
- [x] Participant list
- [x] Mute/deafen
- [x] Speaking indicators
- [ ] Video in voice channels
- [ ] Screen share in voice channels

---

## 🚀 Next Steps

1. **Add WebRTC Framework**
   - Google WebRTC or Amazon Kinesis
   - Implement in VoiceConnection class

2. **Handle Reconnection**
   - Network drops
   - App background/foreground
   - WebSocket reconnect

3. **Optimize Performance**
   - Lazy loading messages
   - Image caching
   - Voice codec selection

4. **Add Tests**
   - Unit tests for services
   - UI tests for call flow
   - Network mocking

---

*For Fluxer Mobile Client*
