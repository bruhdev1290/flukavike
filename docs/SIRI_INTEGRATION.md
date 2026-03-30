# Siri Integration for Fluxer

Siri integration allows users to perform actions hands-free using voice commands. This guide explains how to implement SiriKit for Fluxer.

---

## 🎯 Supported Siri Commands

### Messaging
```
"Send a message to Alice in Fluxer saying Hello!"
"Read my unread messages in Fluxer"
"Reply to the last message with Sounds good!"
"Check my Fluxer notifications"
```

### Voice Channels & Calls
```
"Join the voice channel in Swift Devs"
"Start a voice call with Bob in Fluxer"
"Start a video call with the team channel"
"Leave the voice channel"
"Mute my microphone in Fluxer"
```

### Status & Presence
```
"Set my status to Do Not Disturb in Fluxer"
"What servers am I in on Fluxer?"
"Switch to the Swift Devs server"
```

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Says Command                      │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Siri (System)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Speech     │  │   Natural    │  │   Intent     │  │
│  │  Recognition │──│  Language    │──│  Resolution  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              Fluxer Intent Extension                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │              IntentHandler.swift                 │   │
│  │  • Handle INSendMessageIntent                    │   │
│  │  • Handle INStartCallIntent                      │   │
│  │  • Handle Custom Intents (JoinVoiceChannel)      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                 Fluxer Main App                         │
│         (Handle UI updates when in foreground)          │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Steps

### 1. Enable Siri Capability

In Xcode:
1. Select your project → Signing & Capabilities
2. Click **+ Capability**
3. Add **Siri**

### 2. Add Intent Definition File

Create `FluxerIntents.intentdefinition`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Built-in Messaging Intent -->
    <key>INSendMessageIntent</key>
    <dict>
        <key>IntentClassName</key>
        <string>INSendMessageIntent</string>
    </dict>
    
    <!-- Built-in Call Intent -->
    <key>INStartCallIntent</key>
    <dict>
        <key>IntentClassName</key>
        <string>INStartCallIntent</string>
    </dict>
    
    <!-- Custom Intent: Join Voice Channel -->
    <key>JoinVoiceChannelIntent</key>
    <dict>
        <key>IntentClassName</key>
        <string>JoinVoiceChannelIntent</string>
        <key>IntentDescription</key>
        <string>Join a voice channel in a server</string>
        <key>Parameters</key>
        <array>
            <dict>
                <key>Name</key>
                <string>server</string>
                <key>Type</key>
                <string>String</string>
                <key>Configurable</key>
                <true/>
            </dict>
            <dict>
                <key>Name</key>
                <string>channel</string>
                <key>Type</key>
                <string>String</string>
                <key>Configurable</key>
                <true/>
            </dict>
        </array>
    </dict>
    
    <!-- Custom Intent: Set Status -->
    <key>SetStatusIntent</key>
    <dict>
        <key>IntentClassName</key>
        <string>SetStatusIntent</string>
        <key>IntentDescription</key>
        <string>Set your online status</string>
        <key>Parameters</key>
        <array>
            <dict>
                <key>Name</key>
                <string>status</string>
                <key>Type</key>
                <string>String</string>
                <key>EnumValues</key>
                <array>
                    <string>online</string>
                    <string>away</string>
                    <string>dnd</string>
                    <string>invisible</string>
                </array>
            </dict>
        </array>
    </dict>
</dict>
</plist>
```

### 3. Create Intent Extension

**File: `FluxerIntentExtension/IntentHandler.swift`**

```swift
import Intents

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        if intent is INSendMessageIntent {
            return SendMessageIntentHandler()
        } else if intent is INStartCallIntent {
            return StartCallIntentHandler()
        } else if intent is JoinVoiceChannelIntent {
            return JoinVoiceChannelIntentHandler()
        } else if intent is SetStatusIntent {
            return SetStatusIntentHandler()
        }
        return self
    }
}

// MARK: - Send Message Handler
class SendMessageIntentHandler: NSObject, INSendMessageIntentHandling {
    
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        guard let recipients = intent.recipients else {
            completion([.needsValue()])
            return
        }
        
