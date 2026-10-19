//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import CryptoKit
import Foundation
import KeePassiumLib

/// Pure logic for the offline entry-share feature (Phase 11c, ADR-015):
/// serializes selected entry fields into an encrypted, self-contained
/// payload and encodes it as a `passpouch://share` link.
///
/// Security model (no server, no network):
/// - The payload is encrypted with a freshly generated random key
///   (AES-256-GCM, authenticated) using CryptoKit.
/// - The key lives ONLY in the URL fragment (`#...`); the payload travels in
///   the URL path. The link itself is the secret — whoever holds the link
///   holds the data. Nothing is ever uploaded anywhere.
/// - The key and payload are never logged (Diag conventions).
public enum EntryShareField: String, CaseIterable, Codable {
    case title
    case userName
    case password
    case url
    case notes
    case totp

    var entryFieldName: String {
        switch self {
        case .title: return EntryField.title
        case .userName: return EntryField.userName
        case .password: return EntryField.password
        case .url: return EntryField.url
        case .notes: return EntryField.notes
        case .totp: return EntryField.otp // raw OTP config; see serializeFields
        }
    }

    var localizedTitle: String {
        switch self {
        case .title: return LString.shareFieldTitle
        case .userName: return LString.shareFieldUserName
        case .password: return LString.shareFieldPassword
        case .url: return LString.shareFieldURL
        case .notes: return LString.shareFieldNotes
        case .totp: return LString.shareFieldTOTP
        }
    }
}

/// The decrypted, self-contained share payload.
public struct SharePayload: Codable, Equatable {
    /// Payload format version.
    var version: Int
    /// Field name → resolved value. Names are EntryField standard names,
    /// plus OTP-related field names for TOTP.
    var fields: [String: String]
    /// Optional expiry timestamp, enforced at decrypt time.
    var expiresAt: Date?
}

public enum ShareLinkError: Error, Equatable {
    case nothingSelected
    case malformedLink
    case unsupportedPayloadVersion
    case decryptionFailed // wrong key or corrupted payload
    case expired
}

public enum EntrySharePayload {
    static let payloadVersion = 1
    /// Marker key under which the TOTP configuration is serialized.
    static let totpPayloadKey = "otpauth"

    /// Builds a payload from an entry, containing only the selected fields.
    /// TOTP is serialized as the raw OTP configuration field value(s);
    /// the recipient sees the config text (code generation on the recipient
    /// side is a documented follow-up).
    public static func make(
        from entry: Entry,
        fields: Set<EntryShareField>,
        expiresAt: Date?
    ) throws -> SharePayload {
        guard !fields.isEmpty else { throw ShareLinkError.nothingSelected }

        var payloadFields: [String: String] = [:]
        for field in fields.sorted(by: { $0.rawValue < $1.rawValue }) {
            switch field {
            case .totp:
                guard entry.hasValidTOTP else { continue }
                // Include every OTP-related field the generator could use.
                for name in [EntryField.totp, EntryField.otp,
                             EntryField.otpConfig2Seed, EntryField.otpConfig2Settings] {
                    if let entryField = entry.getField(name), entryField.resolvedValue.isNotEmpty {
                        payloadFields[name] = entryField.resolvedValue
                    }
                }
            default:
                let value: String
                switch field {
                case .title: value = entry.resolvedTitle
                case .userName: value = entry.resolvedUserName
                case .password: value = entry.resolvedPassword
                case .url: value = entry.resolvedURL
                case .notes: value = entry.resolvedNotes
                case .totp: continue // handled above
                }
                if value.isNotEmpty {
                    payloadFields[field.entryFieldName] = value
                }
            }
        }
        guard !payloadFields.isEmpty else { throw ShareLinkError.nothingSelected }

        return SharePayload(
            version: payloadVersion,
            fields: payloadFields,
            expiresAt: expiresAt)
    }

    // MARK: Encryption

    /// Encrypts the payload with a fresh random key. Returns the encoded
    /// payload bytes and the key (which must go into the URL fragment only).
    public static func encrypt(_ payload: SharePayload) throws -> (payload: Data, key: Data) {
        let key = SymmetricKey(size: .bits256)
        let json = try JSONEncoder().encode(payload)
        let sealed = try AES.GCM.seal(json, using: key)
        guard let combined = sealed.combined else {
            throw ShareLinkError.decryptionFailed
        }
        // version byte + AES-GCM combined (nonce|ciphertext|tag)
        var payloadData = Data([UInt8(payloadVersion)])
        payloadData.append(combined)
        return (payloadData, key.withUnsafeBytes { Data($0) })
    }

    /// Decrypts and validates a payload. Throws `decryptionFailed` for a
    /// wrong key or corrupted data (AEAD authentication), `expired` if the
    /// optional expiry timestamp has passed.
    public static func decrypt(_ payloadData: Data, key: Data) throws -> SharePayload {
        guard payloadData.count > 1, payloadData[0] == UInt8(payloadVersion) else {
            throw ShareLinkError.unsupportedPayloadVersion
        }
        let combined = payloadData.dropFirst()
        guard combined.count > AES.GCM.nonceByteSize else {
            throw ShareLinkError.malformedLink
        }
        guard key.count == 32 else { throw ShareLinkError.decryptionFailed }
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: Data(combined))
            let json = try AES.GCM.open(sealedBox, using: symmetricKey)
            let payload = try JSONDecoder().decode(SharePayload.self, from: json)
            if let expiresAt = payload.expiresAt, expiresAt < Date() {
                throw ShareLinkError.expired
            }
            return payload
        } catch let error as ShareLinkError {
            throw error
        } catch {
            throw ShareLinkError.decryptionFailed
        }
    }

    // MARK: Link assembly / parsing

    static let linkHost = "share"

    /// Maximum accepted base64url payload length in a share link, in
    /// characters. Real payloads stay far below this; the cap only blocks
    /// memory-exhaustion attempts via a crafted link.
    static let maxPayloadLinkLength = 4_000_000

    /// Assembles the share link: `passpouch://share/<payload>#<key>`.
    /// The key is in the fragment only — fragments are never sent to any
    /// server and are dropped from `URL.redacted` log output.
    public static func makeLink(payloadData: Data, key: Data) throws -> URL {
        let payloadString = payloadData.base64URLEncodedString()
        let keyString = key.base64URLEncodedString()
        var components = URLComponents()
        components.scheme = AppGroup.appURLScheme
        components.host = linkHost
        components.path = "/" + payloadString
        components.fragment = keyString
        guard let url = components.url else { throw ShareLinkError.malformedLink }
        return url
    }

    /// Parses a share link back into payload bytes and key bytes.
    /// Accepts links with or without the scheme prefix being normalized.
    public static func parseLink(_ url: URL) throws -> (payload: Data, key: Data) {
        guard url.scheme == AppGroup.appURLScheme, url.host == linkHost else {
            throw ShareLinkError.malformedLink
        }
        let payloadString = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
        // Guard against absurdly large payloads (memory-exhaustion via a
        // crafted link) before base64-decoding anything.
        guard payloadString.count <= Self.maxPayloadLinkLength else {
            throw ShareLinkError.malformedLink
        }
        guard let payloadData = Data(base64URLEncoded: payloadString),
              let keyString = url.fragment,
              let keyData = Data(base64URLEncoded: keyString),
              keyData.count == 32
        else {
            throw ShareLinkError.malformedLink
        }
        return (payloadData, keyData)
    }
}

