//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import KeePassiumLib
import SwiftUI

/// Settings screen for the watchOS companion app (ADR-013, SwiftUI per
/// ADR-009). Lets the user enable watch sharing and explicitly pick which
/// entries the watch may see. Default state: everything off, nothing shared.
struct WatchSettingsView: View {
    @State private var isSharingEnabled = WatchSelectionStore.shared.isSharingEnabled
    @State private var selectedIDs = WatchSelectionStore.shared.selectedEntryIDs
    @State private var entries: [Entry] = []
    @State private var databaseName: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    LString.watchAllowOnWatch,
                    isOn: Binding(
                        get: { isSharingEnabled },
                        set: { isSharingEnabled = $0; persistAndResend() }
                    )
                )
            } footer: {
                Text(LString.watchPrivacyFooter)
            }

            if databaseName == nil {
                Section {
                    Text(LString.watchNoDatabaseUnlocked)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(LString.watchSharedEntriesHeader) {
                    if entries.isEmpty {
                        Text(LString.watchNoEntriesSelected)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries, id: \.uuid) { entry in
                        WatchEntryToggleRow(
                            entry: entry,
                            isSelected: selectedIDs.contains(entry.uuid)
                        ) { isSelected in
                            toggle(entry: entry, isSelected: isSelected)
                        }
                    }
                }
            }
        }
        .navigationTitle(LString.titleWatchSettings)
        .onAppear(perform: reloadEntries)
    }

    private func reloadEntries() {
        guard let databaseFile = WatchConnectivityService.shared.currentDatabaseFileForSettings else {
            entries = []
            databaseName = nil
            return
        }
        databaseName = databaseFile.visibleFileName
        var allEntries = [Entry]()
        collectEntries(from: databaseFile.database.root, into: &allEntries)
        entries = allEntries.sorted { $0.resolvedTitle < $1.resolvedTitle }
    }

    private func collectEntries(from group: Group?, into entries: inout [Entry]) {
        guard let group else { return }
        entries.append(contentsOf: group.entries)
        for subgroup in group.groups {
            collectEntries(from: subgroup, into: &entries)
        }
    }

    private func toggle(entry: Entry, isSelected: Bool) {
        if isSelected {
            selectedIDs.insert(entry.uuid)
        } else {
            selectedIDs.remove(entry.uuid)
        }
        persistAndResend()
    }

    private func persistAndResend() {
        let store = WatchSelectionStore.shared
        store.isSharingEnabled = isSharingEnabled
        if !isSharingEnabled {
            selectedIDs = [] // keep local state in sync with the cleared store
        }
        store.selectedEntryIDs = selectedIDs
        WatchConnectivityService.shared.refreshSnapshot()
    }
}

private struct WatchEntryToggleRow: View {
    let entry: Entry
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { onToggle($0) }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.resolvedTitle)
                if !entry.resolvedUserName.isEmpty {
                    Text(entry.resolvedUserName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
