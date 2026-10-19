//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib

/// One parsed `otpauth://` item ready for import.
struct OtpauthItem: Equatable, Identifiable {
    let uri: String
    let issuer: String
    let accountName: String
    /// Stable identity: full URI (includes the secret) — dedupes identical QR payloads.
    var id: String { uri }
}

/// Pure parser for bulk `otpauth://` migration payloads (2FAS / Raivo /
/// Bitwarden export QR codes or pasted text). Handles multiple URIs separated
/// by newlines; validation reuses `TOTPGeneratorFactory.isValidURI`.
enum OtpauthBulkImporter {
    struct ParseResult: Equatable {
        let items: [OtpauthItem]
        let invalidLineCount: Int
    }

    /// Parses a (possibly multi-line) payload of otpauth:// URIs.
    /// - Parameter payload: raw text, e.g. a QR scan or pasted export.
    static func parse(payload: String) -> ParseResult {
        var items = [OtpauthItem]()
        var invalidCount = 0

        let lines = payload
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isNotEmpty else { continue }
            guard line.lowercased().hasPrefix("otpauth://") else {
                invalidCount += 1
                continue
            }
            guard TOTPGeneratorFactory.isValidURI(line) else {
                invalidCount += 1
                continue
            }
            let (issuer, accountName) = parseLabel(from: line)
            items.append(
                OtpauthItem(uri: line, issuer: issuer, accountName: accountName))
        }
        return ParseResult(items: items, invalidLineCount: invalidCount)
    }

    /// Extracts issuer/account from the URI path label (`/Issuer:account`)
    /// and the `issuer` query parameter (query wins, per the otpauth spec).
    static func parseLabel(from uri: String) -> (issuer: String, accountName: String) {
        guard let components = URLComponents(string: uri) else {
            return ("", "")
        }
        var issuer = components.queryItems?
            .first(where: { $0.name == "issuer" })?
            .value ?? ""
        let path = String(components.path.dropFirst()) // drop leading "/"
        let label = path.removingPercentEncoding ?? path
        let labelParts = label.components(separatedBy: ":")
        let accountName: String
        if labelParts.count >= 2 {
            if issuer.isEmpty { issuer = labelParts[0] }
            accountName = labelParts.dropFirst().joined(separator: ":")
        } else {
            accountName = label
        }
        return (issuer, accountName)
    }
}
