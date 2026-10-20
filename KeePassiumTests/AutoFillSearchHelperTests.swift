//  PassPouch — Testing Foundation (Phase 5)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import AuthenticationServices
@testable import KeePassiumLib
import XCTest

/// Tests for the AutoFill credential matching logic (SearchHelper's AutoFill
/// extension): URL/domain similarity scoring, exact-match ranking, and
/// TOTP-aware filtering. The matching sources are compiled into this test
/// target via pbxproj membership exceptions.
final class AutoFillSearchHelperTests: XCTestCase {
    private var database: Database2!
    private var webGroup: Group2?

    override func setUp() {
        super.setUp()
        database = Database2.makeNewV4(.v4)
        guard let root = database.root as? Group2 else {
            XCTFail("New database must have a Group2 root")
            return
        }
        let group = Group2(database: database)
        group.name = "Web"
        root.add(group: group)
        webGroup = group
    }

    @discardableResult
    private func addEntry(
        title: String,
        url: String? = nil,
        userName: String = "alice",
        password: String = "s3cr3t!",
        notes: String = "",
        totp: String? = nil
    ) -> Entry2 {
        let entry = Entry2(database: database)
        entry.uuid = UUID()
        entry.setField(name: EntryField.title, value: title)
        entry.setField(name: EntryField.userName, value: userName)
        entry.setField(name: EntryField.password, value: password, isProtected: true)
        if let url {
            entry.setField(name: EntryField.url, value: url)
        }
        if !notes.isEmpty {
            entry.setField(name: EntryField.notes, value: notes)
        }
        if let totp {
            entry.setField(name: EntryField.otp, value: totp)
        }
        webGroup?.add(entry: entry)
        return entry
    }

    private func find(
        serviceIdentifier identifier: String,
        type: ASCredentialServiceIdentifier.IdentifierType = .domain,
        allowOnly itemKind: AutoFillItemKind? = nil
    ) -> FuzzySearchResults {
        let serviceID = ASCredentialServiceIdentifier(identifier: identifier, type: type)
        return SearchHelper().find(
            database: database,
            serviceIdentifiers: [serviceID],
            passkeyRelyingParty: nil,
            allowOnly: itemKind)
    }

    // MARK: - Exact matching

    func testExactURLMatchIsPerfect() {
        let entry = addEntry(title: "Example", url: "https://example.com/login")
        let results = find(
            serviceIdentifier: "https://example.com/login",
            type: .URL)
        XCTAssertTrue(results.perfectMatch === entry, "Identical URL must be a perfect match")
    }

    func testDomainMatchIsExact() {
        let entry = addEntry(title: "Example", url: "https://example.com")
        let results = find(serviceIdentifier: "example.com")
        XCTAssertTrue(results.perfectMatch === entry, "Host equal to the service domain must be exact")
    }

    func testCaseInsensitiveDomainMatch() {
        let entry = addEntry(title: "Example", url: "https://EXAMPLE.com")
        let results = find(serviceIdentifier: "example.com")
        XCTAssertTrue(results.perfectMatch === entry, "Matching must be case-insensitive")
    }

    // MARK: - Fuzzy matching

    func testSubdomainEntryIsPartialMatchForMainDomain() {
        let entry = addEntry(title: "Example", url: "https://login.example.com/signin")
        let results = find(serviceIdentifier: "example.com")
        XCTAssertNil(results.perfectMatch, "Subdomain must not be a perfect match")
        XCTAssertTrue(
            results.partialMatch.contains { $0.scoredItems.contains { $0.item === entry } },
            "Subdomain of the same main domain must be a partial match")
    }

    func testTitleMatchIsPartial() {
        let entry = addEntry(title: "example.com Portal", url: nil)
        let results = find(serviceIdentifier: "example.com")
        XCTAssertNil(results.perfectMatch, "Title-only match must not be perfect")
        XCTAssertTrue(
            results.partialMatch.contains { $0.scoredItems.contains { $0.item === entry } },
            "Entry whose title contains the domain must be a partial match")
    }

    func testUnrelatedSiteYieldsNoResults() {
        addEntry(title: "Example", url: "https://example.com")
        let results = find(serviceIdentifier: "unrelated.org")
        XCTAssertTrue(results.isEmpty, "Unrelated domain must not match")
    }

    func testMalformedServiceIdentifierYieldsNoResultsAndDoesNotCrash() {
        addEntry(title: "Example", url: "https://example.com")
        let results = find(serviceIdentifier: "https://", type: .URL)
        XCTAssertTrue(results.isEmpty, "Malformed URL must be handled gracefully")
    }

    // MARK: - Ranking

    func testExactMatchRanksAbovePartialMatch() {
        let partialEntry = addEntry(title: "Example", url: "https://login.example.com")
        let exactEntry = addEntry(title: "Example Direct", url: "https://example.com")
        let results = find(serviceIdentifier: "example.com")
        XCTAssertTrue(results.perfectMatch === exactEntry, "Exact host must outrank subdomain")
        XCTAssertFalse(results.perfectMatch === partialEntry)
    }

    // MARK: - TOTP / item kind filtering

    func testOTPKindFilterReturnsOnlyTOTPEntries() {
        let plainEntry = addEntry(title: "Plain", url: "https://example.com")
        let totpEntry = addEntry(
            title: "With OTP",
            url: "https://example.com",
            totp: "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        let results = find(serviceIdentifier: "example.com", allowOnly: .otp)
        let matchedItems = results.exactMatch + results.partialMatch
        let matchedEntries = matchedItems.flatMap { $0.scoredItems.compactMap { $0.item as? Entry2 } }
        XCTAssertTrue(matchedEntries.contains { $0 === totpEntry }, "TOTP entry must pass the OTP filter")
        XCTAssertFalse(
            matchedEntries.contains { $0 === plainEntry },
            "Entry without TOTP must be filtered out")
    }

    func testPasskeyKindFilterExcludesPasswordOnlyEntries() {
        addEntry(title: "Plain", url: "https://example.com")
        let results = find(serviceIdentifier: "example.com", allowOnly: .passkey)
        XCTAssertTrue(results.isEmpty, "Password-only entry must not match a passkey request")
    }
}
