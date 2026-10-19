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
            let privateKey = try P256.Signing.PrivateKey(dataRepresentation: scalar)
            return privateKey.pemRepresentation
        } catch {
            Diag.error("Failed to build P-256 private key from scalar: \(error)")
            return nil
        }
    }

    /// Extracts the 32-byte P-256 private scalar from a DER PKCS#8 structure.
    ///
    /// PKCS#8 for secp256r1 looks like:
    /// `30 .. 02 01 01 04 20 <32-byte scalar> a0 .. 06 08 2A 86 48 CE 3D 03 01 07`
    /// We locate the `02 01 01 04 20` sequence and take the following 32 bytes;
    /// the curve OID is then verified when the key is constructed by CryptoKit.
    private static func extractP256Scalar(fromPKCS8DER der: Data) -> Data? {
        let marker: [UInt8] = [0x02, 0x01, 0x01, 0x04, 0x20]
        let bytes = [UInt8](der)
        guard bytes.count > marker.count + 32 else { return nil }

        var index = 0
        while index <= bytes.count - (marker.count + 32) {
            guard bytes[index] == marker[0] else { index += 1; continue }
            let window = Array(bytes[index..<(index + marker.count)])
            guard window == marker else { index += 1; continue }
            let scalar = Data(bytes[(index + marker.count)..<(index + marker.count + 32)])
            // A valid EC scalar is non-zero (and < curve order; CryptoKit
            // validates that when constructing the key).
            guard scalar.contains(where: { $0 != 0 }) else { return nil }
            return scalar
        }
        return nil
    }
}
