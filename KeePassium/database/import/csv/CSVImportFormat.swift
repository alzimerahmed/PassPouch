//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib

/// Logical roles a CSV column can play in the import wizard.
enum CSVColumnRole: Int, CaseIterable, Identifiable {
    case title
    case url
    case username
    case password
    case notes
    case totp

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .title:
            return LString.CSVImport.roleTitle
        case .url:
            return LString.CSVImport.roleURL
        case .username:
            return LString.CSVImport.roleUsername
        case .password:
            return LString.CSVImport.rolePassword
        case .notes:
            return LString.CSVImport.roleNotes
        case .totp:
            return LString.CSVImport.roleTOTP
        }
    }
}

/// Supported CSV export formats, with header aliases for auto-detection and
/// automatic column mapping. Detection scores each format by how many of its
/// required header names are present in the file's header row.
enum CSVImportFormat: Int, CaseIterable, Identifiable {
    case onePassword = 0
    case bitwarden = 1
    case applePasswords = 2
    case chrome = 3
    case firefox = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .onePassword:
            return LString.CSVImport.formatOnePasswordCSV
        case .bitwarden:
            return LString.CSVImport.formatBitwardenCSV
        case .applePasswords:
            return LString.titleApplePasswordsCSV
        case .chrome:
            return LString.CSVImport.formatChromeCSV
        case .firefox:
            return LString.CSVImport.formatFirefoxCSV
        }
    }

    /// Header names (case-insensitive) that identify this format. A header row
    /// matching more of these wins detection; ties are reported as ambiguous.
    var requiredHeaders: Set<String> {
        switch self {
        case .onePassword:
            return ["title", "url", "username", "password"]
        case .bitwarden:
            return ["name", "login_uri", "login_username", "login_password"]
        case .applePasswords:
            return ["title", "url", "username", "password", "otpauth"]
        case .chrome:
            return ["name", "url", "username", "password"]
        case .firefox:
            return ["url", "username", "password", "httprealm", "formactionorigin"]
        }
    }

    /// Header-name aliases (lowercase) → column role, for automatic mapping.
    var headerAliases: [String: CSVColumnRole] {
        switch self {
        case .onePassword:
            return [
                "title": .title,
                "name": .title,
                "url": .url,
                "website": .url,
                "login_uri": .url,
                "username": .username,
                "login_username": .username,
                "user name": .username,
                "password": .password,
                "login_password": .password,
                "notes": .notes,
                "note": .notes,
                "otpauth": .totp,
                "totp": .totp,
                "login_totp": .totp,
            ]
        case .bitwarden:
            return [
                "name": .title,
                "login_uri": .url,
                "login_username": .username,
                "login_password": .password,
                "login_totp": .totp,
                "notes": .notes,
            ]
        case .applePasswords:
            return [
                "title": .title,
                "url": .url,
                "username": .username,
                "password": .password,
                "notes": .notes,
                "otpauth": .totp,
            ]
        case .chrome:
            return [
                "name": .title,
                "url": .url,
                "username": .username,
                "password": .password,
            ]
        case .firefox:
            return [
                "url": .url,
                "username": .username,
                "password": .password,
                "notes": .notes,
            ]
        }
    }

    /// Exporter metadata columns that must NOT become custom fields.
    var ignoredColumns: Set<String> {
        switch self {
        case .onePassword:
            return ["type", "tags", "favindex"]
        case .bitwarden:
            return ["folder", "favorite", "type", "fields", "reprompt"]
        case .applePasswords:
            return []
        case .chrome:
            return []
        case .firefox:
            return [
                "formactionorigin", "guid",
                "timecreated", "timelastused", "timepasswordchanged",
            ]
        }
    }

    /// Detects the format from a header row. Returns nil when no format
    /// matches or when two formats tie (the wizard then asks for a manual
    /// override).
    public static func detect(headerRow: [String]) -> CSVImportFormat? {
        let normalized = Set(headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        var bestScore = 0
        var bestFormats = [CSVImportFormat]()
        for format in CSVImportFormat.allCases {
            let score = format.requiredHeaders.intersection(normalized).count
            if score > bestScore {
                bestScore = score
                bestFormats = [format]
            } else if score == bestScore && score > 0 {
                bestFormats.append(format)
            }
        }
        guard bestFormats.count == 1 else { return nil }
        return bestFormats.first
    }

    /// Automatic role→column-index mapping for this format's header row.
    /// Roles without a matching column are omitted.
    func autoMapping(for headerRow: [String]) -> [CSVColumnRole: Int] {
        var mapping = [CSVColumnRole: Int]()
        for (index, column) in headerRow.enumerated() {
            let normalized = column.trimmingCharacters(in: .whitespaces).lowercased()
            guard let role = headerAliases[normalized], mapping[role] == nil else { continue }
            mapping[role] = index
        }
        return mapping
    }

    /// Columns that are neither mapped to a role nor ignored become custom
    /// fields with the header name as the field name.
    func customFieldColumns(
        headerRow: [String],
        mapping: [CSVColumnRole: Int]
    ) -> [Int] {
        let mappedIndices = Set(mapping.values)
        var result = [Int]()
        for (index, column) in headerRow.enumerated() {
            let normalized = column.trimmingCharacters(in: .whitespaces).lowercased()
            guard !normalized.isEmpty,
                  !mappedIndices.contains(index),
                  !ignoredColumns.contains(normalized) else { continue }
            result.append(index)
        }
        return result
    }
}
