//  PassPouch — Feature: Autofill Modernization (Phase 7)
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

import AuthenticationServices
@testable import KeePassiumLib
import XCTest

/// Tests for the AutoFill modernization pure logic (Phase 7, gaps #3, #6, #13).
final class Phase7AutofillTests: XCTestCase {

    // MARK: - Gap #3: TOTP autofill decision

    func testTOTPDecision_copyWhenEnabledAndPresentAndUI() {
        XCTAssertEqual(
            TOTPAutoFillDecision.decide(isOTPCopyEnabled: true, hasTOTP: true, hasUI: true),
            .copyOTPAndReturn
        )
    }

    func testTOTPDecision_returnOnlyWhenSettingDisabled() {
        XCTAssertEqual(
            TOTPAutoFillDecision.decide(isOTPCopyEnabled: false, hasTOTP: true, hasUI: true),
            .returnOnly
        )
    }

    func testTOTPDecision_returnOnlyWhenEntryHasNoTOTP() {
        XCTAssertEqual(
            TOTPAutoFillDecision.decide(isOTPCopyEnabled: true, hasTOTP: false, hasUI: true),
            .returnOnly
        )
    }

    func testTOTPDecision_requireUIInNoUIQuickTypePath() {
        // No-UI quick-type fill must not write the clipboard without any
        // user interaction; the request is routed to the extension UI.
        XCTAssertEqual(
            TOTPAutoFillDecision.decide(isOTPCopyEnabled: true, hasTOTP: true, hasUI: false),
            .requireUIForOTPCopy
        )
    }

    // MARK: - Gap #6: QuickType service identifiers (URL + domain)

    func testDomainIdentifiers_fromSimpleURL() {
        let url = URL(string: "https://example.com/login")!
        let identifiers = QuickTypeAutoFillStorage.makeDomainServiceIdentifiers(fromURLs: [url])
        XCTAssertEqual(identifiers.count, 1)
        XCTAssertEqual(identifiers.first?.type, .domain)
        XCTAssertEqual(identifiers.first?.identifier, "example.com")
    }

    func testDomainIdentifiers_stripWWWAndDeduplicate() {
        let urls = [
            URL(string: "https://www.example.com/a")!,
            URL(string: "https://example.com/b")!,
            URL(string: "https://shop.example.com/c")!,
        ]
        let identifiers = QuickTypeAutoFillStorage.makeDomainServiceIdentifiers(fromURLs: urls)
        XCTAssertEqual(
            identifiers.map(\.identifier),
            ["example.com", "shop.example.com"]
        )
    }

    func testDomainIdentifiers_ignoreURLsWithoutHost() {
        let urls = [URL(string: "file:///local/path")!]
        let identifiers = QuickTypeAutoFillStorage.makeDomainServiceIdentifiers(fromURLs: urls)
        XCTAssertTrue(identifiers.isEmpty)
    }

    func testDomainIdentifiers_emptyInput() {
        XCTAssertTrue(
            QuickTypeAutoFillStorage.makeDomainServiceIdentifiers(fromURLs: []).isEmpty
        )
    }

    // MARK: - Gap #6: QuickType record round-trip (identity payload key)

    func testQuickTypeRecord_roundTrip() throws {
        // QuickTypeAutoFillRecord's full initializer is private; build the
        // wire-format identifier directly (v0:provider:descriptor:uuid).
        let itemID = UUID(uuidString: "DEADBEEF-0000-4000-8000-000000000000")!
        let identifier = "0:com.apple.FileProvider.LocalStorage:some-descriptor:\(itemID.uuidString)"
        let parsed = try XCTUnwrap(QuickTypeAutoFillRecord.parse(identifier))
        XCTAssertEqual(parsed.fileProvider, .localStorage)
        XCTAssertEqual(parsed.fileDescriptor, "some-descriptor")
        XCTAssertEqual(parsed.itemID, itemID)
    }

    func testQuickTypeRecord_parseRejectsGarbage() {
        XCTAssertNil(QuickTypeAutoFillRecord.parse("not-a-record"))
        XCTAssertNil(QuickTypeAutoFillRecord.parse("0:localStorage:desc:not-a-uuid"))
        XCTAssertNil(QuickTypeAutoFillRecord.parse("9:localStorage:desc:DEADBEEF-0000-4000-8000-000000000000"))
    }
}
