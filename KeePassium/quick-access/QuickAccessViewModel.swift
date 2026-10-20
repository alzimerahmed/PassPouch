//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
import KeePassiumLib

/// Lazily builds and caches a TOTP generator from a snapshot of the entry's
/// OTP-related fields. Construction happens on first use (copy/refresh), not
/// during entry mapping — mapping hundreds of entries must not parse every
/// OTP configuration upfront.
final class QuickAccessTOTPProvider {
    private let fields: [EntryField]
    private var cachedGenerator: TOTPGenerator?

    init(fields: [EntryField]) {
        self.fields = fields
    }

    /// Live TOTP code, generated fresh on every call. Returns nil when the
    /// captured fields do not yield a usable TOTP configuration.
    func currentCode() -> String? {
        if cachedGenerator == nil {
            cachedGenerator = TOTPGeneratorFactory.makeGenerator(from: fields)
        }
        return cachedGenerator?.generate()
    }
}

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
    /// Precomputed lowercase copies for cheap case-insensitive filtering.
    let lowercasedTitle: String
    let lowercasedUsername: String
    private let totpProvider: QuickAccessTOTPProvider?

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        password: String,
        url: String,
        hasTOTP: Bool,
        totpProvider: QuickAccessTOTPProvider? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.hasTOTP = hasTOTP
        self.lowercasedTitle = title.lowercased()
        self.lowercasedUsername = username.lowercased()
        self.totpProvider = totpProvider
    }

    /// Live TOTP code, generated on demand via the existing KeePassiumLib
    /// `TOTPGeneratorFactory` pipeline. Returns nil when the entry has no
    /// usable TOTP configuration.
    func currentTOTPCode() -> String? {
        return totpProvider?.currentCode()
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
    /// Entries matching the current query, updated with a short debounce so
    /// fast typing does not re-filter the whole list on every keystroke.
    @Published private(set) var filteredEntries: [QuickAccessEntry] = []

    private var filterTask: Task<Void, Never>?
    /// Debounce window for query filtering, in seconds.
    private static let filterDebounceSeconds: UInt64 = 200_000_000

    init() {
        filteredEntries = []
    }

    /// Populate from the currently unlocked database. Only called while a
    /// database session is unlocked; the view model never reads files itself.
    func setDatabase(_ database: Database) {
        entries = Self.mapEntries(Self.entries(in: database))
        refilterNow()
    }

    /// Clear all state — called when the database locks. After this, the
    /// quick-access window shows an empty list and holds no secrets.
    func clear() {
        entries = []
        query = ""
        refilterNow()
    }

    func setQuery(_ newQuery: String) {
        query = newQuery
        filterTask?.cancel()
        filterTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.filterDebounceSeconds)
            guard !Task.isCancelled else { return }
            self?.refilterNow()
        }
    }

    private func refilterNow() {
        filterTask?.cancel()
        filterTask = nil
        filteredEntries = Self.filter(entries, query: query)
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
        let needle = trimmedQuery.lowercased()
        return entries.filter { entry in
            entry.lowercasedTitle.contains(needle)
                || entry.lowercasedUsername.contains(needle)
        }
    }

    static func mapEntries(_ entries: [Entry]) -> [QuickAccessEntry] {
        return entries.map { entry in
            // Cheap presence check for OTP-related fields; the (parsing)
            // generator is built lazily on first use via the provider.
            let hasTOTP = Self.hasOTPFields(entry)
            let provider = hasTOTP
                ? QuickAccessTOTPProvider(fields: entry.fields)
                : nil
            return QuickAccessEntry(
                id: entry.uuid,
                title: entry.resolvedTitle,
                username: entry.resolvedUserName,
                password: entry.resolvedPassword,
                url: entry.resolvedURL,
                hasTOTP: hasTOTP,
                totpProvider: provider
            )
        }
    }

    /// Cheap (no parsing) check whether the entry carries any OTP-related
    /// field with a non-empty value.
    static func hasOTPFields(_ entry: Entry) -> Bool {
        let otpFieldNames = [
            EntryField.otp,
            EntryField.totp,
            EntryField.otpConfig2Seed,
            EntryField.timeOtpSecret
        ]
        return otpFieldNames.contains { name in
            entry.getField(name)?.resolvedValue.isNotEmpty ?? false
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
