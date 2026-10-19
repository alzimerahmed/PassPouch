//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib

// swiftlint:disable line_length
extension LString {
    public enum CSVImport {}
}

extension LString {
    public static let titleCSVFile = NSLocalizedString(
        "[Format/CSVFile]",
        value: "CSV file (auto-detect)",
        comment: "Menu item: import entries from a generic CSV file with format auto-detection"
    )

}

extension LString.CSVImport {
        public static let wizardTitle = NSLocalizedString(
            "[CSVImport/Title]",
            value: "Import CSV",
            comment: "Title of the CSV import wizard"
        )
        public static let sectionFile = NSLocalizedString(
            "[CSVImport/Section/File]",
            value: "File",
            comment: "CSV import wizard: section header for file info"
        )
        public static let sectionFormat = NSLocalizedString(
            "[CSVImport/Section/Format]",
            value: "Format",
            comment: "CSV import wizard: section header for format selection"
        )
        public static let sectionColumnMapping = NSLocalizedString(
            "[CSVImport/Section/ColumnMapping]",
            value: "Column Mapping",
            comment: "CSV import wizard: section header for column mapping"
        )
        public static let sectionPreview = NSLocalizedString(
            "[CSVImport/Section/Preview]",
            value: "Preview",
            comment: "CSV import wizard: section header for row preview"
        )
        public static let sectionSummary = NSLocalizedString(
            "[CSVImport/Section/Summary]",
            value: "Summary",
            comment: "CSV import wizard: section header for import results"
        )
        public static let formatNotRecognized = NSLocalizedString(
            "[CSVImport/FormatNotRecognized]",
            value: "Format not recognized — select it manually.",
            comment: "CSV import wizard: message when auto-detection fails"
        )
        public static let unmappedColumn = NSLocalizedString(
            "[CSVImport/UnmappedColumn]",
            value: "Not imported",
            comment: "CSV import wizard: picker option meaning the column is not mapped to any field"
        )
        public static let rowCountTemplate = NSLocalizedString(
            "[CSVImport/RowCount]",
            value: "%d data row(s)",
            comment: "CSV import wizard: number of data rows in the file [count: Int]"
        )
        public static let previewRowsTemplate = NSLocalizedString(
            "[CSVImport/PreviewRows]",
            value: "First %d row(s):",
            comment: "CSV import wizard: preview header [count: Int]"
        )
        public static let summaryImportedTemplate = NSLocalizedString(
            "[CSVImport/Summary/Imported]",
            value: "Imported: %d",
            comment: "CSV import summary: number of imported entries [count: Int]"
        )
        public static let summarySkippedTemplate = NSLocalizedString(
            "[CSVImport/Summary/Skipped]",
            value: "Skipped: %d",
            comment: "CSV import summary: number of skipped (empty) rows [count: Int]"
        )
        public static let summaryFailedTemplate = NSLocalizedString(
            "[CSVImport/Summary/Failed]",
            value: "Failed: %d",
            comment: "CSV import summary: number of failed (malformed) rows [count: Int]"
        )
        public static let rowWrongColumnCount = NSLocalizedString(
            "[CSVImport/Row/WrongColumnCount]",
            value: "Wrong number of columns",
            comment: "CSV import: reason for failing a row with a mismatched column count"
        )
        public static let rowEmpty = NSLocalizedString(
            "[CSVImport/Row/Empty]",
            value: "Row has no title, username or password",
            comment: "CSV import: reason for skipping an empty row"
        )
        public static let roleTitle = NSLocalizedString(
            "[CSVImport/Role/Title]",
            value: "Title",
            comment: "CSV import wizard: column role name"
        )
        public static let roleURL = NSLocalizedString(
            "[CSVImport/Role/URL]",
            value: "URL",
            comment: "CSV import wizard: column role name"
        )
        public static let roleUsername = NSLocalizedString(
            "[CSVImport/Role/Username]",
            value: "Username",
            comment: "CSV import wizard: column role name"
        )
        public static let rolePassword = NSLocalizedString(
            "[CSVImport/Role/Password]",
            value: "Password",
            comment: "CSV import wizard: column role name"
        )
        public static let roleNotes = NSLocalizedString(
            "[CSVImport/Role/Notes]",
            value: "Notes",
            comment: "CSV import wizard: column role name"
        )
        public static let roleTOTP = NSLocalizedString(
            "[CSVImport/Role/TOTP]",
            value: "One-time code (TOTP)",
            comment: "CSV import wizard: column role name"
        )
        public static let formatOnePasswordCSV = NSLocalizedString(
            "[Format/OnePasswordCSV]",
            value: "1Password (.csv)",
            comment: "Name of 1Password's CSV file format"
        )
        public static let formatBitwardenCSV = NSLocalizedString(
            "[Format/BitwardenCSV]",
            value: "Bitwarden (.csv)",
            comment: "Name of Bitwarden's CSV file format"
        )
        public static let formatChromeCSV = NSLocalizedString(
            "[Format/ChromeCSV]",
            value: "Chrome / Edge (.csv)",
            comment: "Name of the Chrome/Edge browser password CSV format"
        )
        public static let formatFirefoxCCSV = NSLocalizedString(
            "[Format/FirefoxCSV]",
            value: "Firefox (.csv)",
            comment: "Name of the Firefox browser password CSV format"
        )
    }
}

extension LString.Error {
        public static let importCSVFileTooLargeTemplate = NSLocalizedString(
            "[Import/CSV/Error/FileTooLarge]",
            value: "The CSV file is too large (over %d MB).",
            comment: "Error message when a CSV file exceeds the size limit [maxMB: Int]"
        )
        public static let importCSVUnclosedQuoteTemplate = NSLocalizedString(
            "[Import/CSV/Error/UnclosedQuote]",
            value: "Invalid CSV format: unclosed quote at line %d.",
            comment: "Error message when CSV parsing fails due to an unclosed quote [lineNumber: Int]"
        )
        public static let importCSVNoDataRows = NSLocalizedString(
            "[Import/CSV/Error/NoDataRows]",
            value: "The CSV file contains no data rows.",
            comment: "Error message when a CSV file has a header but no data"
        )
    }
}
// swiftlint:enable line_length