        // Resolve recipient names to actual users
        let results = recipients.map { recipient -> INSendMessageRecipientResolutionResult in
            // Look up user in contacts/Fluxer
            if let user = findUser(matching: recipient.displayName) {
                let person = INPerson(
                    personHandle: INPersonHandle(value: user.id, type: .unknown),
                    nameComponents: nil,
                    displayName: user.displayName ?? user.username,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: user.id
                )
                return .success(with: person)
            }
            return .unsupported()
        }
        
        completion(results)
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let content = intent.content, !content.isEmpty else {
            completion(.needsValue())
            return
        }
        completion(.success(with: content))
    }
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated
        guard AuthService.shared.isAuthenticated else {
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        completion(INSendMessageIntentResponse(code: .ready, userActivity: nil))
    }
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        guard let recipient = intent.recipients?.first,
              let content = intent.content else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Send message via API
        Task {
            do {
                // Find DM channel with recipient or create one
                let channelId = try await findOrCreateDMChannel(with: recipient.customIdentifier!)
                let _ = try await APIService.shared.sendMessage(
                    channelId: channelId,
                    content: content
                )
                
                let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
                completion(response)
            } catch {
                let response = INSendMessageIntentResponse(code: .failure, userActivity: nil)
                completion(response)
            }
        }
    }
    
    private func findUser(matching name: String) -> User? {
        // Search cached users
        // This would use your local cache of known users
        return nil
    }
    
    private func findOrCreateDMChannel(with userId: String) async throws -> String {
        // Find existing DM or create new one
        // POST /users/@me/channels
        return ""
    }
}

// MARK: - Start Call Handler
class StartCallIntentHandler: NSObject, INStartCallIntentHandling {
    
    func resolveContacts(for intent: INStartCallIntent, with completion: @escaping ([INStartCallContactResolutionResult]) -> Void) {
        // Resolve contacts for call
        completion([.notRequired()])
    }
    
    func resolveCallCapability(for intent: INStartCallIntent, with completion: @escaping (INStartCallCapabilityResolutionResult) -> Void) {
        completion(.success(with: .audioCall))
    }
    
