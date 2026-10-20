//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import CryptoKit
import Foundation

/// Conversion of externally exported passkey material into the in-database
/// KPEX passkey representation (KeePassXC KDBX 4.1 conventions, see
/// `EntryField+passkey.swift`).
///
/// Currently supports the Bitwarden JSON export `fido2Credentials` shape:
/// ECDSA/P-256 private keys as base64url-encoded DER (PKCS#8) in `keyValue`,
/// base64url-encoded credential ID and user handle.
public enum PasskeyImportError: LocalizedError {
    case unsupportedKeyAlgorithm
    case malformedPrivateKey
    case malformedBase64URL

    public var errorDescription: String? {
        switch self {
        case .unsupportedKeyAlgorithm:
            return NSLocalizedString(
                "[Database/PasskeyImport/Error/UnsupportedAlgorithm]",
                bundle: Bundle.framework,
                value: "Only ECDSA P-256 passkeys can be imported.",
                comment: "Error message when importing a passkey with an unsupported algorithm.")
        case .malformedPrivateKey:
            return NSLocalizedString(
                "[Database/PasskeyImport/Error/MalformedPrivateKey]",
                bundle: Bundle.framework,
                value: "The passkey private key data is malformed.",
                comment: "Error message when importing a malformed passkey private key.")
        case .malformedBase64URL:
            return NSLocalizedString(
                "[Database/PasskeyImport/Error/MalformedBase64URL]",
                bundle: Bundle.framework,
                value: "The passkey data is not valid base64url.",
                comment: "Error message when importing passkey data with invalid base64url encoding.")
        }
    }
}

public extension Passkey {
    /// Builds a `Passkey` from Bitwarden `fido2Credentials`-style fields.
    ///
    /// - Parameters:
    ///   - credentialIDBase64URL: `credentialId` (base64url).
    ///   - privateKeyBase64URL: `keyValue` — ECDSA P-256 private key in
    ///     base64url-encoded DER (PKCS#8) form.
    ///   - relyingParty: `rpId`.
    ///   - username: `userName` (or a sensible fallback from the source item).
    ///   - userHandleBase64URL: `userHandle` (base64url).
    /// - Returns `nil` if the data cannot be parsed or the key algorithm is
    ///   not ES256/P-256.
    static func make(
        fromBitwardenFIDO2Credential credentialIDBase64URL: String,
        privateKeyBase64URL: String,
        relyingParty: String,
        username: String,
        userHandleBase64URL: String
    ) -> Passkey? {
        guard let credentialID = Data(base64URLEncoded: credentialIDBase64URL),
              let userHandle = Data(base64URLEncoded: userHandleBase64URL)
        else {
            Diag.error("Failed to decode passkey credential ID or user handle")
            return nil
        }
        guard let privateKeyPEM = pemFromPKCS8DERBase64URL(privateKeyBase64URL) else {
            Diag.error("Failed to convert passkey private key to PEM")
            return nil
        }
        return Passkey(
            credentialID: credentialID,
            privateKeyPEM: privateKeyPEM,
            relyingParty: relyingParty,
            username: username,
            userHandle: userHandle,
            beFlag: true,
            bsFlag: true)
    }

