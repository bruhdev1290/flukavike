//
//  Models.swift
//  Data models for Flukavike
//

import Foundation
import SwiftUI

// MARK: - User
struct User: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let bannerUrl: String?
    let bio: String?
    let status: UserStatus
    let customStatus: String?
    let bot: Bool
    let createdAt: Date
    
    var displayUsername: String { "@\(username)" }
    var formattedName: String { displayName ?? username }
    
    static let preview = User(
        id: "1",
        username: "alice",
        displayName: "Alice Chen",
        avatarUrl: nil,
        bannerUrl: nil,
        bio: "Building things with Swift 🚀",
        status: .online,
        customStatus: "Coding...",
        bot: false,
        createdAt: Date()
    )
}

enum UserStatus: String, Codable, CaseIterable {
    case online = "Online"
    case idle = "Idle"
    case dnd = "Do Not Disturb"
    case offline = "Offline"
    case invisible = "Invisible"
    
    var color: Color {
        switch self {
        case .online: return .green
        case .idle: return .orange
        case .dnd: return .red
        case .offline: return .gray
        case .invisible: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .online: return "circle.fill"
        case .idle: return "moon.fill"
        case .dnd: return "minus.circle.fill"
        case .offline: return "circle"
        case .invisible: return "circle"
        }
    }
}

// MARK: - Server
struct Server: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let iconUrl: String?
    let bannerUrl: String?
    let description: String?
    let memberCount: Int
    let instance: String
    let channels: [Channel]
    
    static let preview = Server(
        id: "1",
        name: "Flukavike HQ",
        iconUrl: nil,
        bannerUrl: nil,
        description: "Official Flukavike community",
        memberCount: 15420,
        instance: "fluxer.app",
        channels: Channel.previewChannels
    )
    
    static let previewServers = [
        preview,
        Server(
            id: "2",
            name: "Swift Devs",
            iconUrl: nil,
            bannerUrl: nil,
            description: "Swift programming community",
            memberCount: 8934,
            instance: "swift.dev",
            channels: []
        ),
        Server(
            id: "3",
            name: "Design",
            iconUrl: nil,
            bannerUrl: nil,
            description: "UI/UX Design discussions",
            memberCount: 3421,
            instance: "design.community",
            channels: []
        )
    ]
}

// MARK: - Channel
struct Channel: Identifiable, Codable, Equatable {
    let id: String
    let serverId: String
    let name: String
    let topic: String?
    let type: ChannelType
    let position: Int
    let parentId: String?
    let unreadCount: Int
    let mentionCount: Int
    let lastMessageAt: Date?
    
    enum ChannelType: String, Codable, CaseIterable {
        case text = "text"
        case voice = "voice"
        case category = "category"
        case announcement = "announcement"
        
        var icon: String {
            switch self {
            case .text: return "number"
            case .voice: return "speaker.wave.2"
            case .category: return ""
            case .announcement: return "megaphone"
            }
        }
    }
    
    var hasUnread: Bool { unreadCount > 0 }
    var hasMention: Bool { mentionCount > 0 }
    
    static let previewChannels = [
        Channel(
            id: "c1",
            serverId: "1",
            name: "announcements",
            topic: "Official announcements from the team",
            type: .announcement,
            position: 0,
            parentId: nil,
            unreadCount: 2,
            mentionCount: 0,
            lastMessageAt: Date()
        ),
        Channel(
            id: "c2",
            serverId: "1",
            name: "general",
            topic: "General discussion about Flukavike",
            type: .text,
            position: 1,
            parentId: nil,
            unreadCount: 0,
            mentionCount: 0,
            lastMessageAt: Date()
        ),
        Channel(
            id: "c3",
            serverId: "1",
            name: "help",
            topic: "Get help with Flukavike",
            type: .text,
            position: 2,
            parentId: nil,
            unreadCount: 5,
            mentionCount: 1,
            lastMessageAt: Date()
        ),
        Channel(
            id: "c4",
            serverId: "1",
            name: "development",
            topic: "Technical discussions",
            type: .text,
            position: 3,
            parentId: nil,
            unreadCount: 12,
            mentionCount: 0,
            lastMessageAt: Date()
        ),
        Channel(
            id: "c5",
            serverId: "1",
            name: "Voice Chat",
            topic: nil,
            type: .voice,
            position: 4,
            parentId: nil,
            unreadCount: 0,
            mentionCount: 0,
            lastMessageAt: nil
        )
    ]
}

