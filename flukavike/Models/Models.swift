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

    // Memberwise initialiser (used by previews and internal construction).
    init(
        id: String,
        username: String,
        displayName: String?,
        avatarUrl: String?,
        bannerUrl: String?,
        bio: String?,
        status: UserStatus,
        customStatus: String?,
        bot: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bannerUrl = bannerUrl
        self.bio = bio
        self.status = status
        self.customStatus = customStatus
        self.bot = bot
        self.createdAt = createdAt
    }

    // CodingKeys covers both the Fluxer API shape and internal/legacy shapes.
    private enum CodingKeys: String, CodingKey {
        case id, username, bot, bio, status
        // Fluxer API field names (convertFromSnakeCase turns them into camelCase)
        case globalName     // JSON: "global_name"
        case avatar         // JSON: "avatar"  (hash, not URL)
        case banner         // JSON: "banner"  (hash, not URL)
        case customStatus   // JSON: "custom_status"
        case createdAt      // JSON: "created_at"
        // Fallback keys for instances that already return camelCase or full URLs
        case displayName
        case avatarUrl
        case bannerUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id       = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        bot      = (try c.decodeIfPresent(Bool.self, forKey: .bot)) ?? false

        // Fluxer uses "global_name"; fall back to "displayName" for other servers.
        displayName = try c.decodeIfPresent(String.self, forKey: .globalName)
            ?? c.decodeIfPresent(String.self, forKey: .displayName)

        // Fluxer returns "avatar" as a hash; other servers may use "avatarUrl".
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatar)
            ?? c.decodeIfPresent(String.self, forKey: .avatarUrl)

        bannerUrl = try c.decodeIfPresent(String.self, forKey: .banner)
            ?? c.decodeIfPresent(String.self, forKey: .bannerUrl)

        bio         = try c.decodeIfPresent(String.self, forKey: .bio)
        customStatus = try c.decodeIfPresent(String.self, forKey: .customStatus)

        // status and createdAt are not part of the Fluxer user REST response;
        // default to sensible values so decoding never fails.
        status    = (try c.decodeIfPresent(UserStatus.self, forKey: .status)) ?? .offline
        createdAt = (try c.decodeIfPresent(Date.self,       forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(username, forKey: .username)
        try c.encode(bot,      forKey: .bot)
        try c.encodeIfPresent(displayName,  forKey: .displayName)
        try c.encodeIfPresent(avatarUrl,    forKey: .avatarUrl)
        try c.encodeIfPresent(bannerUrl,    forKey: .bannerUrl)
        try c.encodeIfPresent(bio,          forKey: .bio)
        try c.encode(status,               forKey: .status)
        try c.encodeIfPresent(customStatus, forKey: .customStatus)
        try c.encode(createdAt,            forKey: .createdAt)
    }

    static let preview = User(
        id: "1",
        username: "alice",
        displayName: "Alice Chen",
        avatarUrl: nil,
        bannerUrl: nil,
        bio: "Building things with Swift",
        status: .online,
        customStatus: "Coding...",
        bot: false,
        createdAt: Date()
    )
}

enum UserStatus: String, Codable, CaseIterable {
    case online = "online"
    case idle = "idle"
    case dnd = "dnd"
    case offline = "offline"
    case invisible = "invisible"
    
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
    
    var accessibilityLabel: String {
        switch self {
        case .online: return "Online"
        case .idle: return "Idle"
        case .dnd: return "Do not disturb"
        case .offline: return "Offline"
        case .invisible: return "Invisible"
        }
    }
}

