//  PassPouch — Password Manager (watchOS companion)
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
import WatchConnectivity

/// watchOS side of the WatchConnectivity pipeline (ADR-013). Receives the
/// sanitized snapshot from the phone and stores it in the watch's own
/// keychain; wipes it when the phone reports a database lock. The snapshot is
/// never written to a plain file.
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Asks the phone for a fresh snapshot (answered only if a database is
    /// unlocked and sharing is enabled there).
    func requestSnapshot() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            return
        }
        session.sendMessage(
            [WatchMessage.snapshotRequest: true],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            requestSnapshot()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message: message)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handle(message: applicationContext)
    }

    private func handle(message: [String: Any]) {
        if message[WatchMessage.locked] as? Bool == true {
            SnapshotStore.clear()
            return
        }
        if let data = message[WatchMessage.snapshotData] as? Data {
            SnapshotStore.save(data: data)
        }
    }
}
