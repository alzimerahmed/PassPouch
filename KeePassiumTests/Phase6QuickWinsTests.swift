//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.
//
//  NOTE: this file must be a member of the KeePassiumTests target. The
//  KeePassiumTests folder is a PBXFileSystemSynchronizedRootGroup, so new
//  files in it are picked up automatically at build time — no pbxproj edit
//  needed.

import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

/// Tests for the otpauth:// bulk import parser (Phase 6, gap #15).
final class Phase6QuickWinsTests: XCTestCase {

    // MARK: - Single valid URI

    func testParseSingleURI() throws {
        let payload = "otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let result = OtpauthBulkImporter.parse(payload: payload)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.invalidLineCount, 0)
        XCTAssertEqual(result.items.first?.issuer, "Example")
        XCTAssertEqual(result.items.first?.accountName, "alice@example.com")
    }

    // MARK: - Multiple URIs separated by newlines

    func testParseMultipleURIs() {
        let payload = """
        otpauth://totp/GitHub:octocat?secret=JBSWY3DPEHPK3PXP&issuer=GitHub
        otpauth://totp/Amazon:jane?secret=JBSWY3DPEHPK3PXQ&issuer=Amazon

        """
        let result = OtpauthBulkImporter.parse(payload: payload)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.invalidLineCount, 0)
        XCTAssertEqual(result.items[0].issuer, "GitHub")
        XCTAssertEqual(result.items[1].accountName, "jane")
    }

    // MARK: - Invalid lines are counted, not fatal

    func testParseSkipsInvalidLines() {
        let payload = """
        not-a-uri
        otpauth://totp/Bad?secret=!!!notbase32!!!
        otpauth://totp/Good:me?secret=JBSWY3DPEHPK3PXP&issuer=Good
        """
        let result = OtpauthBulkImporter.parse(payload: payload)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.invalidLineCount, 2)
    }

    // MARK: - Empty payload

    func testParseEmptyPayload() {
        let result = OtpauthBulkImporter.parse(payload: "  \n \n")
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.invalidLineCount, 0)
    }

    // MARK: - Label parsing

    func testParseLabelWithoutIssuer() {
        let (issuer, account) = OtpauthBulkImporter.parseLabel(
            from: "otpauth://totp/alice@example.com?secret=JBSWY3DPEHPK3PXP")
        XCTAssertEqual(issuer, "")
        XCTAssertEqual(account, "alice@example.com")
    }

    func testParseLabelQueryIssuerWins() {
        let (issuer, account) = OtpauthBulkImporter.parseLabel(
            from: "otpauth://totp/PathIssuer:alice?secret=JBSWY3DPEHPK3PXP&issuer=QueryIssuer")
        XCTAssertEqual(issuer, "QueryIssuer")
        XCTAssertEqual(account, "alice")
    }

    func testParseLabelAccountMayContainColon() {
        let (issuer, account) = OtpauthBulkImporter.parseLabel(
            from: "otpauth://totp/MyCorp:dept:alice?secret=JBSWY3DPEHPK3PXP")
        XCTAssertEqual(issuer, "MyCorp")
        XCTAssertEqual(account, "dept:alice")
    }

    // MARK: - Validation reuses the lib's TOTP validator

    func testParsedItemsAreValidTOTPURIs() {
        let payload = "otpauth://totp/X:a?secret=JBSWY3DPEHPK3PXP&issuer=X"
        let result = OtpauthBulkImporter.parse(payload: payload)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertTrue(TOTPGeneratorFactory.isValidURI(result.items[0].uri))
    }

    // MARK: - Widget shared data snapshots (metadata only, no secrets)

    func testWidgetSnapshotCodableRoundTrip() throws {
        let snapshot = WidgetRecentEntrySnapshot(
            title: "Example",
            userName: "alice",
            entryUUID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            databaseName: "Vault.kdbx",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode([snapshot])
        let decoded = try JSONDecoder().decode([WidgetRecentEntrySnapshot].self, from: data)
        XCTAssertEqual(decoded, [snapshot])
    }
}
