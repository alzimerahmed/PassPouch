//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import KeePassiumLib

#if targetEnvironment(macCatalyst)
/// WatchConnectivity is unavailable on Mac Catalyst; provide a no-op facade
/// so the call sites (DatabaseViewerCoordinator, settings screen) compile
/// unchanged. The watch companion is iOS-only.
final class WatchConnectivityService {
    static let shared = WatchConnectivityService()

    var currentDatabaseFileForSettings: DatabaseFile? {
        return nil
    }

    func activate() {}
    func databaseDidUnlock(_ databaseFile: DatabaseFile) {}
    func databaseDidLock() {}
    func refreshSnapshot() {}
}
#else
import WatchConnectivity
/// iOS side of the WatchConnectivity pipeline (ADR-013).
///
/// Behavior:
/// - when a database is unlocked, sends a sanitized snapshot of the
///   explicitly selected entries to the paired watch (if sharing is enabled);
/// - when the database locks/closes, tells the watch to wipe its snapshot;
/// - answers the watch's snapshot requests the same way.
///
/// No database file, no master key and no unselected entry data ever leaves
/// the phone. The snapshot travels over the system-encrypted Bluetooth
/// WatchConnectivity channel and is stored on the watch in its own keychain.
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()

    private var currentDatabaseFile: DatabaseFile?

    /// Database currently unlocked in the main app, for the settings screen.
    var currentDatabaseFileForSettings: DatabaseFile? {
        return currentDatabaseFile
    }

    // MARK: - Lifecycle

    /// Idempotent; safe to call from multiple entry points.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState != .activated else {
            return
        }
        session.delegate = self
        session.activate()
    }

    // MARK: - Database state hooks (called from DatabaseViewerCoordinator)

    func databaseDidUnlock(_ databaseFile: DatabaseFile) {
        activate()
        currentDatabaseFile = databaseFile
        sendSnapshotIfNeeded()
    }

    func databaseDidLock() {
        currentDatabaseFile = nil
        sendLockMessage()
    }

    /// Re-sends the snapshot after the user changes sharing settings.
    func refreshSnapshot() {
        sendSnapshotIfNeeded()
    }

    // MARK: - Sending

    private func makeSnapshot() -> WatchSnapshot? {
        guard let databaseFile = currentDatabaseFile else {
            return nil
        }
        let store = WatchSelectionStore.shared
        guard store.isSharingEnabled else {
            return nil
        }
        return WatchSnapshotBuilder.buildSnapshot(
            database: databaseFile.database,
            databaseName: databaseFile.visibleFileName,
            selectedEntryIDs: store.selectedEntryIDs
        )
    }

    private func sendSnapshotIfNeeded() {
        guard let snapshot = makeSnapshot() else {
            // Nothing to share (locked, disabled or empty selection):
            // make sure the watch does not keep a stale snapshot.
            sendLockMessage()
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else {
            Diag.error("Failed to encode watch snapshot")
            return
        }
        send(message: [WatchMessage.snapshotData: data])
    }

    private func sendLockMessage() {
        send(message: [WatchMessage.locked: true])
    }

    private func send(message: [String: Any]) {
        activate()
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired else {
            return
        }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                Diag.warning("Watch message failed, falling back to context [message: \(error.localizedDescription)]")
                session.updateApplicationContext(message)
            }
        } else {
            // Delivered when the watch next becomes reachable.
            session.updateApplicationContext(message)
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Diag.warning("WCSession activation failed [message: \(error.localizedDescription)]")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Required on iOS; nothing to do for a single-session app.
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the session is ready for the next watch connection.
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard message[WatchMessage.snapshotRequest] as? Bool == true else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.sendSnapshotIfNeeded()
        }
    }
}
#endif