// MARK: - Server
struct Server: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let iconUrl: String?
    let bannerUrl: String?
    let description: String?
    let memberCount: Int
    let instance: String
    let channels: [Channel]

    private enum CodingKeys: String, CodingKey {
        case id, name, description, channels, instance
        case iconUrl
        case icon
        case bannerUrl
        case banner
        case memberCount
        case member_count
    }

    init(
        id: String,
        name: String,
        iconUrl: String?,
        bannerUrl: String?,
        description: String?,
        memberCount: Int,
        instance: String,
        channels: [Channel]
    ) {
        self.id = id
        self.name = name
        self.iconUrl = iconUrl
        self.bannerUrl = bannerUrl
        self.description = description
        self.memberCount = memberCount
        self.instance = instance
        self.channels = channels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown Server"
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
            ?? container.decodeIfPresent(String.self, forKey: .icon)
        bannerUrl = try container.decodeIfPresent(String.self, forKey: .bannerUrl)
            ?? container.decodeIfPresent(String.self, forKey: .banner)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount)
            ?? container.decodeIfPresent(Int.self, forKey: .member_count)
            ?? 0
        instance = try container.decodeIfPresent(String.self, forKey: .instance) ?? "web.fluxer.app"
        channels = try container.decodeIfPresent([Channel].self, forKey: .channels) ?? []
    }
    
    static let preview = Server(
        id: "1",
        name: "Flukavike HQ",
        iconUrl: nil,
        bannerUrl: nil,
        description: "Official Flukavike community",
        memberCount: 15420,
        instance: "fluxer.app",
        channels: [
            Channel(id: "c1", serverId: "1", name: "announcements", topic: "Official announcements", type: .announcement, position: 0, parentId: nil, unreadCount: 2, mentionCount: 0, lastMessageAt: Date()),
            Channel(id: "c2", serverId: "1", name: "general", topic: "General chat", type: .text, position: 1, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date()),
            Channel(id: "c3", serverId: "1", name: "help", topic: "Get help", type: .text, position: 2, parentId: nil, unreadCount: 5, mentionCount: 1, lastMessageAt: Date()),
            Channel(id: "c4", serverId: "1", name: "random", topic: "Random stuff", type: .text, position: 3, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date())
        ]
    )
    
    static let previewServers = [
        preview,
        Server(
            id: "2",
            name: "Fluxer Developers",
            iconUrl: nil,
            bannerUrl: nil,
            description: "Developer community",
            memberCount: 8934,
            instance: "fluxer.dev",
            channels: [
                Channel(id: "c5", serverId: "2", name: "general", topic: "Dev general", type: .text, position: 0, parentId: nil, unreadCount: 3, mentionCount: 0, lastMessageAt: Date()),
                Channel(id: "c6", serverId: "2", name: "swift", topic: "Swift programming", type: .text, position: 1, parentId: nil, unreadCount: 8, mentionCount: 2, lastMessageAt: Date()),
                Channel(id: "c7", serverId: "2", name: "api", topic: "API discussions", type: .text, position: 2, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date()),
                Channel(id: "c8", serverId: "2", name: "voice", topic: nil, type: .voice, position: 3, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: nil)
            ]
        ),
        Server(
            id: "3",
            name: "Design",
            iconUrl: nil,
            bannerUrl: nil,
            description: "UI/UX Design discussions",
            memberCount: 3421,
            instance: "design.community",
            channels: [
                Channel(id: "c9", serverId: "3", name: "inspiration", topic: "Design inspiration", type: .text, position: 0, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date()),
                Channel(id: "c10", serverId: "3", name: "critique", topic: "Get feedback", type: .text, position: 1, parentId: nil, unreadCount: 4, mentionCount: 0, lastMessageAt: Date()),
                Channel(id: "c11", serverId: "3", name: "resources", topic: "Design resources", type: .text, position: 2, parentId: nil, unreadCount: 0, mentionCount: 0, lastMessageAt: Date()),
                Channel(id: "c12", serverId: "3", name: "showcase", topic: "Show your work", type: .text, position: 3, parentId: nil, unreadCount: 12, mentionCount: 0, lastMessageAt: Date())
            ]
        )
    ]
}

