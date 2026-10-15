//
//  AltchaSolver.swift
//  Native ALTCHA v2 proof-of-work solver (PBKDF2/SHA-256)
//

import CommonCrypto
import Foundation

/// Solves the ALTCHA v2 challenges that the Fluxer API returns in
/// `CAPTCHA_REQUIRED` / `INVALID_CAPTCHA` errors. No web view or widget needed.
enum AltchaSolver {
    enum SolverError: Error {
        case malformedChallenge
        case unsupportedAlgorithm(String)
        case timedOut
    }

    /// Solves `challenge` (the raw `altcha_challenge` object) and returns the
    /// value for the `X-Captcha-Token` header.
    static func solveToken(challenge: [String: Any], timeout: TimeInterval = 90) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try solveSync(challenge: challenge, timeout: timeout)
        }.value
    }

    private static func solveSync(challenge: [String: Any], timeout: TimeInterval) throws -> String {
        guard let parameters = challenge["parameters"] as? [String: Any],
              challenge["signature"] is String,
              let algorithm = parameters["algorithm"] as? String,
              let nonceHex = parameters["nonce"] as? String,
              let saltHex = parameters["salt"] as? String,
              let cost = (parameters["cost"] as? NSNumber)?.intValue, cost > 0,
              let keyPrefix = (parameters["keyPrefix"] as? String)?.lowercased(),
              !keyPrefix.isEmpty,
              let nonce = Data(hexString: nonceHex),
              let salt = Data(hexString: saltHex)
        else { throw SolverError.malformedChallenge }

        let prfs: [String: CCPseudoRandomAlgorithm] = [
            "PBKDF2/SHA-256": CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            "PBKDF2/SHA-384": CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA384),
            "PBKDF2/SHA-512": CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
        ]
        guard let prf = prfs[algorithm] else { throw SolverError.unsupportedAlgorithm(algorithm) }

        let keyLength = (parameters["keyLength"] as? NSNumber)?.intValue ?? 32
        let deadline = Date().addingTimeInterval(timeout)
        let start = Date()

        var password = [UInt8](nonce) + [0, 0, 0, 0]
        let counterOffset = nonce.count
        var derived = [UInt8](repeating: 0, count: keyLength)
        var counter: UInt32 = 0

        while true {
            password[counterOffset] = UInt8(truncatingIfNeeded: counter >> 24)
            password[counterOffset + 1] = UInt8(truncatingIfNeeded: counter >> 16)
            password[counterOffset + 2] = UInt8(truncatingIfNeeded: counter >> 8)
            password[counterOffset + 3] = UInt8(truncatingIfNeeded: counter)

            let status = password.withUnsafeBufferPointer { pw in
                salt.withUnsafeBytes { sl in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        UnsafeRawPointer(pw.baseAddress!).assumingMemoryBound(to: Int8.self),
                        pw.count,
                        sl.bindMemory(to: UInt8.self).baseAddress!,
                        salt.count,
                        prf,
                        UInt32(cost),
                        &derived,
                        keyLength
                    )
                }
            }
            guard status == kCCSuccess else { throw SolverError.malformedChallenge }

            let hex = derived.map { String(format: "%02x", $0) }.joined()
            if hex.hasPrefix(keyPrefix) {
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                let payload: [String: Any] = [
                    "challenge": challenge,
                    "solution": [
                        "counter": Int(counter),
                        "derivedKey": hex,
                        "time": elapsed
                    ]
                ]
                let json = try JSONSerialization.data(withJSONObject: payload)
                return json.base64EncodedString()
            }

            if counter == UInt32.max || (counter % 16 == 0 && (Task.isCancelled || Date() > deadline)) {
                throw SolverError.timedOut
            }
            counter += 1
        }
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        var data = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
