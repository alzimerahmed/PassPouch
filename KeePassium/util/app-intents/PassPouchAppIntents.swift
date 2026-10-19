//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import AppIntents
import Foundation
import KeePassiumLib

/// App Entity representing a recently viewed entry (metadata only, from the
/// shared app-group UserDefaults — same data the widget uses; no secrets).
struct RecentEntryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Entry")

    struct ID: Hashable, CustomStringConvertible {
        let uuidString: String
        var description: String { uuidString }
    }

    let id: ID
    let title: String
    let userName: String
    let databaseName: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: title), subtitle: .init(stringLiteral: userName))
    }

    static var defaultQuery = RecentEntryQuery()

    static func allRecent() -> [RecentEntryEntity] {
        WidgetSharedDataSource.recentEntries.map {
            RecentEntryEntity(
                id: ID(uuidString: $0.entryUUID.uuidString),
                title: $0.title,
                userName: $0.userName,
                databaseName: $0.databaseName)
        }
    }
}

struct RecentEntryQuery: EntityQuery {
    func entities(for identifiers: [RecentEntryEntity.ID]) async throws -> [RecentEntryEntity] {
        let all = RecentEntryEntity.allRecent()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [RecentEntryEntity] {
        RecentEntryEntity.allRecent()
    }
}

/// Opens the PassPouch app (database picker / last unlocked database).
struct OpenPassPouchIntent: AppIntent {
    static let title: LocalizedStringResource = "Open PassPouch"
    static let description = IntentDescription(
        "Opens the PassPouch password manager.",
        categoryName: "General")

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        DeepLinkOpener.openApp()
        return .result()
    }
}

/// Copies the password of a recently viewed entry to the clipboard.
///
/// Runs in the app process (openAppWhenRun = true). The password is taken
/// from the currently unlocked database only; if the database is locked,
/// the app simply opens and the user unlocks as usual — the intent never
/// decrypts anything on its own.
struct CopyPasswordIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Password"
    static let description = IntentDescription(
        "Copies the password of an entry from the unlocked database to the clipboard.",
        categoryName: "Entries")

    static let openAppWhenRun = true

    @Parameter(title: "Entry")
    var entry: RecentEntryEntity?

    func perform() async throws -> some IntentResult {
        let target = entry ?? RecentEntryEntity.allRecent().first
        guard let target else {
            DeepLinkOpener.openApp()
            return .result()
        }
        DeepLinkOpener.requestCopyPassword(uuidString: target.id.uuidString)
        return .result()
    }
}

/// Spotlight/App Shortcuts registration (iOS 17+ free adoption).
struct PassPouchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPassPouchIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)",
            ],
            shortTitle: "Open PassPouch",
            systemImageName: "key.fill")
        AppShortcut(
            intent: CopyPasswordIntent(),
            phrases: [
                "Copy password with \(.applicationName)",
                "Copy last password in \(.applicationName)",
            ],
            shortTitle: "Copy Password",
            systemImageName: "doc.on.doc")
    }
}

/// Bridges intents (which may run before/while the UI coordinator exists)
/// into the running app via the notification center.
enum DeepLinkOpener {
    static let copyPasswordNotification = Notification.Name("passpouch.copyEntryPassword")

    static func openApp() {
        // openAppWhenRun already brings the app to the foreground.
        Diag.info("App intent: open PassPouch")
    }

    static func requestCopyPassword(uuidString: String) {
        NotificationCenter.default.post(
            name: copyPasswordNotification,
            object: nil,
            userInfo: ["entryUUID": uuidString])
    }
}
