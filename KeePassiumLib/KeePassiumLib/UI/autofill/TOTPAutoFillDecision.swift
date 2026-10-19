//  PassPouch — Feature: Autofill Modernization (Phase 7)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation

/// Pure decision logic for serving a TOTP code alongside an AutoFill
/// credential fill (Phase 7, gap #3).
///
/// iOS provides no API to return a password and a one-time code in a single
/// AutoFill completion; the only mechanism is copying the OTP to the
/// clipboard at the moment the user confirms the credential. This type
/// centralizes that decision so it can be unit-tested.
///
/// Note on the "explicit confirmation before clipboard write" rule
/// (Phase 6 review lesson): in the AutoFill flow the user has *just*
/// explicitly picked the credential in the extension UI, which is the
/// confirmation. Silent clipboard writes remain forbidden for deep links,
/// App Intents and widgets; AutoFill selection is an explicit user action.
public enum TOTPAutoFillDecision: Equatable {
    /// Copy the OTP to the clipboard (with auto-clear timeout) and return
    /// the credentials.
    case copyOTPAndReturn
    /// Return the credentials without touching the clipboard.
    case returnOnly
    /// OTP copy is desired but impossible without UI (no-UI quick-type
    /// path); the request must be re-routed to the extension UI.
    case requireUIForOTPCopy

    /// Decide how to serve the OTP for a credentials AutoFill request.
    ///
    /// - Parameters:
    ///   - isOTPCopyEnabled: user setting "copy TOTP on AutoFill".
    ///   - hasTOTP: whether the selected entry has a valid TOTP generator.
    ///   - hasUI: whether the extension is showing its UI (user explicitly
    ///     interacted with it). In the no-UI quick-type path there is no
    ///     user gesture at this moment.
    public static func decide(
        isOTPCopyEnabled: Bool,
        hasTOTP: Bool,
        hasUI: Bool
    ) -> TOTPAutoFillDecision {
        guard isOTPCopyEnabled, hasTOTP else {
            return .returnOnly
        }
        if hasUI {
            return .copyOTPAndReturn
        }
        // No-UI path: writing the clipboard without any user interaction
        // with our UI is not acceptable (nothing explicit happened yet for
        // the OTP itself); route through the extension UI instead.
        return .requireUIForOTPCopy
    }
}
