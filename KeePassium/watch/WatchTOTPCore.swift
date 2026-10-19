//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import CryptoKit
import Foundation

/// TOTP parameters as sent to the watch: base32 seed + RFC 6238 settings.
public struct WatchTOTPParams: Codable, Equatable {
    public var base32Seed: String
    public var period: Int
    public var digits: Int
    /// "SHA1" | "SHA256" | "SHA512" (matches `TOTPHashAlgorithm.asString`).
    public var algorithm: String

    public init(base32Seed: String, period: Int, digits: Int, algorithm: String) {
        self.base32Seed = base32Seed
        self.period = period
        self.digits = digits
        self.algorithm = algorithm
    }
}

/// RFC 6238 TOTP code generation used by the watch companion (ADR-013).
///
/// NOTE: this file is intentionally duplicated between the iOS app target
/// (`KeePassium/watch/`) and the watchOS target (`PassPouchWatch/`), because
/// the watch app does not link KeePassiumLib (ADR-012 Stage 4 not done yet).
/// Keep the two copies byte-identical; `Phase11WatchTests` covers this copy.
public enum WatchTOTPCore {
    public static let defaultPeriod = 30
    public static let defaultDigits = 6

    // MARK: - Base32 (RFC 4648)

    /// Minimal RFC 4648 base32 decoder (A–Z, 2–7); ignores whitespace and '='.
    /// The watch cannot use KeePassiumLib's `base32DecodeToData`, so this is
    /// the duplicated minimal equivalent.
    public static func base32Decode(_ string: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var output = [UInt8]()
        var buffer = 0
        var bitsLeft = 0
        for char in string.uppercased().unicodeScalars {
            guard char.value != 61, // '='
                  char.value != 32, // ' '
                  char.value != 10, // '\n'
                  char.value != 13 // '\r'
            else { continue }
            guard let index = alphabet.firstIndex(of: Character(char)) else {
                return nil
            }
            buffer = (buffer << 5) | index
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }
        return Data(output)
    }

    // MARK: - Code generation

    /// Generates an RFC 6238 TOTP code at the given instant, or nil if the
    /// seed cannot be decoded or the parameters are invalid.
    public static func generateCode(
        params: WatchTOTPParams,
        at date: Date = Date()
    ) -> String? {
        guard params.period > 0, (4...8).contains(params.digits) else {
            return nil
        }
        guard let seed = base32Decode(params.base32Seed), !seed.isEmpty else {
            return nil
        }
        guard let hmacData = hmac(
            algorithm: params.algorithm,
            counter: UInt64(date.timeIntervalSince1970 / Double(params.period)),
            seed: seed
        ) else {
            return nil
        }
        let offset = Int(hmacData[hmacData.count - 1] & 0x0F)
        let codeBytes = hmacData.subdata(in: offset..<(offset + 4))
        var code = 0
        for byte in codeBytes {
            code = (code << 8) | Int(byte)
        }
        code &= 0x7FFF_FFFF
        let modulus = Int(pow(10.0, Double(params.digits)))
        return String(format: "%0\(params.digits)d", code % modulus)
    }

    /// Formats a code for display: `123 456` / `1234 5678` grouping.
    public static func formatForDisplay(_ code: String) -> String {
        guard code.count >= 5, code.count % 2 == 0 else {
            return code
        }
        let half = code.count / 2
        let index = code.index(code.startIndex, offsetBy: half)
        return code[..<index] + " " + code[index...]
    }

    private static func hmac(
        algorithm: String,
        counter: UInt64,
        seed: Data
    ) -> Data? {
        let counterData = withUnsafeBytes(of: counter.bigEndian) { Data($0) }
        switch algorithm.uppercased() {
        case "SHA1":
            return CryptoKit.HMAC<Insecure.SHA1>
                .authenticationCode(for: counterData, using: SymmetricKey(data: seed))
                .withUnsafeBytes { Data($0) }
        case "SHA256":
            return CryptoKit.HMAC<SHA256>
                .authenticationCode(for: counterData, using: SymmetricKey(data: seed))
                .withUnsafeBytes { Data($0) }
        case "SHA512":
            return CryptoKit.HMAC<SHA512>
                .authenticationCode(for: counterData, using: SymmetricKey(data: seed))
                .withUnsafeBytes { Data($0) }
        default:
            return nil
        }
    }
}
