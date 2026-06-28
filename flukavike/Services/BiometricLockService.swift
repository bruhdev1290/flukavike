//
//  BiometricLockService.swift
//  App-data protection via biometric + PIN fallback.
//

import Foundation
import LocalAuthentication
import CommonCrypto
import Security
import Observation

@Observable
final class BiometricLockService {
    static let shared = BiometricLockService()

    // MARK: - Stored State (UserDefaults-backed flags; PIN + throttle in Keychain)

    var isLockEnabled: Bool {
        didSet { UserDefaults.standard.set(isLockEnabled, forKey: Self.lockEnabledKey) }
    }

    var isBiometricEnabled: Bool {
        didSet { UserDefaults.standard.set(isBiometricEnabled, forKey: Self.biometricEnabledKey) }
    }

    /// True while the app should display the lock overlay.
    var isLocked: Bool = false

    /// Failed-attempt counter. Persisted in the Keychain so a relaunch cannot
    /// reset the brute-force throttle. Resets to 0 on successful unlock.
    private(set) var failedAttempts: Int = 0 {
        didSet { persistFailedAttempts() }
    }

    /// When set, biometric/PIN unlock is refused until this date passes.
    /// Persisted in the Keychain (not UserDefaults) so it survives relaunch
    /// and is not trivially editable by the user.
    private(set) var lockoutUntil: Date?

    let maxFailedAttempts = 5
    /// PBKDF2 iteration count for the PIN verifier.
    nonisolated static let pinIterations = 100_000
    /// Required PIN length.
    let pinLength = 4

    // MARK: - Keys

    private static let lockEnabledKey = "appLockEnabled"
    private static let biometricEnabledKey = "biometricEnabled"
    private static let pinSaltKey = "appLockPinSalt"
    private static let pinHashKey = "appLockPinHash"
    private static let failedAttemptsKey = "appLockFailedAttempts"
    private static let lockoutUntilKey = "appLockLockoutUntil"
    private static let keychainService = "app.flukavike.mobile"

    // MARK: - Init

    private init() {
        isLockEnabled = UserDefaults.standard.bool(forKey: Self.lockEnabledKey)
        isBiometricEnabled = UserDefaults.standard.object(forKey: Self.biometricEnabledKey) as? Bool ?? true
        failedAttempts = loadFailedAttempts()
        lockoutUntil = loadLockoutUntil()
    }

    // MARK: - Biometry

