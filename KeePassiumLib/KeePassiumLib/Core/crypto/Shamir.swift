//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation

/// Shamir Secret Sharing over GF(256) for the offline Emergency Access
/// feature (Phase 11c, ADR-016): splits a secret (e.g. a master password)
/// into N printable shares of which any M reconstruct it. Written from
/// scratch — no third-party dependency.
///
/// Security properties:
/// - Fewer than M shares reveal nothing about the secret (information-theoretic).
/// - Shares are bound to a random per-split set ID; combining shares from
///   different splits is rejected.
/// - The encoded secret carries a CRC-32 checksum, so tampered or wrong
///   shares are detected at combine time instead of yielding a silently
///   corrupted secret.
/// - The caller is responsible for erasing the secret and shares from
///   memory after use (see `Eraseable` conventions in this codebase).
public enum Shamir {

    public enum ShamirError: Error, Equatable {
        /// Fewer than the threshold of usable shares was provided.
        case notEnoughShares
        /// Two shares claim the same polynomial index (x) — duplicate.
        case duplicateShareIndex
        /// Shares belong to different split operations (set ID mismatch).
        case setIDMismatch
        /// Reconstructed data failed the CRC-32 check (tampered/wrong shares).
        case checksumMismatch
        /// A share string could not be parsed.
        case invalidShareFormat
        /// Invalid split parameters (threshold/shares out of range).
        case invalidParameters
    }

    /// One share of a split secret.
    public struct Share: Equatable {
        /// Polynomial degree + 1: shares needed to reconstruct.
        public let threshold: Int
        /// Random identifier shared by all shares of one split operation.
        public let setID: Data
        /// Non-zero field element identifying this share (1...255).
        public let x: UInt8
        /// f(x) for every byte of the (checksummed) secret.
        public let y: Data

        public init(threshold: Int, setID: Data, x: UInt8, y: Data) {
            self.threshold = threshold
            self.setID = setID
            self.x = x
            self.y = y
        }
    }

    /// Wire format version of the printable share encoding.
    static let shareFormatVersion: UInt8 = 1
    /// Human-recognizable prefix of a printable share string.
    public static let sharePrefix = "PPSH1-"
    static let setIDLength = 8
    static let checksumLength = 4

    // MARK: - Split / combine

    /// Splits `secret` into `sharesCount` shares, any `threshold` of which
    /// reconstruct the secret. `secret` must be non-empty; 2 <= threshold <=
    /// sharesCount <= 255.
    public static func split(
        secret: Data,
        threshold: Int,
        sharesCount: Int,
        using rng: RandomNumberGenerator
    ) throws -> [Share] {
        guard secret.count > 0 else { throw ShamirError.invalidParameters }
        guard sharesCount >= 2, sharesCount <= 255 else { throw ShamirError.invalidParameters }
        guard threshold >= 2, threshold <= sharesCount else { throw ShamirError.invalidParameters }

        let setID = Data((0..<setIDLength).map { _ in UInt8.random(in: .min ... .max, using: rng) })
        let checksummedSecret = secret + crc32(secret)

        // Distinct non-zero x values for the shares.
        let xs = Array(UInt8(1)...UInt8(255)).shuffled(using: &rng).prefix(sharesCount)

        var ys = [Data](repeating: Data(count: checksummedSecret.count), count: sharesCount)
        for (byteIndex, secretByte) in checksummedSecret.enumerated() {
            // Random polynomial f with f(0) = secretByte, degree threshold-1.
            var coefficients = [secretByte]
            coefficients.reserveCapacity(threshold)
            for _ in 1..<threshold {
                coefficients.append(UInt8.random(in: .min ... .max, using: rng))
            }
            for (shareIndex, x) in xs.enumerated() {
                ys[shareIndex][byteIndex] = evaluatePolynomial(coefficients, at: x)
            }
        }

        return zip(xs, ys).map { Share(threshold: threshold, setID: setID, x: $0, y: $1) }
    }

    /// Convenience overload using the system secure RNG.
    public static func split(secret: Data, threshold: Int, sharesCount: Int) throws -> [Share] {
        var rng = SecureRandomNumberGenerator()
        return try split(secret: secret, threshold: threshold, sharesCount: sharesCount, using: &rng)
    }

    /// Reconstructs the secret from at least `threshold` shares of the same
    /// split. Throws on wrong/tampered shares (checksum mismatch) or mixed
    /// sets. The returned data is the original secret.
    public static func combine(shares: [Share]) throws -> Data {
        guard !shares.isEmpty else { throw ShamirError.notEnoughShares }

        let setID = shares[0].setID
        guard shares.allSatisfy({ $0.setID == setID }) else { throw ShamirError.setIDMismatch }

        let threshold = shares[0].threshold
        guard shares.allSatisfy({ $0.threshold == threshold }) else { throw ShamirError.invalidShareFormat }

        var usableShares = shares
        if usableShares.count > threshold {
            usableShares = Array(usableShares.prefix(threshold))
        }
        guard usableShares.count >= threshold else { throw ShamirError.notEnoughShares }

        // Distinct x values are required for interpolation.
        let xs = usableShares.map { $0.x }
        guard Set(xs).count == xs.count else { throw ShamirError.duplicateShareIndex }

        let secretLength = usableShares[0].y.count
        guard usableShares.allSatisfy({ $0.y.count == secretLength }) else {
            throw ShamirError.invalidShareFormat
        }

        var reconstructed = Data(count: secretLength)
        for byteIndex in 0..<secretLength {
            let points: [(x: UInt8, y: UInt8)] = usableShares.map { ($0.x, $0.y[byteIndex]) }
            reconstructed[byteIndex] = interpolate(points, atZero: true)
        }

        guard secretLength > checksumLength else { throw ShamirError.invalidShareFormat }
        let secret = reconstructed.prefix(secretLength - checksumLength)
        let expectedCRC = reconstructed.suffix(checksumLength)
        guard crc32(secret) == expectedCRC else { throw ShamirError.checksumMismatch }
        return Data(secret)
    }