    /// Converts a base64url-encoded DER PKCS#8 EC P-256 private key
    /// (Bitwarden `keyValue`) to the PEM representation used by KPEX
    /// `KPEX_PASSKEY_PRIVATE_KEY_PEM`. Returns `nil` for anything that is not
    /// a parseable P-256 private key.
    static func pemFromPKCS8DERBase64URL(_ base64URL: String) -> String? {
        guard let der = Data(base64URLEncoded: base64URL) else {
            Diag.error("Passkey private key is not valid base64url")
            return nil
        }
        guard let scalar = extractP256Scalar(fromPKCS8DER: der) else {
            Diag.error("Passkey private key DER does not contain a P-256 scalar")
            return nil
        }
        do {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: scalar)
            return privateKey.pemRepresentation
        } catch {
            Diag.error("Failed to build P-256 private key from scalar: \(error)")
            return nil
        }
    }

    /// Extracts the 32-byte P-256 private scalar from a DER PKCS#8 structure.
    ///
    /// PKCS#8 for secp256r1 looks like:
    /// `30 .. 02 01 01 04 20 <32-byte scalar> a1 .. 03 42 04 <65-byte point>`
    /// The scan is restricted to the region after the P-256 curve OID (the
    /// algorithm identifier must be present in a real PKCS#8 blob), and the
    /// extracted scalar is verified against the embedded public key when one
    /// is present — a naive byte-scan alone could match garbage and silently
    /// import a wrong-but-valid key.
    private static func extractP256Scalar(fromPKCS8DER der: Data) -> Data? {
        // OID for secp256r1 / prime256v1 inside the PKCS#8 algorithm identifier.
        let p256OID: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
        let marker: [UInt8] = [0x02, 0x01, 0x01, 0x04, 0x20]
        let bytes = [UInt8](der)

        guard let oidRange = firstOccurrence(of: p256OID, in: bytes) else {
            Diag.error("PKCS#8 blob does not contain the P-256 curve OID")
            return nil
        }
        // The version+key marker follows the algorithm identifier, inside the
        // OCTET STRING wrapping the ECPrivateKey SEQUENCE.
        let searchStart = oidRange.upperBound
        guard let markerRange = firstOccurrence(of: marker, in: Array(bytes[searchStart...]))
            .map({ $0.lowerBound + searchStart..<$0.upperBound + searchStart }),
              markerRange.upperBound + 32 <= bytes.count
        else {
            Diag.error("PKCS#8 blob does not contain the expected EC private key marker")
            return nil
        }
        let scalarStart = markerRange.upperBound
        let scalar = Data(bytes[scalarStart..<(scalarStart + 32)])
        // A valid EC scalar is non-zero (and < curve order; CryptoKit
        // validates that when constructing the key).
        guard scalar.contains(where: { $0 != 0 }) else { return nil }

        do {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: scalar)
            // If the optional [1] public key BIT STRING is present
            // (03 42 04 <65-byte uncompressed point>), verify it matches.
            let derived = privateKey.publicKey.rawRepresentation
            if let publicKeyPoint = embeddedUncompressedPublicKey(in: bytes, after: scalarStart + 32) {
                guard derived == publicKeyPoint else {
                    Diag.error("Extracted private scalar does not match the embedded public key")
                    return nil
                }
            } else {
                // Fail closed: if the embedded public key exists in any
                // length/tag encoding it must literally contain the derived
                // point; otherwise the key is unverifiable.
                let tail = Array(bytes[(scalarStart + 32)...])
                if firstOccurrence(of: [UInt8](derived), in: tail) != nil {
                    return scalar
                }
                if tail.contains(0xA1) {
                    Diag.error("Public key attribute present but unverifiable")
                    return nil
                }
            }
        } catch {
            Diag.error("Extracted scalar is not a valid P-256 private key: \(error)")
            return nil
        }
        return scalar
    }

    /// Finds the first occurrence of `pattern` in `bytes`, if any.
    private static func firstOccurrence(of pattern: [UInt8], in bytes: [UInt8]) -> Range<Int>? {
        guard pattern.count <= bytes.count else { return nil }
        for start in 0...(bytes.count - pattern.count) {
            if Array(bytes[start..<(start + pattern.count)]) == pattern {
                return start..<(start + pattern.count)
            }
        }
        return nil
    }

    /// Extracts a 65-byte uncompressed P-256 public point following a
    /// `03 42 04` BIT STRING header, if present after `afterIndex`.
    private static func embeddedUncompressedPublicKey(
        in bytes: [UInt8],
        after afterIndex: Int
    ) -> Data? {
        let header: [UInt8] = [0x03, 0x42, 0x04]
        guard afterIndex + header.count + 65 <= bytes.count else { return nil }
        for start in afterIndex...(bytes.count - header.count - 65) {
            if Array(bytes[start..<(start + header.count)]) == header {
                return Data(bytes[(start + header.count)..<(start + header.count + 65)])
            }
        }
        return nil
    }
}
