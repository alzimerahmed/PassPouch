//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import SwiftUI

/// SwiftUI screen for bulk-importing `otpauth://` URIs (pasted text or a
/// multi-URI QR payload). Uses system colors/styles — dark mode and Dynamic
/// Type come for free; no custom motion (reduced-motion safe by design).
struct OtpauthImportView: View {
    @Binding var payloadText: String
    let parsedItems: [OtpauthItem]
    let invalidLineCount: Int
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void
    let onSelectAll: (Bool) -> Void
    let onImport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Payload") {
                    TextEditor(text: $payloadText)
                        .frame(minHeight: 96)
                        .font(.footnote)
                        .accessibilityLabel(Text("otpauth:// URI payload"))
                }
                if invalidLineCount > 0 {
                    Section {
                        Label(
                            String.localizedStringWithFormat(
                                NSLocalizedString(
                                    "[OtpauthImport/InvalidLines] %d line(s) could not be parsed and will be skipped.",
                                    value: "%d line(s) could not be parsed and will be skipped.",
                                    comment: "otpauth bulk import: number of unparseable lines [count: Int]"),
                                invalidLineCount),
                            systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(parsedItems) { item in
                        Button {
                            onToggle(item.uri)
                        } label: {
                            HStack {
                                Image(systemName: selectedIDs.contains(item.uri)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayTitle(item)).font(.body)
                                    if !item.accountName.isEmpty {
                                        Text(item.accountName)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Toggles selection for import"))
                    }
                } header: {
                    HStack {
                        Text("Found TOTP entries")
                        Spacer()
                        Button(
                            selectedIDs.count == parsedItems.count
                                ? "Deselect All" : "Select All"
                        ) {
                            onSelectAll(selectedIDs.count != parsedItems.count)
                        }
                        .font(.footnote)
                        .buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle(Text("Import TOTP"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private func displayTitle(_ item: OtpauthItem) -> String {
        item.issuer.isEmpty ? item.accountName : item.issuer
    }
}

