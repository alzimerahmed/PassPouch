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

    /// Validates data rows against the mapping and returns the rows that can
    /// be imported. Rows with a wrong column count fail; rows without any of
    /// title/username/password are skipped as empty.
    func prepareRows(mapping: [CSVColumnRole: Int]) -> [PreparedRow] {
        var prepared = [PreparedRow]()
        for (index, row) in dataRows.enumerated() {
            guard row.count == headerRow.count else {
                // Wrong column count — cannot map reliably; counted as failed.
                continue
            }
            let hasMeaningfulContent = [CSVColumnRole.title, .username, .password]
                .contains { role in
                    guard let column = mapping[role] else { return false }
                    return column < row.count && !row[column].trimmingCharacters(in: .whitespaces).isEmpty
                }
            guard hasMeaningfulContent else { continue }
            prepared.append(PreparedRow(rowIndex: index + 1, values: row))
        }
        return prepared
    }

    /// Classifies a single data row (for preview/summary accounting).
    func classifyRow(_ row: [String], mapping: [CSVColumnRole: Int]) -> RowOutcome {
        guard row.count == headerRow.count else {
            return .failed(reason: LString.CSVImport.rowWrongColumnCount)
        }
        let hasMeaningfulContent = [CSVColumnRole.title, .username, .password]
            .contains { role in
                guard let column = mapping[role] else { return false }
                return column < row.count && !row[column].trimmingCharacters(in: .whitespaces).isEmpty
            }
        guard hasMeaningfulContent else {
            return .skipped(reason: LString.CSVImport.rowEmpty)
        }
        return .imported
    }

    /// Creates entries in `group` (detached, so the caller controls insertion)
    /// and returns the import summary. Passwords and TOTP seeds are stored as
    /// protected fields.
    func importEntries(
        into group: Group,
        format: CSVImportFormat,
        mapping: [CSVColumnRole: Int]
    ) -> CSVImportSummary {
        var summary = CSVImportSummary()
        let customFieldColumns = format.customFieldColumns(
            headerRow: headerRow,
            mapping: mapping)

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

            let entry = group.createEntry(detached: true)
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
                    entry.setField(name: "TOTP", value: totp, isProtected: true)
                }
            }

            for column in customFieldColumns where column < row.count {
                let name = column < headerRow.count ? headerRow[column] : "field\(column)"
                let fieldValue = row[column]
                guard !fieldValue.isEmpty else { continue }
                entry.setField(name: name, value: fieldValue, isProtected: false)
            }

            entry.touch(.modified)
            summary.imported += 1
        }
        return summary
    }
}
