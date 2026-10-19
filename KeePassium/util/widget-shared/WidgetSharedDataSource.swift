//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib
import WidgetKit

/// Snapshot of a recently viewed entry, safe to share with the widget extension.
/// Contains **metadata only** (title, user name, UUID) — never passwords, TOTP
/// seeds or other secrets. Secrets stay in the encrypted database and keychain.
struct WidgetRecentEntrySnapshot: Codable, Equatable {
    let title: String
    let userName: String
    let entryUUID: UUID
    let databaseName: String
    let timestamp: Date
}

/// Snapshot of a recently opened database, safe to share with the widget
/// extension (file name only — no paths, no keys).
struct WidgetRecentDatabaseSnapshot: Codable, Equatable {
    let name: String
    let timestamp: Date
}

/// Reads/writes the app-group UserDefaults data consumed by the PassPouch
/// widget extension (`PassPouchWidgets` target). The widget reads the same
/// keys with its own copy of the Codable structs, so the format must stay
/// backward-compatible (additive changes only).
enum WidgetSharedDataSource {
    private static let recentEntriesKey = "widget.recentEntries.v1"
    private static let recentDatabasesKey = "widget.recentDatabases.v1"
    private static let maxEntries = 8
    private static let maxDatabases = 4

    static var recentEntries: [WidgetRecentEntrySnapshot] {
        get { load(key: recentEntriesKey) }
        set { save(newValue, key: recentEntriesKey) }
    }

    static var recentDatabases: [WidgetRecentDatabaseSnapshot] {
        get { load(key: recentDatabasesKey) }
        set { save(newValue, key: recentDatabasesKey) }
    }

    /// Records a viewed entry (metadata only) and refreshes the widget timeline.
    static func recordViewedEntry(_ entry: Entry, in databaseFile: DatabaseFile) {
        let snapshot = WidgetRecentEntrySnapshot(
            title: entry.resolvedTitle,
            userName: entry.resolvedUserName,
            entryUUID: entry.uuid,
            databaseName: databaseFile.visibleFileName,
            timestamp: Date.now
        )
        var entries = recentEntries.filter { $0.entryUUID != snapshot.entryUUID }
        entries.insert(snapshot, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        recentEntries = entries
        WidgetReloader.reloadAllTimelines()
    }

    /// Records an opened database (name only) and refreshes the widget timeline.
    static func recordOpenedDatabase(_ databaseFile: DatabaseFile) {
        guard !databaseFile.visibleFileName.isEmpty else { return }
        let snapshot = WidgetRecentDatabaseSnapshot(
            name: databaseFile.visibleFileName,
            timestamp: Date.now
        )
        var databases = recentDatabases.filter { $0.name != snapshot.name }
        databases.insert(snapshot, at: 0)
        if databases.count > maxDatabases {
            databases.removeLast(databases.count - maxDatabases)
        }
        recentDatabases = databases
        WidgetReloader.reloadAllTimelines()
    }
}

/// Reloads widget timelines from the app process after shared data changes.
enum WidgetReloader {
    static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension WidgetSharedDataSource {
    static func load<T: Decodable>(key: String) -> [T] {
        guard let data = UserDefaults.appGroupShared.data(forKey: key) else {
            return []
        }
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            Diag.warning("Failed to decode widget shared data [key: \(key)]")
            return []
        }
    }

    static func save<T: Encodable>(_ value: [T], key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.appGroupShared.set(data, forKey: key)
        } catch {
            Diag.warning("Failed to encode widget shared data [key: \(key)]")
        }
    }
}
