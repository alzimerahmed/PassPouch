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
        #if canImport(UIKit)
        TextField(
            NSLocalizedString(
                "quickAccess.search.placeholder",
                value: "Search",
                comment: "Quick-access window: search field placeholder"),
            text: $viewModel.query
        )
        .textFieldStyle(.roundedBorder)
        .padding(8)
        #else
        EmptyView()
        #endif
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
                    }
                }
                Button(NSLocalizedString(
                    "quickAccess.copyPassword",
                    value: "Copy Password",
                    comment: "Quick-access window: copy password action")) {
                    Clipboard.general.copyWithTimeout(entry.password)
                }
                if entry.hasTOTP, let code = entry.currentTOTPCode() {
                    Text(code)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Button(NSLocalizedString(
                        "quickAccess.copyTOTP",
                        value: "Copy",
                        comment: "Quick-access window: copy TOTP code action")) {
                        Clipboard.general.copyWithTimeout(code)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
