//
//  FlukavikeIntents.swift
//  App Intents for Siri and Shortcuts integration
//

import AppIntents
import Foundation

// MARK: - Channel Store (shared singleton accessible from intents)

/// Lightweight mirror of gateway guilds that intents can read without needing SwiftUI environment.
class ChannelStore {
    static let shared = ChannelStore()
    private init() {}

    private(set) var entries: [(channel: Channel, serverName: String)] = []

    func update(guilds: [Server], restServers: [Server]) {
        entries = guilds.flatMap { guild -> [(Channel, String)] in
            let name: String
            if let r = restServers.first(where: { $0.id == guild.id }), r.name != "Unknown Server" {
                name = r.name
            } else {
                name = guild.name
            }
            return guild.channels
                .filter { $0.type == .text || $0.type == .announcement }
                .map { ($0, name) }
        }
    }

    func channel(for id: String) -> (channel: Channel, serverName: String)? {
        entries.first { $0.channel.id == id }
    }
}

// MARK: - Channel Entity

struct ChannelEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Channel")
    static var defaultQuery = ChannelEntityQuery()

    var id: String
    var name: String
    var serverName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "#\(name)",
            subtitle: LocalizedStringResource(stringLiteral: serverName)
        )
    }
}

struct ChannelEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ChannelEntity] {
        identifiers.compactMap { id in
            ChannelStore.shared.channel(for: id).map {
                ChannelEntity(id: $0.channel.id, name: $0.channel.name, serverName: $0.serverName)
            }
        }
    }

    func suggestedEntities() async throws -> [ChannelEntity] {
        ChannelStore.shared.entries.map {
            ChannelEntity(id: $0.channel.id, name: $0.channel.name, serverName: $0.serverName)
        }
    }

    func defaultResult() async -> ChannelEntity? {
        try? await suggestedEntities().first
    }
}

// MARK: - Open Channel Intent

struct OpenChannelIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Channel"
    static var description = IntentDescription("Navigate to a channel in Flukavike.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Channel")
    var channel: ChannelEntity

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .init("ViewChannelIntent"),
                object: nil,
                userInfo: ["channelId": channel.id, "serverId": ""]
            )
        }
        return .result()
    }
}

// MARK: - Send Message Intent

struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Message"
    static var description = IntentDescription("Send a message to a channel in Flukavike.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Channel")
    var channel: ChannelEntity

    @Parameter(title: "Message")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$message) to \(\.$channel)")
    }

    func perform() async throws -> some IntentResult {
        // Send via API
        let sent = try? await APIService.shared.sendMessage(channelId: channel.id, content: message)

        await MainActor.run {
            // Navigate to the channel so the user sees what was sent
            NotificationCenter.default.post(
                name: .init("ViewChannelIntent"),
                object: nil,
                userInfo: ["channelId": channel.id, "serverId": ""]
            )
        }

        if sent != nil {
            return .result(dialog: "Message sent to #\(channel.name).")
        } else {
            throw $message.needsValueError("Couldn't send the message. Make sure you're signed in.")
        }
    }
}

// MARK: - App Shortcuts (auto-surfaced in Siri)

struct FlukavikeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenChannelIntent(),
            phrases: [
                "Open \(\.$channel) on \(.applicationName)",
                "Go to \(\.$channel) in \(.applicationName)"
            ],
            shortTitle: "Open Channel",
            systemImageName: "number"
        )
        AppShortcut(
            intent: SendMessageIntent(),
            phrases: [
                "Send a message on \(.applicationName)",
                "Message \(\.$channel) on \(.applicationName)"
            ],
            shortTitle: "Send Message",
            systemImageName: "paperplane.fill"
        )
    }
}
