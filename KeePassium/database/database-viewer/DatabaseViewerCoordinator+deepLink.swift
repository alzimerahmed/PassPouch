//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib

extension DatabaseViewerCoordinator {
    /// Copies the password of the entry with the given UUID (in the currently
    /// open database) to the clipboard, with the usual auto-clear timeout.
    /// Used by widget deep links and the CopyPassword App Intent.
    ///
    /// Security: works only on the already-unlocked database; never decrypts
    /// anything itself and never exposes the password in logs.
    func copyPasswordForDeepLink(entryUUID: UUID) {
        guard let entry = Self.findEntry(withUUID: entryUUID, in: _database.root) else {
            Diag.warning("Deep-link entry not found in open database [uuid: \(entryUUID.uuidString)]")
            _presenterForModals.showErrorAlert(
                NSLocalizedString(
                    "[DeepLink/EntryNotFound/message] The entry is not in the open database.",
                    value: "The entry is not in the open database.",
                    comment: "Deep-link error: entry UUID is not in the open database"),
                title: NSLocalizedString(
                    "[DeepLink/EntryNotFound/title] Entry not found",
                    value: "Entry not found",
                    comment: "Deep-link error title"))
            return
        }
        let password = entry.resolvedPassword
        guard password.isNotEmpty else {
            Diag.warning("Deep-link entry has no password [uuid: \(entryUUID.uuidString)]")
            return
        }
        // Security: never copy to the clipboard without an explicit user
        // confirmation — deep links and App Intents can arrive from outside
        // (widget taps, redirects), so the copy must be user-approved.
        let confirmationAlert = UIAlertController(
            title: entry.resolvedTitle,
            message: NSLocalizedString(
                "[DeepLink/CopyConfirm/message] Copy the password of this entry to the clipboard?",
                value: "Copy the password of this entry to the clipboard?",
                comment: "Confirmation before copying a password via deep link/App Intent"),
            preferredStyle: .alert)
        confirmationAlert.addAction(UIAlertAction(
            title: LString.actionCancel,
            style: .cancel))
        confirmationAlert.addAction(UIAlertAction(
            title: LString.actionCopy,
            style: .default) { [weak self] _ in
                self?.copyToClipboard(password)
            })
        _presenterForModals.present(confirmationAlert, animated: true)
    }

    private func copyToClipboard(_ password: String) {
        Clipboard.general.copyWithTimeout(password)
        HapticFeedback.play(.copiedToClipboard)
        _presenterForModals.makeToast(
            LString.titleCopiedToClipboard,
            duration: 1.0,
            position: .center,
            image: .symbol(.docOnDoc))
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: LString.titleCopiedToClipboard)
        }
    }

    private static func findEntry(withUUID uuid: UUID, in group: Group) -> Entry? {
        if let entry = group.entries.first(where: { $0.uuid == uuid }) {
            return entry
        }
        for subgroup in group.groups {
            if let entry = findEntry(withUUID: uuid, in: subgroup) {
                return entry
            }
        }
        return nil
    }
}
