//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib

/// View model for the CSV import wizard. Holds the parsed CSV document, the
/// selected format and the role→column mapping; performs the actual import.
/// All decision logic is pure and unit-testable; SwiftUI only renders state.
final class CSVImportWizardModel: ObservableObject {
    let fileName: String
    let headerRow: [String]
    let dataRows: [[String]]

    /// Format auto-detected from the header row, if unambiguous.
    let detectedFormat: CSVImportFormat?

    /// User-selected format (defaults to the detected one).
    @Published var selectedFormat: CSVImportFormat

    /// Role → column index mapping (user-adjustable).
    @Published var mapping: [CSVColumnRole: Int]

    /// Import results, populated after `importEntries(into:...)`.
    @Published private(set) var summary: CSVImportSummary?

    var isFormatDetected: Bool { detectedFormat != nil }

    init(fileName: String, csvText: String) throws {
        self.fileName = fileName
        let rows = try CSVParser.parse(csvText)
        guard rows.count > 1 else {
            Diag.error("CSV has a header but no data rows")
            throw CSVParser.ParserError.noDataRows
        }
        headerRow = rows[0]
        dataRows = Array(rows.dropFirst())
        detectedFormat = CSVImportFormat.detect(headerRow: headerRow)
        let initialFormat = detectedFormat ?? .applePasswords
        selectedFormat = initialFormat
        mapping = initialFormat.autoMapping(for: headerRow)
    }

    /// Re-applies automatic mapping for the given format (used when the user
    /// overrides the format manually).
    func applyAutoMapping(for format: CSVImportFormat) {
        selectedFormat = format
        mapping = format.autoMapping(for: headerRow)
    }

    func setMapping(role: CSVColumnRole, column: Int?) {
        if let column {
            mapping[role] = column
        } else {
            mapping.removeValue(forKey: role)
        }
    }

    /// First N data rows rendered through the current mapping, for preview.
    func previewRows(limit: Int = 5) -> [[String]] {
        let mapper = CSVImportMapper(headerRow: headerRow, dataRows: dataRows)
        return mapper.prepareRows(mapping: mapping).prefix(limit).map(\.values)
    }

    /// Number of data rows that will be imported with the current mapping.
    var importableRowCount: Int {
        let mapper = CSVImportMapper(headerRow: headerRow, dataRows: dataRows)
        return mapper.prepareRows(mapping: mapping).count
    }

    /// Runs the import into `group` and stores the summary.
    func importEntries(into group: Group) -> CSVImportSummary {
        let mapper = CSVImportMapper(headerRow: headerRow, dataRows: dataRows)
        let result = mapper.importEntries(into: group, format: selectedFormat, mapping: mapping)
        summary = result
        return result
    }
}
