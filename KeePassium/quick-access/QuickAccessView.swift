//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import KeePassiumLib
import SwiftUI

/// Phase 11d (ADR-017): quick-access window content — search field, entry
/// list, and per-entry copy actions. Strings follow the LString pattern
/// (ADR-011): en strings live in code via NSLocalizedString.
struct QuickAccessView: View {
    @ObservedObject var viewModel: QuickAccessViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if viewModel.entries.isEmpty {
                lockedPlaceholder
            } else {
                entryList
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private var searchField: some View {
        TextField(
            NSLocalizedString(
                "quickAccess.search.placeholder",
                value: "Search",
                comment: "Quick-access window: search field placeholder"),
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.setQuery($0) })
        )
        .textFieldStyle(.roundedBorder)
        .padding(8)
    }

    private var lockedPlaceholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(NSLocalizedString(
                "quickAccess.locked.message",
                value: "Unlock a database in PassPouch to search it here.",
                comment: "Quick-access window: shown while no database is unlocked"))
            Spacer()
        }
        .font(.callout)
        .foregroundColor(.secondary)
    }

    private var entryList: some View {
        List(viewModel.filteredEntries) { entry in
            QuickAccessEntryRow(entry: entry)
        }
        .listStyle(.plain)
    }
}

private struct QuickAccessEntryRow: View {
    let entry: QuickAccessEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
            if !entry.username.isEmpty {
                Text(entry.username)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                if !entry.username.isEmpty {
                    Button(NSLocalizedString(
                        "quickAccess.copyUsername",
                        value: "Copy Username",
                        comment: "Quick-access window: copy username action")) {
                        Clipboard.general.copyWithTimeout(entry.username)
                        announceCopied()
                    }
                }
                Button(NSLocalizedString(
                    "quickAccess.copyPassword",
                    value: "Copy Password",
                    comment: "Quick-access window: copy password action")) {
                    Clipboard.general.copyWithTimeout(entry.password)
                    announceCopied()
                }
                if entry.hasTOTP {
                    // TOTP codes go stale every ~30s; recompute the code on
                    // copy and refresh the display periodically.
                    TimelineView(.periodic(from: .now, by: 5)) { _ in
                        totpControls
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var totpControls: some View {
        if let code = entry.currentTOTPCode() {
            Text(code)
                .font(.body.monospaced())
                .textSelection(.enabled)
            Button(NSLocalizedString(
                "quickAccess.copyTOTP",
                value: "Copy",
                comment: "Quick-access window: copy TOTP code action")) {
                // Generate fresh at copy time — the displayed code may be
                // seconds away from expiry.
                if let freshCode = entry.currentTOTPCode() {
                    Clipboard.general.copyWithTimeout(freshCode)
                    announceCopied()
                }
            }
        }
    }

    private func announceCopied() {
        UIAccessibility.post(
            notification: .announcement,
            argument: LString.titleCopiedToClipboard)
    }
}
