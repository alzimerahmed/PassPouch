//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib

extension MainCoordinator {
    /// Handles `passpouch://share/<payload>#<key>` inbound links (ADR-015).
    /// Decrypts the payload locally and shows the read-only shared-item
    /// viewer. The link (payload and key) is never logged.
    func handleShareDeepLink(_ url: URL) {
        let (payloadData, key): (Data, Data)
        do {
            (payloadData, key) = try EntrySharePayload.parseLink(url)
        } catch {
            Diag.warning("Unrecognized share link structure, ignoring")
            showErrorForSharedItem(LString.sharedItemInvalid)
            return
        }

        let payload: SharePayload
        do {
            payload = try EntrySharePayload.decrypt(payloadData, key: key)
        } catch ShareLinkError.expired {
            Diag.info("Share link is expired")
            showErrorForSharedItem(LString.sharedItemExpired)
            return
        } catch {
            // Wrong key or corrupted payload — AEAD authentication failed.
            Diag.info("Share link decryption failed")
            showErrorForSharedItem(LString.sharedItemWrongKey)
            return
        }

        Diag.info("Opening shared item viewer [fields: \(payload.fields.count)]")
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let coordinator = SharedItemCoordinator(payload: payload, router: modalRouter)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
        _rootSplitVC.present(modalRouter, animated: true, completion: nil)
    }

    private func showErrorForSharedItem(_ message: String) {
        let alert = UIAlertController(
            title: LString.sharedItemTitle,
            message: message,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LString.actionOK, style: .cancel))
        _rootSplitVC.present(alert, animated: true, completion: nil)
    }
}
