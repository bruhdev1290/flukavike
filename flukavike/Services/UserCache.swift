//
//  UserCache.swift
//  Lightweight in-memory cache for resolving user names/avatars by ID.
//

import Foundation

actor UserCache {
    static let shared = UserCache()
    private init() {}

    private var users: [String: User] = [:]

    func user(withId id: String) async -> User? {
        if let user = users[id] { return user }
        do {
            let user = try await APIService.shared.getUser(id: id)
            users[id] = user
            return user
        } catch {
            print("[UserCache] Failed to fetch user \(id): \(error)")
            return nil
        }
    }

    func cache(_ user: User) {
        users[user.id] = user
    }

    func cache(_ usersToCache: [User]) {
        for user in usersToCache {
            users[user.id] = user
        }
    }
}
