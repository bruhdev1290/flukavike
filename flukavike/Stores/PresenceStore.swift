//
//  PresenceStore.swift
//  Global live presence store updated from Gateway PRESENCE_UPDATE events.
//

import SwiftUI
import Observation

struct UserPresence: Equatable {
    let status: UserStatus
    let customStatus: String?
    let lastUpdated: Date
}

@Observable
final class PresenceStore {
    static let shared = PresenceStore()

    private(set) var presences: [String: UserPresence] = [:]

    private init() {}

    func presence(for userId: String) -> UserPresence? {
        presences[userId]
    }

    func status(for userId: String) -> UserStatus {
        presences[userId]?.status ?? .offline
    }

    func update(userId: String, status: UserStatus, customStatus: String?) {
        presences[userId] = UserPresence(
            status: status,
            customStatus: customStatus,
            lastUpdated: Date()
        )
    }

    func update(from presenceUpdate: PresenceUpdate) {
        guard let status = UserStatus(rawValue: presenceUpdate.status) else { return }
        update(
            userId: presenceUpdate.user.id,
            status: status,
            customStatus: presenceUpdate.customStatus
        )
    }

    func apply(presences updates: [PresenceUpdate]) {
        for update in updates {
            self.update(from: update)
        }
    }
}
