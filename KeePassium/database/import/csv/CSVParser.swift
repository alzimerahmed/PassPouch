//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib

/// Minimal, dependency-free CSV parser (RFC 4180-ish) used by the CSV import
/// wizard. Handles quoted fields, escaped quotes (`""`), CRLF/LF/CR line
/// endings and embedded newlines inside quoted fields. Strips a UTF-8 BOM.
///
/// Deliberately lenient about ragged rows (rows with a different column count
/// than the header): they are returned as-is so the import layer can count
/// them as failed rows and show a per-row summary instead of aborting.
enum CSVParser {
    public enum ParserError: LocalizedError {
        case emptyFile
        case oversizedFile(maxBytes: Int)
        case unclosedQuote(line: Int)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return LString.Error.importEmptyIncomingFile
            case let .oversizedFile(maxBytes):
                return String.localizedStringWithFormat(
                    LString.Error.importCSVFileTooLargeTemplate,
                    maxBytes / (1024 * 1024))
            case let .unclosedQuote(line):
                return String.localizedStringWithFormat(
                    LString.Error.importCSVUnclosedQuoteTemplate, line)
            }
        }
    }

    /// Upper bound for accepted CSV files; password-manager exports are far
    /// smaller, and the limit protects the wizard from pathological inputs.
    public static let maxFileSizeBytes = 10 * 1024 * 1024 // 10 MB

    /// Loads a CSV file as UTF-8 text, enforcing the size limit *before*
    /// reading the whole file into memory.
    public static func loadText(from fileURL: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let fileSize = attributes[.size] as? Int, fileSize > maxFileSizeBytes {
            Diag.error("CSV file is too large [size: \(fileSize)]")
            throw ParserError.oversizedFile(maxBytes: maxFileSizeBytes)
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            Diag.error("Incoming CSV file is empty")
            throw ParserError.emptyFile
        }
        guard let text = String(data: data, encoding: .utf8) else {
            Diag.error("CSV file is not valid UTF-8")
            throw ParserError.emptyFile
        }
        return text
    }

    /// Parses CSV text into rows of fields. The first row is conventionally
    /// the header, but the parser does not care — callers decide.
    public static func parse(_ rawText: String) throws -> [[String]] {
        // Strip UTF-8 BOM if present.
        var text = rawText
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Diag.error("CSV content is empty")
            throw ParserError.emptyFile
        }

        var rows = [[String]]()
        var currentRow = [String]()
        var currentField = ""
        var isInQuotes = false
        var line = 1

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            let nextIndex = text.index(after: index)

            switch char {
            case "\"":
                if isInQuotes {
                    if nextIndex < text.endIndex && text[nextIndex] == "\"" {
                        // Escaped quote.
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        isInQuotes = false
                    }
                } else {
                    isInQuotes = true
                }
            case ",":
                if isInQuotes {
                    currentField.append(char)
                } else {
                    currentRow.append(currentField)
                    currentField = ""
                }
            case "\r":
                if isInQuotes {
                    currentField.append(char)
                } else if nextIndex < text.endIndex && text[nextIndex] == "\n" {
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                    line += 1
                    index = nextIndex
                } else {
                    // Lone CR (old Mac line ending).
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                    line += 1
                }
            case "\n":
                if isInQuotes {
                    currentField.append(char)
                } else {
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                    line += 1
                }
            default:
                currentField.append(char)
            }
            index = text.index(after: index)
        }

        if isInQuotes {
            Diag.error("Unclosed quote in CSV [line: \(line)]")
            throw ParserError.unclosedQuote(line: line)
        }
        // Final row without a trailing newline.
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        // Drop trailing fully-empty rows (artifacts of trailing newlines).
        while let lastRow = rows.last, lastRow.count == 1, lastRow[0].isEmpty {
            rows.removeLast()
        }
        guard !rows.isEmpty else {
            Diag.error("CSV content has no rows")
            throw ParserError.emptyFile
        }
        return rows
    }
}
