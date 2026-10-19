//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import CryptoKit
import Foundation

/// Pure logic for the Have I Been Pwned (HIBP) k-anonymity password check.
///
/// Privacy contract (must never be violated by callers):
/// - Only the first `hashPrefixLength` hex characters of the SHA-1 hash of a
///   password are ever sent over the network (k-anonymity, HIBP API v3).
/// - The full password and its full hash never leave the device; the remaining
///   hash suffix is matched locally.
/// - The endpoint is HTTPS-only: `https://api.pwnedpasswords.com/range/{prefix}`.
public enum PasswordBreachCheck {
    /// HIBP API v3 range endpoint uses a 5-character SHA-1 hex prefix.
    public static let defaultHashPrefixLength = 5

    /// Uppercase hex SHA-1 hash of the password (40 chars). Local-only.
    public static func sha1HexHash(of password: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    /// The k-anonymity prefix that may be safely sent to the HIBP range API.
    public static func hashPrefix(
        of password: String,
        prefixLength: Int = defaultHashPrefixLength
    ) -> String {
        return String(sha1HexHash(of: password).prefix(prefixLength))
    }

    /// A single line of the HIBP range response: the hash suffix (the part
    /// after the sent prefix) and the number of times it appeared in breaches.
    public struct RangeResult: Equatable {
        /// Uppercase hex hash suffix, `40 - prefixLength` characters.
        public let hashSuffix: String
        public let count: Int

        public init(hashSuffix: String, count: Int) {
            self.hashSuffix = hashSuffix
            self.count = count
        }
    }

    /// Parses the plain-text HIBP range response
    /// (`"<suffix>:<count>\n..."`), validating each line. Invalid lines are
    /// skipped; duplicate suffixes are deduplicated.
    public static func parseRangeResponse(
        _ text: String,
        prefixLength: Int = defaultHashPrefixLength
    ) -> [RangeResult] {
        let expectedSuffixLength = 40 - prefixLength
        var seenSuffixes = Set<String>()
        var results = [RangeResult]()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let suffix = String(parts[0]).uppercased()
            guard suffix.count == expectedSuffixLength,
                  suffix.allSatisfy({ $0.isHexDigit }),
                  let count = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                  count >= 0
            else { continue }

            guard seenSuffixes.insert(suffix).inserted else { continue }
            results.append(RangeResult(hashSuffix: suffix, count: count))
        }
        return results
    }

    /// Returns the breach count for the password, given the parsed range
    /// response for its prefix. `nil` = not found in the response (no known
    /// breach); a returned value is the number of breach occurrences.
    public static func breachCount(
        of password: String,
        in rangeResults: [RangeResult],
        prefixLength: Int = defaultHashPrefixLength
    ) -> Int? {
        let fullHash = sha1HexHash(of: password)
        let prefix = String(fullHash.prefix(prefixLength))
        let suffix = String(fullHash.dropFirst(prefixLength))
        guard prefix.count == prefixLength else { return nil }
        return rangeResults
            .first(where: { $0.hashSuffix == suffix })?
            .count
    }
}
