//
//  KeychainTokenStore.swift
//  Secure token storage using Keychain
//

import Foundation
import Security

enum KeychainTokenStore {
    private static let service = "app.fluxer.mobile"
    private static let tokenKey = "auth_token"
    private static let refreshTokenKey = "refresh_token"
    
    // MARK: - Auth Token
    
    static func saveToken(_ token: String) -> Bool {
        save(token, key: tokenKey)
    }
    
    static func getToken() -> String? {
        load(key: tokenKey)
    }
    
    static func deleteToken() -> Bool {
        delete(key: tokenKey)
    }
    
    // MARK: - Refresh Token
    
    static func saveRefreshToken(_ token: String) -> Bool {
        save(token, key: refreshTokenKey)
    }
    
    static func getRefreshToken() -> String? {
        load(key: refreshTokenKey)
    }
    
    static func deleteRefreshToken() -> Bool {
        delete(key: refreshTokenKey)
    }
    
    // MARK: - Helpers
    
    @discardableResult
    private static func save(_ value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item first
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
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
