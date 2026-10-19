//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib

extension MainCoordinator {
    /// Observes App Intent requests (CopyPasswordIntent runs in the app
    /// process but has no reference to the coordinator tree).
    func _setupAppIntentObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCopyPasswordRequest(_:)),
            name: DeepLinkOpener.copyPasswordNotification,
            object: nil)
    }

    @objc
    private func handleCopyPasswordRequest(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let uuidString = userInfo["entryUUID"] as? String,
            let entryUUID = UUID(uuidString: uuidString)
        else {
            Diag.warning("App intent requested password copy without a valid entry UUID")
            return
        }
        Diag.info("App intent: copy password for entry [uuid: \(entryUUID.uuidString)]")
        _databaseViewerCoordinator?.copyPasswordForDeepLink(entryUUID: entryUUID)
    }

    /// Handles `passpouch://entry/<uuid>` deep links (widget taps).
    /// If a database is unlocked, its password is copied to the clipboard
    /// (with auto-clear timeout). If not, the app simply opens to the
    /// unlock/database-picker screen — no decryption is performed here.
    func handleEntryDeepLink(_ entryUUID: UUID) {
        guard let databaseViewerCoordinator = _databaseViewerCoordinator else {
            Diag.info("Deep link to entry ignored: database is locked or not open")
            return
        }
        databaseViewerCoordinator.copyPasswordForDeepLink(entryUUID: entryUUID)
    }
}