// MARK: - Channel
struct Channel: Identifiable, Decodable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case id, name, topic, type, position
        case serverId
        case guildId
        case guild_id
        case parentId
        case parent_id
        case unreadCount
        case unread_count
        case mentionCount
        case mention_count
        case lastMessageAt
        case last_message_at
        case createdAt
        case created_at
    }

    init(
        id: String,
        serverId: String,
        name: String,
        topic: String?,
        type: ChannelType,
        position: Int,
        parentId: String?,
        unreadCount: Int,
        mentionCount: Int,
        lastMessageAt: Date?
    ) {
        self.id = id
        self.serverId = serverId
        self.name = name
        self.topic = topic
        self.type = type
        self.position = position
        self.parentId = parentId
        self.unreadCount = unreadCount
        self.mentionCount = mentionCount
        self.lastMessageAt = lastMessageAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
            ?? container.decodeIfPresent(String.self, forKey: .guildId)
            ?? container.decodeIfPresent(String.self, forKey: .guild_id)
            ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unknown"
        topic = try container.decodeIfPresent(String.self, forKey: .topic)

        // Handle type - try string first, then int, then default to text
        if let typeString = try? container.decode(String.self, forKey: .type),
           let parsedType = ChannelType(rawValue: typeString) {
            type = parsedType
        } else if let typeInt = try? container.decode(Int.self, forKey: .type) {
            switch typeInt {
            case 2:
                type = .voice
            case 4:
                type = .category
            case 5:
                type = .announcement
            default:
                type = .text
            }
        } else {
            type = .text
        }

        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
            ?? container.decodeIfPresent(String.self, forKey: .parent_id)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
            ?? container.decodeIfPresent(Int.self, forKey: .unread_count)
            ?? 0
        mentionCount = try container.decodeIfPresent(Int.self, forKey: .mentionCount)
            ?? container.decodeIfPresent(Int.self, forKey: .mention_count)
            ?? 0
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
            ?? container.decodeIfPresent(Date.self, forKey: .last_message_at)
            ?? container.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? container.decodeIfPresent(Date.self, forKey: .created_at)
    }
    
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

// MARK: - DM / Relationship API responses

struct DMChannelResponse: Identifiable, Decodable {
    let id: String
    let type: Int
    let recipients: [User]
    let lastMessageId: String?
}

/// type: 1=friend, 2=blocked, 3=incoming request, 4=outgoing request
struct RelationshipResponse: Identifiable, Decodable {
    let id: String
    let type: Int
    let user: User
    var isFriend: Bool { type == 1 }
}

struct GuildMemberResponse: Decodable {
    let user: User?
    let nick: String?

    var displayName: String {
        nick ?? user?.formattedName ?? "Unknown"
    }
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

    private enum CodingKeys: String, CodingKey {
        case id, author, content, timestamp, reactions, attachments
        case channelId          // JSON: "channel_id"
        case editedTimestamp    // JSON: "edited_timestamp"
        case isPinned           // app-internal
        case pinned             // JSON: "pinned" (Fluxer)
        case replyToId          // app-internal
        case messageReference   // JSON: "message_reference" (Fluxer)
    }

