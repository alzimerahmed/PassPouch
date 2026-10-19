//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

final class Phase9ImportTests: XCTestCase {
    // MARK: - CSV parser

    func testParserBasicRows() throws {
        let rows = try CSVParser.parse("a,b,c\n1,2,3")
        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testParserQuotedFieldsAndEscapedQuotes() throws {
        let rows = try CSVParser.parse(#""a, with comma","say ""hi""",plain"#)
        XCTAssertEqual(rows, [["a, with comma", "say \"hi\"", "plain"]])
    }

    func testParserEmbeddedNewlineInQuotes() throws {
        let rows = try CSVParser.parse("title,notes\n\"Entry\",\"line1\nline2\"")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["Entry", "line1\nline2"])
    }

    func testParserCRLFAndLoneCR() throws {
        XCTAssertEqual(try CSVParser.parse("a,b\r\n1,2"), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(try CSVParser.parse("a,b\r1,2"), [["a", "b"], ["1", "2"]])
    }

    func testParserStripsBOM() throws {
        let rows = try CSVParser.parse("\u{FEFF}a,b\n1,2")
        XCTAssertEqual(rows.first?.first, "a")
    }

    func testParserTrailingNewlineDoesNotCreateEmptyRow() throws {
        let rows = try CSVParser.parse("a,b\n1,2\n")
        XCTAssertEqual(rows.count, 2)
    }

    func testParserEmptyContentThrows() {
        XCTAssertThrowsError(try CSVParser.parse(""))
        XCTAssertThrowsError(try CSVParser.parse("\n\n  \n"))
    }

    func testParserUnclosedQuoteThrows() {
        XCTAssertThrowsError(try CSVParser.parse("a,b\n\"unterminated")) { error in
            guard case CSVParser.ParserError.unclosedQuote = error else {
                return XCTFail("Expected unclosedQuote, got \(error)")
            }
        }
    }

    func testParserRaggedRowsAreLenient() throws {
        // Wrong column counts must not abort parsing; the mapper counts them
        // as failed rows instead.
        let rows = try CSVParser.parse("a,b,c\n1,2\n1,2,3,4")
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1].count, 2)
        XCTAssertEqual(rows[2].count, 4)
    }

    func testLoadTextRejectsOversizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase9-oversize.csv")
        let bigData = Data(repeating: UInt8(ascii: "a"), count: CSVParser.maxFileSizeBytes + 1)
        try bigData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CSVParser.loadText(from: url)) { error in
            guard case CSVParser.ParserError.oversizedFile = error else {
                return XCTFail("Expected oversizedFile, got \(error)")
            }
        }
    }

    func testLoadTextRejectsEmptyFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("phase9-empty.csv")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CSVParser.loadText(from: url)) { error in
            guard case CSVParser.ParserError.emptyFile = error else {
                return XCTFail("Expected emptyFile, got \(error)")
            }
        }
    }

    // MARK: - Format auto-detection

    func testDetectApplePasswords() {
        let header = ["Title", "URL", "Username", "Password", "Notes", "OTPAuth"]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: header), .applePasswords)
    }

    func testDetectBitwarden() {
        let header = [
            "folder", "favorite", "type", "name", "notes", "fields",
            "reprompt", "login_uri", "login_username", "login_password",
            "login_totp",
        ]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: header), .bitwarden)
    }

    func testDetectOnePassword() {
        // 1Password's CSV header is identical to Apple Passwords' except that
        // Apple always includes the OTPAuth column. Without it, the file
        // resolves to 1Password; with it, to Apple Passwords (same mapping).
        let header = ["Title", "Url", "Username", "Password", "Notes"]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: header), .onePassword)
        let withOTP = header + ["OTPAuth"]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: withOTP), .applePasswords)
    }

    func testDetectChromeAndEdge() {
        let header = ["name", "url", "username", "password"]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: header), .chrome)
    }

    func testDetectFirefox() {
        let header = [
            "url", "username", "password", "httpRealm", "formUrlPath",
            "notes", "timeCreated", "timeLastUsed", "timePasswordChanged",
        ]
        XCTAssertEqual(CSVImportFormat.detect(headerRow: header), .firefox)
    }

    func testDetectAmbiguousReturnsNil() {
        // "url,username,password" matches both Chrome and Firefox partially
        // with equal scores → ambiguous → manual override required.
        XCTAssertNil(CSVImportFormat.detect(headerRow: ["url", "username", "password"]))
    }

    func testDetectUnknownReturnsNil() {
        XCTAssertNil(CSVImportFormat.detect(headerRow: ["foo", "bar"]))
    }

    // MARK: - Column mapping per exporter

    func testAutoMappingApplePasswords() throws {
        let header = ["Title", "URL", "Username", "Password", "Notes", "OTPAuth"]
        let mapping = CSVImportFormat.applePasswords.autoMapping(for: header)
        XCTAssertEqual(mapping[.title], 0)
        XCTAssertEqual(mapping[.url], 1)
        XCTAssertEqual(mapping[.username], 2)
        XCTAssertEqual(mapping[.password], 3)
        XCTAssertEqual(mapping[.notes], 4)
        XCTAssertEqual(mapping[.totp], 5)
    }

    func testAutoMappingBitwarden() throws {
        let header = [
            "folder", "favorite", "type", "name", "notes", "fields",
            "reprompt", "login_uri", "login_username", "login_password",
            "login_totp",
        ]
        let mapping = CSVImportFormat.bitwarden.autoMapping(for: header)
        XCTAssertEqual(mapping[.title], 3)
        XCTAssertEqual(mapping[.notes], 4)
        XCTAssertEqual(mapping[.url], 7)
        XCTAssertEqual(mapping[.username], 8)
        XCTAssertEqual(mapping[.password], 9)
        XCTAssertEqual(mapping[.totp], 10)
        // Exporter metadata columns must not become custom fields.
        let custom = CSVImportFormat.bitwarden.customFieldColumns(
            headerRow: header, mapping: mapping)
        XCTAssertTrue(custom.isEmpty)
    }

    func testAutoMappingChrome() throws {
        let header = ["name", "url", "username", "password"]
        let mapping = CSVImportFormat.chrome.autoMapping(for: header)
        XCTAssertEqual(mapping[.title], 0)
        XCTAssertEqual(mapping[.url], 1)
        XCTAssertEqual(mapping[.username], 2)
        XCTAssertEqual(mapping[.password], 3)
        XCTAssertEqual(mapping[.notes], nil)
    }

    func testAutoMappingFirefox() throws {
        let header = [
            "url", "username", "password", "httpRealm", "formUrlPath",
            "notes", "timeCreated", "timeLastUsed", "timePasswordChanged",
        ]
        let mapping = CSVImportFormat.firefox.autoMapping(for: header)
        XCTAssertEqual(mapping[.url], 0)
        XCTAssertEqual(mapping[.username], 1)
        XCTAssertEqual(mapping[.password], 2)
        XCTAssertEqual(mapping[.notes], 5)
        // Timestamps are metadata and must be ignored.
        let custom = CSVImportFormat.firefox.customFieldColumns(
            headerRow: header, mapping: mapping)
        XCTAssertEqual(custom, [3, 4]) // httpRealm, formUrlPath
    }

    // MARK: - Import into Database2

    private func makeDatabase2() throws -> Database2 {
        let db = Database2.makeNewV4(.v4)
        guard db.root is Group2 else {
            XCTFail("New database must have a Group2 root")
            throw DatabaseError.loadError(reason: .formatError(reason: "No root group"))
        }
        return db
    }

    private func makeMapper(csv: String) throws -> CSVImportMapper {
        let rows = try CSVParser.parse(csv)
        return CSVImportMapper(headerRow: rows[0], dataRows: Array(rows.dropFirst()))
    }

    func testImportApplePasswordsRowsIntoDatabase2() throws {
        let csv = """
        Title,URL,Username,Password,Notes,OTPAuth
        "Example, Inc",https://example.com,alice@example.com,s3cret,"Multi-line
        note",otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example
        ,,,,,
        """
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        let mapping = format.autoMapping(for: mapper.headerRow)

        let summary = mapper.importEntries(into: root, format: format, mapping: mapping)
        XCTAssertEqual(summary.imported, 1)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.failed, 0)

        let entry = try XCTUnwrap(root.entries.first)
        XCTAssertEqual(entry.rawTitle, "Example, Inc")
        XCTAssertEqual(entry.rawURL, "https://example.com")
        XCTAssertEqual(entry.rawUserName, "alice@example.com")
        XCTAssertEqual(entry.rawPassword, "s3cret")
        XCTAssertTrue(entry.rawNotes.contains("Multi-line"))
        XCTAssertEqual(
            entry.getField(EntryField.otp)?.value,
            "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        XCTAssertTrue(entry.getField(EntryField.otp)?.isProtected ?? false)
    }

    func testImportPasswordsAreProtected() throws {
        let csv = "name,url,username,password\nSite,https://site.test,bob,hunter2"
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        let summary = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        XCTAssertEqual(summary.imported, 1)

        let entry = try XCTUnwrap(root.entries.first)
        XCTAssertTrue(entry.getField(EntryField.password)?.isProtected ?? false)
    }

    func testImportBitwardenCSVRow() throws {
        let csv = """
        folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp
        ,,1,GitHub,work account,,0,https://github.com,octocat,s3cret,otpauth://totp/GitHub:octocat?secret=JBSWY3DPEHPK3PXP
        """
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        XCTAssertEqual(format, .bitwarden)
        let summary = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        XCTAssertEqual(summary.imported, 1)

        let entry = try XCTUnwrap(root.entries.first)
        XCTAssertEqual(entry.rawTitle, "GitHub")
        XCTAssertEqual(entry.rawUserName, "octocat")
        XCTAssertEqual(entry.rawPassword, "s3cret")
        XCTAssertEqual(entry.rawURL, "https://github.com")
        XCTAssertNotNil(entry.getField(EntryField.otp))
    }

    func testImportFirefoxCSVRow() throws {
        let csv = """
        url,username,password,httpRealm,formUrlPath,notes,timeCreated,timeLastUsed,timePasswordChanged
        https://mozilla.org,fox,s3cret,moz,/login,a note,1700000000,1700000001,1700000002
        """
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        XCTAssertEqual(format, .firefox)
        let summary = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        XCTAssertEqual(summary.imported, 1)

        let entry = try XCTUnwrap(root.entries.first)
        XCTAssertEqual(entry.rawTitle, "") // Firefox has no title column
        XCTAssertEqual(entry.rawURL, "https://mozilla.org")
        XCTAssertEqual(entry.rawUserName, "fox")
        XCTAssertEqual(entry.rawPassword, "s3cret")
        XCTAssertEqual(entry.getField("httpRealm")?.value, "moz")
        XCTAssertNil(entry.getField("timeCreated")) // metadata ignored
    }

    func testImportInvalidTOTPKeptAsProtectedCustomField() throws {
        let csv = "Title,URL,Username,Password,Notes,OTPAuth\nT,https://t.test,u,p,,not-a-valid-uri"
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        _ = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        let entry = try XCTUnwrap(root.entries.first)
        XCTAssertEqual(entry.getField("TOTP")?.value, "not-a-valid-uri")
        XCTAssertTrue(entry.getField("TOTP")?.isProtected ?? false)
    }

    func testMalformedRowsAreCountedAsFailed() throws {
        let csv = "name,url,username,password\nGood,https://g.test,u,p\nBad,row\nAlsoBad,a,b,c,d"
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        let summary = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        XCTAssertEqual(summary.imported, 1)
        XCTAssertEqual(summary.failed, 2)
        XCTAssertEqual(summary.skipped, 0)
        XCTAssertEqual(root.entries.count, 1)
    }

    func testEmptyRowsAreSkipped() throws {
        let csv = "name,url,username,password\n,,,,\nGood,https://g.test,u,p"
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let mapper = try makeMapper(csv: csv)
        let format = try XCTUnwrap(CSVImportFormat.detect(headerRow: mapper.headerRow))
        let summary = mapper.importEntries(
            into: root, format: format,
            mapping: format.autoMapping(for: mapper.headerRow))
        XCTAssertEqual(summary.imported, 1)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.failed, 0)
    }

    func testWizardModelEndToEnd() throws {
        let csv = """
        Title,URL,Username,Password,Notes,OTPAuth
        Site A,https://a.test,a,p1,
        Site B,https://b.test,b,p2,
        """
        let model = try CSVImportWizardModel(fileName: "export.csv", csvText: csv)
        XCTAssertEqual(model.detectedFormat, .applePasswords)
        XCTAssertEqual(model.dataRows.count, 2)
        XCTAssertEqual(model.importableRowCount, 2)
        XCTAssertFalse(model.previewRows().isEmpty)

        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let summary = model.importEntries(into: root)
        XCTAssertEqual(summary.imported, 2)
        XCTAssertEqual(model.summary, summary)
        XCTAssertEqual(root.entries.count, 2)
    }

    func testWizardModelRejectsHeaderOnlyCSV() {
        XCTAssertThrowsError(
            try CSVImportWizardModel(fileName: "h.csv", csvText: "name,url,username,password")
        ) { error in
            guard case CSVParser.ParserError.emptyFile = error else {
                return XCTFail("Expected emptyFile, got \(error)")
            }
        }
    }

    func testWizardModelManualFormatOverride() throws {
        // Chrome-style header without OTPAuth: ambiguous between Chrome and
        // Firefox? No — Chrome wins by required-header count. Force a truly
        // ambiguous header and verify manual override applies Firefox mapping.
        let csv = "url,username,password\nhttps://f.test,fox,s3cret"
        let model = try CSVImportWizardModel(fileName: "f.csv", csvText: csv)
        XCTAssertNil(model.detectedFormat)
        model.applyAutoMapping(for: .firefox)
        XCTAssertEqual(model.mapping[.url], 0)
        XCTAssertEqual(model.mapping[.username], 1)
        XCTAssertEqual(model.mapping[.password], 2)

        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let summary = model.importEntries(into: root)
        XCTAssertEqual(summary.imported, 1)
        XCTAssertEqual(root.entries.first?.rawURL, "https://f.test")
    }
}
