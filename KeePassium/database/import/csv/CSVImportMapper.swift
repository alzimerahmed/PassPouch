//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib

/// Outcome of a CSV import, shown in the wizard's summary step.
struct CSVImportSummary: Equatable {
    var imported = 0
    var skipped = 0
    var failed = 0

    var hasProblems: Bool { skipped > 0 || failed > 0 }
}

/// Maps parsed CSV rows to KeePass entries according to a format + column
/// mapping. Pure logic, no UI — unit-testable in isolation.
struct CSVImportMapper {
    /// A single data row prepared for import.
    struct PreparedRow {
        let rowIndex: Int // 1-based data row number (excluding header)
        let values: [String]
    }

    enum RowOutcome: Equatable {
        case imported
        case skipped(reason: String)
        case failed(reason: String)
    }

    let headerRow: [String]
    let dataRows: [[String]]

    /// A row is malformed when it has more columns than the header, or when
    /// it is so short that a mapped title/username/password column is out of
    /// bounds. Shorter rows that still cover those columns are importable:
    /// real exports commonly omit trailing empty cells.
    private func isMalformed(_ row: [String], mapping: [CSVColumnRole: Int]) -> Bool {
        if row.count > headerRow.count { return true }
        let lastRequiredColumn = [CSVColumnRole.title, .username, .password]
            .compactMap { mapping[$0] }
            .max() ?? -1
        return row.count <= lastRequiredColumn
    }

    /// Validates data rows against the mapping and returns the rows that can
    /// be imported. Malformed rows fail; rows without any of
    /// title/username/password are skipped as empty.
    func prepareRows(mapping: [CSVColumnRole: Int]) -> [PreparedRow] {
        var prepared = [PreparedRow]()
        for (index, row) in dataRows.enumerated() {
            guard !isMalformed(row, mapping: mapping) else {
                // Wrong column count — cannot map reliably; counted as failed.
                continue
            }
            guard hasMeaningfulContent(row, mapping: mapping) else { continue }
            prepared.append(PreparedRow(rowIndex: index + 1, values: row))
        }
        return prepared
    }

    /// Classifies a single data row (for preview/summary accounting).
    func classifyRow(_ row: [String], mapping: [CSVColumnRole: Int]) -> RowOutcome {
        guard !isMalformed(row, mapping: mapping) else {
            return .failed(reason: LString.CSVImport.rowWrongColumnCount)
        }
        guard hasMeaningfulContent(row, mapping: mapping) else {
            return .skipped(reason: LString.CSVImport.rowEmpty)
        }
        return .imported
    }

    /// A row is importable only if at least one of title/username/password
    /// is mapped to an existing, non-empty column.
    private func hasMeaningfulContent(
        _ row: [String],
        mapping: [CSVColumnRole: Int]
    ) -> Bool {
        return [CSVColumnRole.title, .username, .password].contains { role in
            guard let column = mapping[role] else { return false }
            return column < row.count
                && !row[column].trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Creates entries directly inside `group` and returns the import summary.
    /// Passwords and TOTP seeds are stored as protected fields.
    func importEntries(
        into group: Group,
        format: CSVImportFormat,
        mapping: [CSVColumnRole: Int]
    ) -> CSVImportSummary {
        var summary = CSVImportSummary()
        let customFieldColumns = format.customFieldColumns(
            headerRow: headerRow,
            mapping: mapping)
        // Standard field names (case-insensitive) must never be overwritten
        // by unmapped custom-field columns; such columns are renamed
        // "<name> (n)" instead of silently dropped.
        let reservedNames = Set([
            EntryField.title,
            EntryField.userName,
            EntryField.password,
            EntryField.url,
            EntryField.notes,
            EntryField.otp,
            EntryField.totp,
        ].map { $0.lowercased() })

        for row in dataRows {
            switch classifyRow(row, mapping: mapping) {
            case .failed:
                summary.failed += 1
                continue
            case .skipped:
                summary.skipped += 1
                continue
            case .imported:
                break
            }

            let entry = group.createEntry(detached: false)
            entry.populateStandardFields()

            func value(for role: CSVColumnRole) -> String {
                guard let column = mapping[role], column < row.count else { return "" }
                return row[column]
            }

            entry.rawTitle = value(for: .title)
            entry.rawURL = value(for: .url)
            entry.rawUserName = value(for: .username)
            entry.rawPassword = value(for: .password) // rawPassword is protected
            entry.rawNotes = value(for: .notes)

            let totp = value(for: .totp).trimmingCharacters(in: .whitespaces)
            if !totp.isEmpty {
                if TOTPGeneratorFactory.isValidURI(totp) {
                    entry.setField(name: EntryField.otp, value: totp, isProtected: true)
                } else {
                    // Not a valid otpauth URI — keep it as a protected custom
                    // field instead of silently dropping the data.
                    entry.setField(name: EntryField.totp, value: totp, isProtected: true)
                }
            }

            // Unmapped columns must not collide with standard field names.
            var seenNames = [String: Int]()
            for name in reservedNames { seenNames[name] = 1 }
            for column in customFieldColumns where column < row.count {
                let rawName = column < headerRow.count ? headerRow[column] : "field\(column)"
                let normalized = rawName.trimmingCharacters(in: .whitespaces).lowercased()
                guard !normalized.isEmpty else { continue }
                // Deduplicate repeated or reserved header names so same-named
                // columns do not overwrite each other's values.
                let occurrence = (seenNames[normalized] ?? 0) + 1
                seenNames[normalized] = occurrence
                let fieldName = occurrence == 1 ? rawName : "\(rawName) (\(occurrence))"
                let fieldValue = row[column]
                guard !fieldValue.isEmpty else { continue }
                entry.setField(name: fieldName, value: fieldValue, isProtected: false)
            }

            entry.touch(.modified)
            summary.imported += 1
        }
        return summary
    }
}