    init(
        id: String, channelId: String, author: User, content: String,
        timestamp: Date, editedTimestamp: Date?, replyToId: String?,
        reactions: [Reaction], attachments: [Attachment], isPinned: Bool
    ) {
        self.id = id; self.channelId = channelId; self.author = author
        self.content = content; self.timestamp = timestamp
        self.editedTimestamp = editedTimestamp; self.replyToId = replyToId
        self.reactions = reactions; self.attachments = attachments
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        channelId = try c.decodeIfPresent(String.self, forKey: .channelId) ?? ""
        author    = try c.decode(User.self, forKey: .author)
        content   = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        editedTimestamp = try c.decodeIfPresent(Date.self, forKey: .editedTimestamp)
        reactions   = try c.decodeIfPresent([Reaction].self,    forKey: .reactions)   ?? []
        attachments = try c.decodeIfPresent([Attachment].self,  forKey: .attachments) ?? []
        isPinned    = try c.decodeIfPresent(Bool.self, forKey: .pinned)
            ?? c.decodeIfPresent(Bool.self, forKey: .isPinned)
            ?? false
        // ⚠️ WARNING — DO NOT change MessageReference back to [String: String].
        // Fluxer's message_reference object includes a "type" field with an integer value.
        // Decoding as [String: String] throws a typeMismatch and breaks the entire message
        // array decode, causing "Failed to load message history" on any channel that has replies.
        if let refData = try? c.decodeIfPresent(MessageReference.self, forKey: .messageReference) {
            replyToId = refData.messageId
        } else {
            replyToId = try? c.decodeIfPresent(String.self, forKey: .replyToId)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(channelId, forKey: .channelId)
        try c.encode(author, forKey: .author)
        try c.encode(content, forKey: .content)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(editedTimestamp, forKey: .editedTimestamp)
        try c.encodeIfPresent(replyToId, forKey: .replyToId)
        try c.encode(reactions, forKey: .reactions)
        try c.encode(attachments, forKey: .attachments)
        try c.encode(isPinned, forKey: .isPinned)
    }
    
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

// ⚠️ WARNING — DO NOT change these structs to [String: String] or remove them.
// Fluxer returns mixed-type objects for both message references and emoji that cannot
// be decoded as [String: String]. Reverting either struct will break message history
// loading for any channel containing replies or reactions. See README for details.
private struct MessageReference: Decodable {
    // message_reference also contains "type" (Int) and "channel_id" (String) — only message_id is needed.
    let messageId: String?
}

private struct EmojiObject: Decodable {
    // emoji object contains "id" (Int or null) and "animated" (Bool) alongside "name" (String).
    let name: String?
}

// MARK: - Reaction
struct Reaction: Codable, Equatable {
    let emoji: String
    let count: Int
    let me: Bool

    private enum CodingKeys: String, CodingKey {
        case emoji, count, me
    }

    // The Fluxer API returns emoji as an object: {name, id, animated}.
    // We flatten that to a plain string (the Unicode char or name).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // ⚠️ WARNING — DO NOT use [String: String] here or remove the try?.
        // Fluxer emoji objects contain "id" (Int) and "animated" (Bool) — not all strings.
        // If decoding throws instead of returning nil, a single reaction breaks the entire
        // message array decode, causing "Failed to load message history" for that channel.
        if let emojiObj = try? c.decodeIfPresent(EmojiObject.self, forKey: .emoji),
           let name = emojiObj.name {
            emoji = name
        } else {
            emoji = (try? c.decodeIfPresent(String.self, forKey: .emoji)) ?? "?"
        }

        count = (try c.decodeIfPresent(Int.self, forKey: .count)) ?? 0
        me    = (try c.decodeIfPresent(Bool.self, forKey: .me))    ?? false
    }

    // Convenience for previews / internal construction.
    init(emoji: String, count: Int, me: Bool) {
        self.emoji = emoji
        self.count = count
        self.me    = me
    }
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
    let serverId: String?
    let serverName: String?
    
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
            relatedId: "m1",
            serverId: "1",
            serverName: "Flukavike HQ"
        ),
        AppNotification(
            id: "n2",
            type: .reaction,
            title: "Bob reacted to your message",
            message: "👍 on \"Hey everyone!\"",
            timestamp: Date().addingTimeInterval(-600),
            read: false,
            relatedId: "m1",
            serverId: "2",
            serverName: "Fluxer Developers"
        ),
        AppNotification(
            id: "n3",
            type: .incomingCall,
            title: "Incoming call",
            message: "Alice is calling you",
            timestamp: Date().addingTimeInterval(-1800),
            read: true,
            relatedId: nil,
            serverId: nil,
            serverName: nil
        ),
        AppNotification(
            id: "n4",
            type: .mention,
            title: "Charlie mentioned you",
            message: "@you what do you think about this?",
            timestamp: Date().addingTimeInterval(-900),
            read: false,
            relatedId: "m2",
            serverId: "2",
            serverName: "Fluxer Developers"
        ),
        AppNotification(
            id: "n5",
            type: .reply,
            title: "Elias replied to you",
            message: "That's a great idea!",
            timestamp: Date().addingTimeInterval(-1200),
            read: true,
            relatedId: "m3",
            serverId: "1",
            serverName: "Flukavike HQ"
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