    // MARK: - Printable encoding

    /// Encodes a share as a printable, copy-pastable string:
    /// `PPSH1-<base32(version|threshold|setID|x|y)>`.
    public static func encodeShare(_ share: Share) -> String {
        var bytes = Data()
        bytes.append(shareFormatVersion)
        bytes.append(UInt8(share.threshold))
        bytes.append(share.setID)
        bytes.append(share.x)
        bytes.append(share.y)
        return sharePrefix + base32Encode(bytes)
    }

    /// Parses a printable share string (see `encodeShare`). Whitespace is
    /// tolerated; the prefix is case-sensitive.
    public static func decodeShare(_ string: String) throws -> Share {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(sharePrefix) else { throw ShamirError.invalidShareFormat }
        guard let bytes = base32DecodeToData(String(trimmed.dropFirst(sharePrefix.count))) else {
            throw ShamirError.invalidShareFormat
        }
        let headerLength = 2 + setIDLength + 1
        guard bytes.count > headerLength else { throw ShamirError.invalidShareFormat }
        guard bytes[0] == shareFormatVersion else { throw ShamirError.invalidShareFormat }
        let threshold = Int(bytes[1])
        guard threshold >= 2 else { throw ShamirError.invalidShareFormat }
        let setID = bytes.subdata(in: 2..<(2 + setIDLength))
        let x = bytes[2 + setIDLength]
        guard x != 0 else { throw ShamirError.invalidShareFormat }
        let y = bytes.subdata(in: (headerLength)..<bytes.count)
        return Share(threshold: threshold, setID: setID, x: x, y: y)
    }

    // MARK: - GF(256) arithmetic (AES polynomial x^8 + x^4 + x^3 + x + 1)

    static func gf256Multiply(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var result: UInt8 = 0
        var accumulator = a
        var multiplier = b
        while multiplier != 0 {
            if multiplier & 1 != 0 {
                result ^= accumulator
            }
            let highBit = accumulator & 0x80
            accumulator <<= 1
            if highBit != 0 {
                accumulator ^= 0x1B // reduction of x^8 in the AES field
            }
            multiplier >>= 1
        }
        return result
    }

    /// Evaluates a polynomial (coefficients[0] is the constant term) at `x`.
    static func evaluatePolynomial(_ coefficients: [UInt8], at x: UInt8) -> UInt8 {
        var result: UInt8 = 0
        var power: UInt8 = 1
        for coefficient in coefficients {
            result ^= gf256Multiply(coefficient, power)
            power = gf256Multiply(power, x)
        }
        return result
    }

    /// Lagrange interpolation at x = 0 over the given points.
    static func interpolate(_ points: [(x: UInt8, y: UInt8)], atZero: Bool) -> UInt8 {
        precondition(atZero) // only x = 0 is needed for reconstruction
        var result: UInt8 = 0
        for (i, point) in points.enumerated() {
            var numerator: UInt8 = 1
            var denominator: UInt8 = 1
            for (j, other) in points.enumerated() where j != i {
                numerator = gf256Multiply(numerator, other.x)             // (0 - x_j) = x_j in GF(2^n)
                denominator = gf256Multiply(denominator, point.x ^ other.x) // (x_i - x_j) = x_i ^ x_j
            }
            // Division in GF(256) via multiplication by the inverse.
            let inverse = gf256Inverse(denominator)
            let lagrangeTerm = gf256Multiply(numerator, inverse)
            result ^= gf256Multiply(point.y, lagrangeTerm)
        }
        return result
    }

    /// Multiplicative inverse in GF(256) via exponentiation (a^254 = a^-1).
    static func gf256Inverse(_ a: UInt8) -> UInt8 {
        precondition(a != 0)
        var result: UInt8 = 1
        var base = a
        var exponent: UInt8 = 254
        while exponent != 0 {
            if exponent & 1 != 0 {
                result = gf256Multiply(result, base)
            }
            base = gf256Multiply(base, base)
            exponent >>= 1
        }
        return result
    }

    // MARK: - CRC-32 (zlib polynomial, for share-set integrity)

    static func crc32(_ data: Data) -> Data {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = (crc & 1) != 0 ? 0xEDB88320 : 0
                crc = (crc >> 1) ^ mask
            }
        }
        let value = ~crc
        return withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
