//
//  AuthSessionStore.swift
//  Secure Keychain-backed session storage
//

import Foundation
import Security

/// Stores the active `WebSession` in the iOS Keychain.
/// Designed to be extended later for multi-account support.
enum AuthSessionStore {
    private static let service = "app.flukavike.mobile"
    private static let sessionKey = "web_session"

    // MARK: - Save / Load

    @discardableResult
    static func saveSession(_ session: WebSession) -> Bool {
        guard let data = try? JSONEncoder.flukavike.encode(session) else {
            return false
        }
        return save(data, key: sessionKey)
    }

    static func loadSession() -> WebSession? {
        guard let data = load(key: sessionKey) else { return nil }
        return try? JSONDecoder.flukavike.decode(WebSession.self, from: data)
    }

    @discardableResult
    static func deleteSession() -> Bool {
        delete(key: sessionKey)
    }

    // MARK: - Legacy Migration

    /// Reads any session still stored in UserDefaults and moves it to Keychain.
    static func migrateFromUserDefaultsIfNeeded() -> WebSession? {
        guard let data = UserDefaults.standard.data(forKey: "web_auth_session"),
              let session = try? JSONDecoder.flukavike.decode(WebSession.self, from: data) else {
            return nil
        }
        _ = saveSession(session)
        UserDefaults.standard.removeObject(forKey: "web_auth_session")
        return session
    }

    // MARK: - Keychain Helpers

    @discardableResult
    private static func save(_ data: Data, key: String) -> Bool {
        _ = delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return data
    }

    @discardableResult
    private static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