    func confirm(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        guard AuthService.shared.isAuthenticated else {
            completion(INStartCallIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        completion(INStartCallIntentResponse(code: .ready, userActivity: nil))
    }
    
    func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        // Start voice/video call
        // This would open the app and initiate the call
        let userActivity = NSUserActivity(activityType: "com.fluxer.startCall")
        userActivity.userInfo = ["callType": intent.callCapability == .videoCall ? "video" : "voice"]
        
        let response = INStartCallIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}

// MARK: - Join Voice Channel Handler
class JoinVoiceChannelIntentHandler: NSObject, JoinVoiceChannelIntentHandling {
    
    func resolveServer(for intent: JoinVoiceChannelIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let server = intent.server, !server.isEmpty else {
            completion(.needsValue())
            return
        }
        completion(.success(with: server))
    }
    
    func resolveChannel(for intent: JoinVoiceChannelIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let channel = intent.channel, !channel.isEmpty else {
            completion(.needsValue())
            return
        }
        completion(.success(with: channel))
    }
    
    func handle(intent: JoinVoiceChannelIntent, completion: @escaping (JoinVoiceChannelIntentResponse) -> Void) {
        Task {
            do {
                // Find server and channel
                guard let server = findServer(named: intent.server!),
                      let channel = findVoiceChannel(named: intent.channel!, in: server) else {
                    completion(JoinVoiceChannelIntentResponse(code: .failure, userActivity: nil))
                    return
                }
                
                // Join voice channel
                try await FluxerCallService.shared.joinVoiceChannel(channel.id)
                
                completion(JoinVoiceChannelIntentResponse(code: .success, userActivity: nil))
            } catch {
                completion(JoinVoiceChannelIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
    
    private func findServer(named name: String) -> Server? {
        // Search cached servers
        return nil
    }
    
    private func findVoiceChannel(named name: String, in server: Server) -> Channel? {
        return server.channels.first { 
            $0.type == .voice && $0.name.lowercased().contains(name.lowercased())
        }
    }
}

// MARK: - Set Status Handler
class SetStatusIntentHandler: NSObject, SetStatusIntentHandling {
    
    func resolveStatus(for intent: SetStatusIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let status = intent.status, !status.isEmpty else {
            completion(.needsValue())
            return
        }
        
        let validStatuses = ["online", "away", "dnd", "invisible"]
        if validStatuses.contains(status.lowercased()) {
            completion(.success(with: status))
        } else {
            completion(.unsupported())
        }
    }
    
    func handle(intent: SetStatusIntent, completion: @escaping (SetStatusIntentResponse) -> Void) {
        guard let statusString = intent.status?.lowercased(),
              let status = UserStatus.fromSiriValue(statusString) else {
            completion(SetStatusIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Update presence via WebSocket
        WebSocketService.shared.updatePresence(status: status, customStatus: nil)
        
        completion(SetStatusIntentResponse(code: .success, userActivity: nil))
    }
}

// MARK: - UserStatus Extension
extension UserStatus {
    static func fromSiriValue(_ value: String) -> UserStatus? {
        switch value {
        case "online": return .online
        case "away": return .idle
        case "dnd": return .dnd
        case "invisible": return .invisible
        default: return nil
        }
    }
}
```

### 4. Handle Intents in Main App

**File: `FluxerApp.swift`** (add to App struct)

```swift
// MARK: - Intent Handling
extension FluxerApp {
    func application(_ application: UIApplication, 
                     continue userActivity: NSUserActivity, 
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        switch userActivity.activityType {
        case "com.fluxer.startCall":
            if let callType = userActivity.userInfo?["callType"] as? String {
                handleStartCallIntent(type: callType)
            }
            return true
            
        case NSUserActivityTypeBrowsingWeb:
            // Handle Universal Links
            return true
            
        default:
            return false
        }
    }
    
    private func handleStartCallIntent(type: String) {
        // Navigate to call UI and start call
        // This would require coordinating with your navigation state
    }
}
```

### 5. Donate Intents

**File: `FluxerMockup/Services/SiriDonationService.swift`**

```swift
import Intents

class SiriDonationService {
    static let shared = SiriDonationService()
    
    // Donate when user sends a message
    func donateSendMessage(to recipient: User, content: String) {
        let intent = INSendMessageIntent(
            recipients: [INPerson(
                personHandle: INPersonHandle(value: recipient.id, type: .unknown),
                nameComponents: nil,
                displayName: recipient.displayName ?? recipient.username,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: recipient.id
            )],
            content: nil, // Don't include actual content for privacy
            speakableGroupName: nil,
            conversationIdentifier: recipient.id,
            serviceName: "Fluxer",
            sender: nil,
            attachments: nil
        )
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate intent: \(error)")
            }
        }
    }
    
    // Donate when user joins a voice channel
    func donateJoinVoiceChannel(server: Server, channel: Channel) {
        let intent = JoinVoiceChannelIntent()
        intent.server = server.name
        intent.channel = channel.name
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate intent: \(error)")
            }
        }
    }
    
    // Donate when user starts a call
    func donateStartCall(with recipient: User, isVideo: Bool) {
        let intent = INStartCallIntent(
            callCapability: isVideo ? .videoCall : .audioCall,
            contact: INPerson(
                personHandle: INPersonHandle(value: recipient.id, type: .unknown),
                nameComponents: nil,
                displayName: recipient.displayName ?? recipient.username,
                image: nil,
                contactIdentifier: nil,
                customIdentifier: recipient.id
            )
        )
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("Failed to donate intent: \(error)")
            }
        }
    }
}
```

### 6. Add Siri Shortcuts Support

**File: `FluxerMockup/Services/ShortcutsService.swift`**

```swift
import AppIntents

// MARK: - Send Message Shortcut
struct SendMessageShortcut: AppIntent {
    static var title: LocalizedStringResource = "Send Fluxer Message"
    static var description = IntentDescription("Send a message to a contact")
    
    @Parameter(title: "Recipient", description: "Who to send the message to")
    var recipient: String
    
    @Parameter(title: "Message", description: "The message content")
    var message: String
    
    func perform() async throws -> some IntentResult {
        // Send message via API
        guard let user = findUser(matching: recipient) else {
            throw IntentError.userNotFound
        }
        
        let channelId = try await findOrCreateDMChannel(with: user.id)
        let _ = try await APIService.shared.sendMessage(
            channelId: channelId,
            content: message
        )
        
        return .result(dialog: "Message sent to \(user.displayName ?? user.username)")
    }
}

// MARK: - Join Voice Channel Shortcut
struct JoinVoiceChannelShortcut: AppIntent {
    static var title: LocalizedStringResource = "Join Voice Channel"
    static var description = IntentDescription("Join a voice channel in a server")
    
    @Parameter(title: "Server", description: "The server name")
    var server: String
    
    @Parameter(title: "Channel", description: "The voice channel name")
    var channel: String
    
    func perform() async throws -> some IntentResult {
        guard let serverObj = findServer(named: server),
              let channelObj = findVoiceChannel(named: channel, in: serverObj) else {
            throw IntentError.channelNotFound
        }
        
        try await FluxerCallService.shared.joinVoiceChannel(channelObj.id)
        
        return .result(dialog: "Joined \(channel) in \(server)")
    }
}

// MARK: - Set Status Shortcut
struct SetStatusShortcut: AppIntent {
    static var title: LocalizedStringResource = "Set Fluxer Status"
    static var description = IntentDescription("Set your online status")
    
    @Parameter(title: "Status", description: "Your new status")
    var status: StatusParameter
    
    enum StatusParameter: String, AppEnum {
        case online
        case away
        case dnd
        case invisible
        
        static var typeDisplayRepresentation: TypeDisplayRepresentation {
            "Status"
        }
        
        static var caseDisplayRepresentations: [StatusParameter: DisplayRepresentation] {
            [
                .online: "Online",
                .away: "Away",
                .dnd: "Do Not Disturb",
                .invisible: "Invisible"
            ]
        }
    }
    
    func perform() async throws -> some IntentResult {
        let userStatus: UserStatus = {
            switch status {
            case .online: return .online
            case .away: return .idle
            case .dnd: return .dnd
            case .invisible: return .invisible
            }
        }()
        
        WebSocketService.shared.updatePresence(status: userStatus, customStatus: nil)
        
        return .result(dialog: "Status set to \(status.rawValue)")
    }
}

// MARK: - Shortcuts Provider
struct FluxerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: SendMessageShortcut(),
                phrases: [
                    "Send a message in \(.applicationName)",
                    "Message \($recipient) on \(.applicationName) saying \($message)"
                ],
                shortTitle: "Send Message",
                systemImageName: "bubble.left.fill"
            ),
            AppShortcut(
                intent: JoinVoiceChannelShortcut(),
                phrases: [
                    "Join voice channel in \(.applicationName)",
                    "Join \($channel) in \($server) on \(.applicationName)"
                ],
                shortTitle: "Join Voice",
                systemImageName: "mic.fill"
            ),
            AppShortcut(
                intent: SetStatusShortcut(),
                phrases: [
                    "Set my \(.applicationName) status to \($status)",
                    "Go \($status) on \(.applicationName)"
                ],
                shortTitle: "Set Status",
                systemImageName: "person.fill"
            )
        ]
    }
}