// MARK: - Message
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let author: User
    let content: String
    let timestamp: Date
    let editedTimestamp: Date?
    let replyToId: String?
    let reactions: [Reaction]
    let attachments: [Attachment]
    let isPinned: Bool
    
    var isEdited: Bool { editedTimestamp != nil }
    var isReply: Bool { replyToId != nil }
    
    static let previewMessages = [
        Message(
            id: "m1",
            channelId: "c2",
            author: User.preview,
            content: "Hey everyone! 👋 Just wanted to share that the new update is looking great!",
            timestamp: Date().addingTimeInterval(-3600),
            editedTimestamp: nil,
            replyToId: nil,
            reactions: [
                Reaction(emoji: "👍", count: 5, me: true),
                Reaction(emoji: "🎉", count: 3, me: false)
            ],
            attachments: [],
            isPinned: false
        ),
        Message(
            id: "m2",
            channelId: "c2",
            author: User(
                id: "2",
                username: "bob",
                displayName: "Bob Smith",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: nil,
                status: .online,
                customStatus: nil,
                bot: false,
                createdAt: Date()
            ),
            content: "Absolutely! The design is so clean ✨",
            timestamp: Date().addingTimeInterval(-1800),
            editedTimestamp: nil,
            replyToId: nil,
            reactions: [
                Reaction(emoji: "❤️", count: 2, me: true)
            ],
            attachments: [],
            isPinned: false
        ),
        Message(
            id: "m3",
            channelId: "c2",
            author: User(
                id: "3",
                username: "charlie",
                displayName: "Charlie Davis",
                avatarUrl: nil,
                bannerUrl: nil,
                bio: nil,
                status: .idle,
                customStatus: "AFK",
                bot: false,
                createdAt: Date()
            ),
            content: "Can't wait for the TestFlight beta! When is it dropping?",
            timestamp: Date().addingTimeInterval(-900),
            editedTimestamp: nil,
            replyToId: nil,
            reactions: [],
            attachments: [],
            isPinned: false
        )
    ]
}

// MARK: - Reaction
struct Reaction: Codable, Equatable {
    let emoji: String
    let count: Int
    let me: Bool
}

// MARK: - Attachment
struct Attachment: Codable, Equatable {
    let id: String
    let filename: String
    let size: Int
    let url: String
    let proxyUrl: String?
    let width: Int?
    let height: Int?
    let contentType: String?
    let duration: Double?
    let waveform: [UInt8]?
    
    var isImage: Bool {
        contentType?.starts(with: "image/") ?? false
    }
    
    var isAudio: Bool {
        contentType?.starts(with: "audio/") ?? false
    }
    
    var isVoiceMessage: Bool {
        isAudio && duration != nil
    }
}

// MARK: - Notification
struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let read: Bool
    let relatedId: String?
    
    enum NotificationType: String, Codable {
        case mention
        case reply
        case reaction
        case dm
        case serverInvite
        case system
        case incomingCall
        case missedCall
        
        var icon: String {
            switch self {
            case .mention: return "at"
            case .reply: return "arrowshape.turn.up.left"
            case .reaction: return "face.smiling"
            case .dm: return "bubble.left"
            case .serverInvite: return "envelope"
            case .system: return "bell"
            case .incomingCall: return "phone.fill.arrow.up.right"
            case .missedCall: return "phone.fill.arrow.down.left"
            }
        }
        
        var color: Color {
            switch self {
            case .mention: return .red
            case .reply: return .blue
            case .reaction: return .yellow
            case .dm: return .green
            case .serverInvite: return .purple
            case .system: return .gray
            case .incomingCall: return .green
            case .missedCall: return .red
            }
        }
    }
    
    static let previewNotifications = [
        AppNotification(
            id: "n1",
            type: .mention,
            title: "Alice mentioned you",
            message: "@you check out this design!",
            timestamp: Date().addingTimeInterval(-300),
            read: false,
            relatedId: "m1"
        ),
        AppNotification(
            id: "n2",
            type: .reaction,
            title: "Bob reacted to your message",
            message: "👍 on \"Hey everyone!\"",
            timestamp: Date().addingTimeInterval(-600),
            read: false,
            relatedId: "m1"
        ),
        AppNotification(
            id: "n3",
            type: .incomingCall,
            title: "Incoming call",
            message: "Alice is calling you",
            timestamp: Date().addingTimeInterval(-1800),
            read: true,
            relatedId: nil
        )
    ]
}

// MARK: - Voice Channel
struct VoiceChannel: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let guildId: String?
    let name: String
    let participants: [VoiceParticipant]
    let maxParticipants: Int?
    let bitrate: Int
    let region: String
    let isLobby: Bool
    
    struct VoiceParticipant: Identifiable, Codable, Equatable {
        let id: String
        let user: User
        let isMuted: Bool
        let isDeafened: Bool
        let isVideoEnabled: Bool
        let isScreenSharing: Bool
        let joinedAt: Date
        
        var isSpeaking: Bool = false
    }
    
    var participantCount: Int { participants.count }
    var hasVideo: Bool { participants.contains { $0.isVideoEnabled } }
    var hasScreenShare: Bool { participants.contains { $0.isScreenSharing } }
}

// MARK: - Call
struct Call: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let guildId: String?
    let initiator: User
    let participants: [User]
    let type: CallType
    let startedAt: Date
    let endedAt: Date?
    let status: CallStatus
    
    enum CallType: String, Codable {
        case voice
        case video
        case screenShare
    }
    
    enum CallStatus: String, Codable {
        case ringing
        case ongoing
        case ended
        case missed
        case declined
    }
    
    var duration: TimeInterval? {
        guard let endedAt = endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
    
    var isActive: Bool { status == .ongoing }
    var isIncoming: Bool { status == .ringing }
}

// MARK: - Push Notification Payload
struct PushNotificationPayload: Codable {
    let type: String
    let title: String?
    let body: String?
    let data: NotificationData?
    
    struct NotificationData: Codable {
        let channelId: String?
        let guildId: String?
        let messageId: String?
        let senderId: String?
        let callId: String?
    }
}

// MARK: - Screen Share Session
struct ScreenShareSession: Identifiable, Codable, Equatable {
    let id: String
    let channelId: String
    let userId: String
    let startedAt: Date
    let resolution: String
    let frameRate: Int
    
    var isActive: Bool = true
}
