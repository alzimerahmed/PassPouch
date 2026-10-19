//  PassPouch — Feature: Autofill Modernization (Phase 7)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation

/// Pure routing decision for AutoFill "quick unlock without app launch"
/// (Phase 7, gap #13).
///
/// The AutoFill extension can serve a credential entirely in-process when a
/// master key for the requested database is already stored in the shared
/// keychain (DatabaseSettingsManager). When it is not, the request falls
/// back to the extension's own UI (database unlock inside the extension) —
/// the main app is never launched. This type centralizes the decision.
public enum QuickUnlockRoute: Equatable {
    /// Serve the credential directly in the extension process, no UI.
    case serveDirectly
    /// Open the extension's own unlock UI (biometrics/passcode/master key
    /// prompt inside the extension) — still no main-app launch.
    case unlockInExtensionUI
    /// The credential identity could not be resolved (stale QuickType
    /// record); clear stale identities and show the extension UI.
    case staleIdentity

    /// Decide how to handle a no-UI AutoFill credential request.
    ///
    /// - Parameters:
    ///   - hasParsedRecord: the credential identity's record identifier
    ///     parsed successfully into a `QuickTypeAutoFillRecord`.
    ///   - hasStoredMasterKey: a master key for the target database exists
    ///     in the shared keychain (per `DatabaseSettingsManager`).
    public static func decide(
        hasParsedRecord: Bool,
        hasStoredMasterKey: Bool
    ) -> QuickUnlockRoute {
        guard hasParsedRecord else {
            return .staleIdentity
        }
        return hasStoredMasterKey ? .serveDirectly : .unlockInExtensionUI
    }
}