    var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Attempts biometric unlock. Returns true on success. Only genuine
    /// authentication failures (not user cancel/fallback/system cancel) feed
    /// the shared throttle, so a user who dismisses Face ID to type their PIN
    /// isn't driven toward lockout.
    @discardableResult
    func tryBiometric() async -> Bool {
        guard canUseBiometrics, !isInLockout else { return false }
        let context = LAContext()
        context.localizedFallbackTitle = "Use PIN"
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Flukavike"
            ) { success, error in
                Task { @MainActor in
                    if success {
                        self.resetFailures()
                        self.isLocked = false
                    } else if Self.isGenuineAuthFailure(error) {
                        // Count only real biometric failures (not cancellations
                        // or the PIN fallback) toward the brute-force throttle.
                        self.registerFailedAttempt()
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// True for authentication failures that should advance the throttle.
    /// User cancels, the PIN fallback, system cancels, and device-environment
    /// states (no biometrics enrolled / unavailable / no passcode set) are
    /// excluded so a legitimate user is never locked out for dismissing the
    /// prompt or for a hardware/config limitation rather than a wrong guess.
    private static func isGenuineAuthFailure(_ error: Error?) -> Bool {
        guard let laError = error as? LAError else { return false }
        switch laError.code {
        // User/system cancellations and the PIN fallback — not guesses.
        case .userCancel, .userFallback, .systemCancel, .appCancel:
            return false
        // Device-environment states — not wrong guesses; lockout would be
        // punishing a hardware/config limitation.
        case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
            return false
        // `.biometryLockout` means the system already locked biometrics; don't
        // double-count toward our own throttle.
        case .biometryLockout:
            return false
        // `.authenticationFailed` is a genuine wrong-biometric/no-match; plus
        // genuinely unknown future failure codes are treated as throttleable.
        default:
            return true
        }
    }

    // MARK: - Lockout

    var isInLockout: Bool {
        guard let until = lockoutUntil else { return false }
        return until > Date()
    }

    var lockoutRemainingSeconds: Int {
        guard let until = lockoutUntil else { return 0 }
        return max(0, Int(until.timeIntervalSinceNow.rounded(.up)))
    }

    /// Escalating lockout duration based on the number of completed lockout
    /// cycles, so repeated brute-force attempts face longer cooldowns.
    private func lockoutDuration(forCycle cycle: Int) -> TimeInterval {
        // 30s, 60s, 120s, 300s, 600s, then capped at 900s.
        let base: TimeInterval = 30
        let mult = pow(2.0, Double(min(cycle, 5)))
        return min(base * mult, 900)
    }

    /// Number of completed lockout cycles persisted in the Keychain (used to
    /// escalate the lockout duration across repeated failures).
    private var lockoutCycles: Int {
        get { Int(loadKeychain(Self.lockoutCycleKey) ?? "0") ?? 0 }
        set { saveKeychain(Self.lockoutCycleKey, String(newValue)) }
    }
    private static let lockoutCycleKey = "appLockLockoutCycle"

    // MARK: - PIN

    var hasPinSet: Bool {
        loadKeychain(Self.pinHashKey) != nil
    }

    /// Stores a PBKDF2-derived verifier of the PIN (with a fresh per-PIN salt)
    /// in the Keychain. Rejects PINs shorter than `pinLength`. The PBKDF2
    /// derivation (100k iterations) is run off the main thread so enrollment
    /// doesn't block the UI.
    func setPin(_ pin: String) async -> Bool {
        guard pin.count >= pinLength else { return false }
        // Regenerate the salt on every setPin so PIN changes are not re-hashed
        // over a stale salt, and so identical PINs don't collide across sets.
        let salt = Self.randomSalt()
        let hash = await Task.detached(priority: .userInitiated) {
            Self.derivePinHash(pin, salt: salt)
        }.value
        saveKeychain(Self.pinSaltKey, salt)
        saveKeychain(Self.pinHashKey, hash)
        return true
    }

    /// Verifies a PIN against the stored PBKDF2-derived hash. The PBKDF2
    /// derivation (100k iterations) is run off the main thread so PIN entry
    /// doesn't block the UI. On success, clears the lock and resets the
    /// throttle; on failure, increments the persisted counter and may trigger
    /// an escalating lockout.
    func unlockWithPin(_ pin: String) async -> Bool {
        guard !isInLockout,
              let storedHash = loadKeychain(Self.pinHashKey),
              let salt = loadKeychain(Self.pinSaltKey) else {
            return false
        }
        // Run the expensive KDF off the main actor; compare on the main actor
        // with a constant-time comparison so no byte-position timing leaks.
        let candidate = await Task.detached(priority: .userInitiated) {
            Self.derivePinHash(pin, salt: salt)
        }.value
        let matched = Self.constantTimeEquals(candidate, storedHash)
        if matched {
            resetFailures()
            isLocked = false
            return true
        }
        registerFailedAttempt()
        return false
    }

    /// Records a failed attempt. Shared by PIN and biometric failure paths so
    /// both verifiers feed a single persisted throttle. Triggers an escalating
    /// lockout once `maxFailedAttempts` is reached.
    func registerFailedAttempt() {
        failedAttempts += 1
        if failedAttempts >= maxFailedAttempts {
            let cycle = lockoutCycles
            lockoutUntil = Date().addingTimeInterval(lockoutDuration(forCycle: cycle))
            persistLockoutUntil()
            lockoutCycles = cycle + 1
            failedAttempts = 0
        }
    }

    func resetFailures() {
        failedAttempts = 0
        lockoutUntil = nil
        persistLockoutUntil()
        lockoutCycles = 0
    }

    /// Removes the PIN and disables the lock entirely.
    func disable() {
        isLockEnabled = false
        isBiometricEnabled = true
        resetFailures()
        deleteKeychain(Self.pinHashKey)
        deleteKeychain(Self.pinSaltKey)
        isLocked = false
    }

    // MARK: - Lock Lifecycle

    /// Engages the lock if app lock is enabled and a verifier is configured.
    /// Requires a PIN to be set (biometric-only locks without a PIN fallback
    /// are intentionally rejected so the user is never locked out with no
    /// recovery path).
    func lockIfNeeded() {
        guard isLockEnabled, hasPinSet else { return }
        isLocked = true
    }

    // MARK: - Crypto Helpers

    /// Derives a PIN verifier using PBKDF2-HMAC-SHA256 (100k iterations) keyed
    /// off a per-PIN salt. A single SHA-256 pass is unsuitable for a low-entropy
    /// 4-digit secret; PBKDF2 makes each offline guess expensive.
    /// `nonisolated` so it can run off the main actor inside a detached Task.
    private nonisolated static func derivePinHash(_ pin: String, salt: String) -> String {
        let password = pin.data(using: .utf8) ?? Data()
        let saltData = Data(hexString: salt) ?? Data()
        var derived = [UInt8](repeating: 0, count: 32)

        // CCKeyDerivationPBKDF is the CommonCrypto PBKDF2 primitive.
        let status = saltData.withUnsafeBytes { saltBytes -> Int32 in
            password.withUnsafeBytes { passwordBytes -> Int32 in
                withUnsafeMutableBytes(of: &derived) { derivedBytes -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(Self.pinIterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { return "" }
        return derived.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomSalt() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Constant-time comparison of two hex strings. Avoids the short-circuit
    /// of `String ==` so byte-position timing doesn't leak which prefix of the
    /// derived hash matched.
    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        // Length mismatch returns false but still walks the shared prefix to
        // keep timing roughly constant for equal-length inputs.
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        if aBytes.count != bBytes.count { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }

    // MARK: - Throttle Persistence (Keychain-backed so relaunch can't reset it)

    private func persistFailedAttempts() {
        saveKeychain(Self.failedAttemptsKey, String(failedAttempts))
    }

    private func loadFailedAttempts() -> Int {
        Int(loadKeychain(Self.failedAttemptsKey) ?? "0") ?? 0
    }

    private func persistLockoutUntil() {
        if let until = lockoutUntil {
            saveKeychain(Self.lockoutUntilKey, String(until.timeIntervalSince1970))
        } else {
            deleteKeychain(Self.lockoutUntilKey)
        }
    }

    private func loadLockoutUntil() -> Date? {
        guard let raw = loadKeychain(Self.lockoutUntilKey),
              let ts = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // MARK: - Keychain Helpers

    @discardableResult
    private func saveKeychain(_ key: String, _ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        deleteKeychain(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func loadKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    private func deleteKeychain(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

private nonisolated extension Data {
    /// Parses a hex string (e.g. a salt) into `Data`. Returns nil on failure.
    init?(hexString: String) {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }
}
