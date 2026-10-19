//  PassPouch — Password Manager (watchOS companion)
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import SwiftUI

/// Read-only quick view of the entries the user explicitly shared from the
/// iPhone app (ADR-013). Shows title, username, live TOTP code and a
/// reveal-on-press password. No copy/paste on watchOS — view only.
struct ContentView: View {
    @State private var snapshot: WatchSnapshot?

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot, !snapshot.entries.isEmpty {
                    List(snapshot.entries, id: \.id) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                if !entry.userName.isEmpty {
                                    Text(entry.userName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .listStyle(.carousel)
                } else {
                    emptyState
                }
            }
            .navigationTitle(Text("PassPouch"))
        }
        .onAppear {
            snapshot = SnapshotStore.load()
            WatchSessionManager.shared.requestSnapshot()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.iphone")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(NSLocalizedString(
                    "[Watch/Empty/title]",
                    value: "Unlock PassPouch on your iPhone to see shared entries here.",
                    comment: "Empty state in the watch app when nothing is shared yet."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// Detail view for one shared entry: username, live-refreshing TOTP code and
/// a password that is hidden until pressed (never read aloud by VoiceOver
/// while hidden).
struct EntryDetailView: View {
    let entry: WatchEntrySnapshot

    @State private var isPasswordVisible = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            if !entry.userName.isEmpty {
                row(
                    label: NSLocalizedString(
                        "[Watch/Field/Username]", value: "Username", comment: "Field label"),
                    value: entry.userName
                )
            }
            if let totp = entry.totp {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString(
                            "[Watch/Field/TOTP]",
                            value: "One-time code",
                            comment: "Field label for the live TOTP code"
                        ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(displayCode(params: totp))
                            .font(.system(.title2, design: .monospaced))
                            .textSelection(.disabled)
                    }
                }
            }
            Section {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    HStack {
                        Text(
                            isPasswordVisible
                                ? (entry.password.isEmpty ? "—" : entry.password)
                                : String(repeating: "•", count: max(entry.password.count, 1))
                        )
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        Spacer()
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPasswordVisible
                        ? NSLocalizedString(
                            "[Watch/A11y/PasswordVisible]",
                            value: "Password, visible",
                            comment: "A11y label when the password is revealed"
                        )
                        : NSLocalizedString(
                            "[Watch/A11y/PasswordHidden]",
                            value: "Password, hidden. Press to reveal.",
                            comment: "A11y label while the password is hidden"
                        )
                )
            } header: {
                Text(NSLocalizedString(
                    "[Watch/Field/Password]",
                    value: "Password",
                    comment: "Field label"
                ))
            }
        }
        .listStyle(.carousel)
        .navigationTitle(entry.title)
        .onReceive(ticker) { date in
            now = date
        }
    }

    private func displayCode(params: WatchTOTPParams) -> String {
        let code = WatchTOTPCore.generateCode(params: params, at: now) ?? "———"
        return WatchTOTPCore.formatForDisplay(code)
    }

    private func row(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.disabled)
        }
    }
}
