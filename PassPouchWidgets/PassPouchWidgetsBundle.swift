//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import SwiftUI
import WidgetKit

/// PassPouch widget extension bundle.
///
/// Security note (v1 tradeoff): the widget shows recently viewed entry names
/// and user names from the shared app-group UserDefaults — **never passwords
/// or TOTP seeds**. Live decryption of the KDBX database inside the widget
/// process would require sharing the master key (or keychain-derived key)
/// with the extension, which is not acceptable for v1. Tapping an entry
/// deep-links into the app (`passpouch://entry/<uuid>`), where the password
/// is copied only if the database is already unlocked.
@main
struct PassPouchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecentEntriesWidget()
    }
}
