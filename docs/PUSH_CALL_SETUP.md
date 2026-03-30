# Push Notifications & Calls Setup Guide

This guide covers setting up push notifications, voice/video calls, and screen sharing for Fluxer Mobile.

---

## 📱 Push Notifications (APNs)

### 1. Apple Developer Setup

1. **Create App ID**
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Certificates, Identifiers & Profiles → Identifiers
   - Create new App ID with Push Notifications capability

2. **Create Push Notification Certificate**
   - Certificates → Push Notification service SSL
   - Select your App ID
   - Download and install certificate
   - Export .p12 file for server

3. **Enable Capability in Xcode**
   ```
   Project Settings → Target → Signing & Capabilities
   → + Capability → Push Notifications
   ```

### 2. Code Integration

The app already includes `PushNotificationService.swift` which handles:

- Requesting notification permissions
- Registering device tokens
- Handling incoming notifications
- Call notification routing

### 3. Notification Types

The app supports these notification types:

| Type | Description | Action |
|------|-------------|--------|
| `INCOMING_CALL` | Someone is calling | Show CallKit UI |
| `CALL_ENDED` | Call was ended | Dismiss call UI |
| `MESSAGE_MENTION` | You were mentioned | Open channel |
| `DIRECT_MESSAGE` | New DM received | Open DM |

### 4. Testing Push Notifications

Use the Push Notification Console in Xcode:
```
Window → Devices and Simulators → Simulators
→ Select device → Send Push Notification
```

Or use command line:
```bash
xcrun simctl push booted com.fluxer.app payload.json
```

Sample payload.json:
```json
{
  "aps": {
    "alert": {
      "title": "Incoming Call",
      "body": "Alice is calling you"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "INCOMING_CALL",
  "call": {
    "id": "123456",
    "channel_id": "789",
    "caller": {
      "id": "999",
      "username": "alice",
      "global_name": "Alice"
    },
    "type": "voice"
  }
}
```

---

## 📞 Voice & Video Calls (CallKit)

### 1. Enable CallKit Capability

```
Project Settings → Target → Signing & Capabilities
→ + Capability → Background Modes
→ Check: Voice over IP, Background fetch, Remote notifications
```

### 2. CallKit Configuration

The `CallManager.swift` handles:

- Incoming call UI
- Outgoing call UI
- Mute/unmute
- Video toggle
- Screen sharing
- Call duration tracking

### 3. WebRTC Integration (Required for Real Calls)

Add WebRTC framework:

**Option A: CocoaPods**
```ruby
pod 'GoogleWebRTC'
```

**Option B: Swift Package Manager**
```
https://github.com/stasel/WebRTC.git
```

### 4. Call Flow

```
Incoming Call:
1. Push notification received (type: INCOMING_CALL)
2. CallManager.reportIncomingCall()
3. CallKit shows system call UI
4. User answers → WebRTC connection established
5. Audio/video streams flow

Outgoing Call:
1. User initiates call
2. CallManager.startCall()
3. CallKit shows outgoing call UI
4. WebRTC connection to remote peer
5. Call connected
```

---

## 🖥 Screen Sharing

### 1. Create Broadcast Upload Extension

```
File → New → Target → Broadcast Upload Extension
Name: FluxerBroadcastExtension
```

### 2. Extension Files

Already created in `FluxerBroadcastExtension/`:

- `SampleHandler.swift` - Processes screen frames
- `Info.plist` - Extension configuration

### 3. Setup Screen Share Button

The `CallView.swift` includes a screen share button that:

1. Shows system broadcast picker
2. User selects extension
3. Extension captures screen frames
4. Sends to SFU via WebSocket

### 4. App Groups (Required)

Enable App Groups for communication between app and extension:

```
Capabilities → App Groups
→ Add: group.com.fluxer.app
```

Update both main app and extension targets.

---

## 🔊 Voice Channels

### VoiceChannelView

The `VoiceChannelView.swift` provides:

- Grid of participants (2x2, 3x3, etc.)
- Speaking indicators (green ring)
- Video thumbnails
- Screen share indicators
- Mute/deafen/video controls

### Joining a Voice Channel

```swift
// From ChannelListView or ChatView
VoiceChannelView(channel: voiceChannel)
```

### WebSocket Events

Connect to voice gateway:
```
wss://gateway.fluxer.app/?v=1&encoding=json
```

Voice events:
- `VOICE_STATE_UPDATE` - User joined/left/muted
- `SPEAKING` - User started/stopped speaking
- `VIDEO_ENABLED` - Video stream started
- `SCREEN_SHARE` - Screen share started

---

## 🧪 Testing

### Test Calls

1. **Simulator**: Limited (no audio/video)
2. **Device**: Full functionality

### Test Screen Share

1. Start a call
2. Tap screen share button
3. Select "FluxerBroadcastExtension"
4. Tap "Start Broadcast"

### Debug Logs

Enable verbose logging:
```swift
// In CallManager.swift
RTCSetMinDebugLogLevel(.info)
```

---

## 📋 Required Entitlements

Your app needs these entitlements:

```xml
<key>aps-environment</key>
<string>development</string>

<key>com.apple.developer.push-to-talk</key>
<true/>

<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.fluxer.app</string>
</array>
```

---

## 🔒 Privacy Descriptions

Add to `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Fluxer needs microphone access for voice calls and voice messages.</string>

<key>NSCameraUsageDescription</key>
<string>Fluxer needs camera access for video calls.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Fluxer uses local network to find the best connection for calls.</string>
```

---

## 🚀 Next Steps

To complete integration:

1. **Add WebRTC Framework** - Real audio/video handling
2. **Setup SFU Connection** - Connect to Fluxer media server
3. **ICE Servers** - Configure STUN/TURN servers
4. **Signaling** - Implement WebSocket signaling
5. **Testing** - Test on physical devices

---

*For Fluxer Mobile Client*
