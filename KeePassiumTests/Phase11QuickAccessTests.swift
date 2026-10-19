//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

/// Phase 11d (ADR-017) tests: quick-access pure logic — filtering,
/// entry mapping, TOTP presence flag, and lock-state clearing.
final class Phase11QuickAccessTests: XCTestCase {
    // MARK: - Helpers

    private func makeDatabase() throws -> (Database2, Group2) {
        let db = Database2.makeNewV4(.v4)
        let root = try XCTUnwrap(db.root as? Group2)
        return (db, root)
    }

    private func makeEntry(
        in group: Group2,
        title: String,
        userName: String = "user",
        password: String,
        timeOtpSecret: String? = nil
    ) -> Entry2 {
        let entry = Entry2(database: group.database)
        entry.rawTitle = title
        entry.rawUserName = userName
        entry.rawPassword = password
        if let timeOtpSecret {
            entry.setField(name: EntryField.timeOtpSecret, value: timeOtpSecret, isProtected: true)
        }
        group.add(entry: entry)
        return entry
    }

    private func makeItem(
        title: String,
        username: String,
        password: String = "secret",
        hasTOTP: Bool = false
    ) -> QuickAccessEntry {
        return QuickAccessEntry(
            title: title,
            username: username,
            password: password,
            url: "",
            hasTOTP: hasTOTP
        )
    }

    // MARK: - Filtering

    func testEmptyQueryReturnsAllEntries() {
        let items = [
            makeItem(title: "GitHub", username: "alice"),
            makeItem(title: "GitLab", username: "bob")
        ]
        XCTAssertEqual(QuickAccessViewModel.filter(items, query: ""), items)
        XCTAssertEqual(QuickAccessViewModel.filter(items, query: "   "), items)
    }

    func testQueryMatchesTitle() {
        let items = [
            makeItem(title: "GitHub", username: "alice"),
            makeItem(title: "Email", username: "bob")
        ]
        XCTAssertEqual(
            QuickAccessViewModel.filter(items, query: "git").map(\.title),
            ["GitHub"])
    }

    func testQueryMatchesUsername() {
        let items = [
            makeItem(title: "GitHub", username: "alice"),
            makeItem(title: "Email", username: "bob")
        ]
        XCTAssertEqual(
            QuickAccessViewModel.filter(items, query: "BOB").map(\.username),
            ["bob"])
    }

    func testQueryIsCaseInsensitive() {
        let items = [makeItem(title: "GitHub", username: "alice")]
        XCTAssertEqual(
            QuickAccessViewModel.filter(items, query: "GITHUB").count, 1)
        XCTAssertEqual(
            QuickAccessViewModel.filter(items, query: "ALICE").count, 1)
    }

    func testNoMatchReturnsEmpty() {
        let items = [makeItem(title: "GitHub", username: "alice")]
        XCTAssertTrue(QuickAccessViewModel.filter(items, query: "nomatch").isEmpty)
    }

    // MARK: - Entry mapping

    func testMapEntriesExtractsFields() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "Bank",
            userName: "carol",
            password: "p4ssw0rd")
        entry.rawURL = "https://bank.example"

        let items = QuickAccessViewModel.mapEntries([entry])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Bank")
        XCTAssertEqual(items[0].username, "carol")
        XCTAssertEqual(items[0].password, "p4ssw0rd")
        XCTAssertEqual(items[0].url, "https://bank.example")
        XCTAssertFalse(items[0].hasTOTP)
    }

    func testMapEntriesDetectsTOTP() throws {
        let (_, root) = try makeDatabase()
        _ = makeEntry(
            in: root,
            title: "TOTP Site",
            password: "secret",
            timeOtpSecret: "JBSWY3DPEHPK3PXP")
        let items = QuickAccessViewModel.mapEntries(
            QuickAccessViewModel.entries(in: root.database))
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].hasTOTP)
    }

    func testEntriesInDatabaseWalksGroups() throws {
        let (_, root) = try makeDatabase()
        _ = makeEntry(in: root, title: "Top", password: "a")
        let subGroup = Group2(database: root.database)
        subGroup.name = "Sub"
        root.add(group: subGroup)
        _ = makeEntry(in: subGroup, title: "Nested", password: "b")

        let items = QuickAccessViewModel.mapEntries(
            QuickAccessViewModel.entries(in: root.database))
        XCTAssertEqual(Set(items.map(\.title)), ["Top", "Nested"])
    }

    // MARK: - Lock-state clearing

    func testClearEmptiesEntriesAndQuery() {
        let viewModel = QuickAccessViewModel()
        viewModel.entries = [makeItem(title: "GitHub", username: "alice")]
        viewModel.query = "git"

        viewModel.clear()

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertEqual(viewModel.query, "")
        XCTAssertTrue(viewModel.filteredEntries.isEmpty)
    }

    func testSetDatabasePopulatesAndClearResets() throws {
        let (_, root) = try makeDatabase()
        _ = makeEntry(in: root, title: "Bank", password: "x")

        let viewModel = QuickAccessViewModel()
        viewModel.setDatabase(root.database)
        XCTAssertEqual(viewModel.entries.count, 1)

        viewModel.clear()
        XCTAssertTrue(viewModel.entries.isEmpty)
    }
}