enum IntentError: Error {
    case userNotFound
    case channelNotFound
}
```

---

## 📱 Info.plist Updates

Add to your main app's `Info.plist`:

```xml
<key>NSUserActivityTypes</key>
<array>
    <string>INSendMessageIntent</string>
    <string>INStartCallIntent</string>
    <string>com.fluxer.startCall</string>
    <string>com.fluxer.joinVoiceChannel</string>
</array>

<key>NSSiriUsageDescription</key>
<string>Fluxer uses Siri to let you send messages, start calls, and join voice channels hands-free.</string>
```

---

## 🔄 Testing Siri Integration

### Simulator Testing
1. Enable Siri in Simulator: **Device → Siri**
2. Hold Option key and click the Siri button
3. Type or speak your command

### Device Testing
1. Build and run on physical device
2. Go to **Settings → Siri & Search → Fluxer**
3. Enable all supported intents
4. Test with: "Hey Siri, send a message to Alice in Fluxer"

---

## 🚀 Next Steps

1. **Implement Intent Extension** as shown above
2. **Add vocabulary** for server names, channel names, and usernames
3. **Donate intents** after user actions so Siri learns patterns
4. **Add suggested shortcuts** in your app's settings
5. **Test extensively** with different phrasings

---

## 📚 Resources

- [SiriKit Documentation](https://developer.apple.com/documentation/sirikit)
- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [WWDC 2022: Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)
