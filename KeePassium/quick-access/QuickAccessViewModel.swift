//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
import KeePassiumLib

/// Phase 11d (ADR-017): compact macOS (Catalyst) quick-access window.
///
/// Pure view-model logic: maps unlocked-database entries to lightweight
/// copyable items and filters them by a query string. No persistence of
/// secrets beyond the already-unlocked in-memory database session.
struct QuickAccessEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let username: String
    let password: String
    let url: String
    let hasTOTP: Bool
    private let totpGenerator: TOTPGenerator?

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String,
        url: String,
        hasTOTP: Bool,
        totpGenerator: TOTPGenerator? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.hasTOTP = hasTOTP
        self.totpGenerator = totpGenerator
    }

    /// Live TOTP code, generated on demand via the existing KeePassiumLib
    /// `TOTPGeneratorFactory` pipeline. Returns nil when the entry has no
    /// usable TOTP configuration.
    func currentTOTPCode() -> String? {
        return totpGenerator?.generate()
    }

    static func == (lhs: QuickAccessEntry, rhs: QuickAccessEntry) -> Bool {
        return lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.username == rhs.username
            && lhs.password == rhs.password
            && lhs.url == rhs.url
            && lhs.hasTOTP == rhs.hasTOTP
    }
}

final class QuickAccessViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var entries: [QuickAccessEntry] = []

    /// Entries matching the current query (title/username, case-insensitive
    /// contains). Empty query returns all entries.
    var filteredEntries: [QuickAccessEntry] {
        return Self.filter(entries, query: query)
    }

    /// Populate from the currently unlocked database. Only called while a
    /// database session is unlocked; the view model never reads files itself.
    func setDatabase(_ database: Database) {
        entries = Self.mapEntries(Self.entries(in: database))
    }

    /// Clear all state — called when the database locks. After this, the
    /// quick-access window shows an empty list and holds no secrets.
    func clear() {
        entries = []
        query = ""
    }

    // MARK: - Pure logic (unit-tested)

    static func filter(
        _ entries: [QuickAccessEntry],
        query: String
    ) -> [QuickAccessEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return entries
        }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(trimmedQuery)
                || entry.username.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    static func mapEntries(_ entries: [Entry]) -> [QuickAccessEntry] {
        return entries.map { entry in
            let generator = entry.totpGenerator()
            return QuickAccessEntry(
                id: entry.uuid,
                title: entry.title ?? "",
                username: entry.username ?? "",
                password: entry.password ?? "",
                url: entry.url ?? "",
                hasTOTP: generator != nil,
                totpGenerator: generator
            )
        }
    }

    /// Recursively collect all entries of the unlocked database.
    static func entries(in database: Database) -> [Entry] {
        guard let root = database.root else { return [] }
        var result: [Entry] = []
        var stack: [Group] = [root]
        while let group = stack.popLast() {
            result.append(contentsOf: group.entries)
            stack.append(contentsOf: group.groups)
        }
        return result
    }
}

/// Notifications used to keep the quick-access window in sync with the
/// main window's database session. Posted only on macOS (Catalyst).
enum QuickAccessNotifications {
    /// Object: the newly unlocked `DatabaseFile`.
    static let databaseDidUnlock =
        Notification.Name("com.passpouch.quickAccess.databaseDidUnlock")
    static let databaseDidLock =
        Notification.Name("com.passpouch.quickAccess.databaseDidLock")
}
