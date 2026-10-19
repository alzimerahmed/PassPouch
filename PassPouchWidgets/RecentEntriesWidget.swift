//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import SwiftUI
import WidgetKit

// Mirror of `WidgetRecentEntrySnapshot` (app target). Keep Codable fields
// identical — the app encodes these into the shared app-group UserDefaults.
struct SharedRecentEntry: Codable, Identifiable, Equatable {
    let title: String
    let userName: String
    let entryUUID: UUID
    let databaseName: String
    let timestamp: Date

    var id: UUID { entryUUID }
}

// Mirror of `WidgetRecentDatabaseSnapshot` (app target).
struct SharedRecentDatabase: Codable, Equatable {
    let name: String
    let timestamp: Date
}

enum SharedWidgetData {
    static let appGroupID = "group.com.passpouch"
    private static let recentEntriesKey = "widget.recentEntries.v1"

    static var recentEntries: [SharedRecentEntry] {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: recentEntriesKey)
        else {
            return []
        }
        return (try? JSONDecoder().decode([SharedRecentEntry].self, from: data)) ?? []
    }
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let entries: [SharedRecentEntry]
}

struct RecentEntriesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date.now, entries: sampleEntries)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(date: Date.now, entries: currentEntries(for: context)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let entry = RecentEntry(date: Date.now, entries: currentEntries(for: context))
        // Data changes are pushed by the app via WidgetCenter.reloadAllTimelines;
        // a distant-future refresh policy avoids pointless wakeups.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date.now) ?? Date.now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntries(for context: Context) -> [SharedRecentEntry] {
        let entries = SharedWidgetData.recentEntries
        if entries.isEmpty && context.isPreview {
            return sampleEntries
        }
        return entries
    }

    private var sampleEntries: [SharedRecentEntry] {
        [
            SharedRecentEntry(
                title: "Example Site",
                userName: "user@example.com",
                entryUUID: UUID(),
                databaseName: "Vault.kdbx",
                timestamp: Date.now
            ),
        ]
    }
}

struct RecentEntriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentEntriesWidget", provider: RecentEntriesProvider()) { entry in
            RecentEntriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Entries")
        .description(
            "Shows entries you recently opened in PassPouch. Passwords are never shown in the widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
