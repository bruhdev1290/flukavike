//
//  StarredChannelsStore.swift
//  Local store for starred/favorite channels.
//

import SwiftUI

@Observable
final class StarredChannelsStore {
    static let shared = StarredChannelsStore()

    private let idsKey = "starred_channel_ids"
    private let namesKey = "starred_server_names"

    private(set) var starredIds: Set<String>
    private var serverNames: [String: String]

    private init() {
        starredIds = Set(UserDefaults.standard.stringArray(forKey: idsKey) ?? [])
        serverNames = (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String]) ?? [:]
    }

    func serverName(for channelId: String) -> String {
        serverNames[channelId] ?? ""
    }

    @discardableResult
    func toggle(channelId: String, serverName: String) -> Bool {
        if starredIds.contains(channelId) {
            starredIds.remove(channelId)
            serverNames.removeValue(forKey: channelId)
        } else {
            starredIds.insert(channelId)
            if !serverName.isEmpty {
                serverNames[channelId] = serverName
            }
        }
        persist()
        return starredIds.contains(channelId)
    }

    @discardableResult
    func toggle(channel: Channel, serverName: String) -> Bool {
        toggle(channelId: channel.id, serverName: serverName)
    }

    func remove(channelId: String) {
        starredIds.remove(channelId)
        serverNames.removeValue(forKey: channelId)
        persist()
    }

    func isStarred(_ channelId: String) -> Bool {
        starredIds.contains(channelId)
    }

    func isStarred(_ channel: Channel) -> Bool {
        isStarred(channel.id)
    }

    func starredChannels(from guilds: [Server], restServers: [Server] = []) -> [(serverName: String, channel: Channel)] {
        var result: [(String, Channel)] = []
        for guild in guilds {
            for channel in guild.channels.sorted(by: { $0.position < $1.position }) where starredIds.contains(channel.id) {
                let restName = restServers.first(where: { $0.id == guild.id })?.name
                let name: String
                if let r = restName, !r.isEmpty, r != "Unknown Server" {
                    name = r
                } else if let stored = serverNames[channel.id], !stored.isEmpty, stored != "Unknown Server" {
                    name = stored
                } else if guild.name != "Unknown Server", !guild.name.isEmpty {
                    name = guild.name
                } else {
                    name = serverNames[channel.id] ?? guild.name
                }
                result.append((name, channel))
            }
        }
        return result
    }

    private func persist() {
        UserDefaults.standard.set(Array(starredIds), forKey: idsKey)
        UserDefaults.standard.set(serverNames, forKey: namesKey)
    }
}
