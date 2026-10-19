//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI

/// SwiftUI wizard for CSV entry import: file info → format (auto-detected
/// with manual override) → column mapping with preview → import → summary.
/// Uses system styles — dark mode and Dynamic Type come for free; no custom
/// motion (reduced-motion safe by design).
struct CSVImportWizardView: View {
    @ObservedObject var model: CSVImportWizardModel
    let onImport: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                fileSection
                formatSection
                if model.summary == nil {
                    mappingSection
                    previewSection
                } else {
                    summarySection
                }
            }
            .navigationTitle(Text(LString.CSVImport.wizardTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LString.actionCancel, action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.summary == nil {
                        Button(LString.actionImport, action: onImport)
                            .disabled(model.importableRowCount == 0)
                    } else {
                        Button(LString.actionDone, action: onDone)
                    }
                }
            }
        }
    }

    private var fileSection: some View {
        Section(LString.CSVImport.sectionFile) {
            Text(model.fileName)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(String.localizedStringWithFormat(
                LString.CSVImport.rowCountTemplate, model.dataRows.count))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var formatSection: some View {
        Section(LString.CSVImport.sectionFormat) {
            Picker(
                LString.CSVImport.sectionFormat,
                selection: Binding(
                    get: { model.selectedFormat },
                    set: { model.applyAutoMapping(for: $0) }
                )
            ) {
                ForEach(CSVImportFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            if !model.isFormatDetected {
                Label(
                    LString.CSVImport.formatNotRecognized,
                    systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mappingSection: some View {
        Section(LString.CSVImport.sectionColumnMapping) {
            ForEach(CSVColumnRole.allCases) { role in
                Picker(role.displayName, selection: Binding(
                    get: { model.mapping[role] },
                    set: { model.setMapping(role: role, column: $0) }
                )) {
                    Text(LString.CSVImport.unmappedColumn).tag(Int?.none)
                    ForEach(model.headerRow.indices, id: \.self) { index in
                        Text(model.headerRow[index]).tag(Int?.some(index))
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        Section {
            ForEach(model.previewRows().indices, id: \.self) { index in
                let row = model.previewRows()[index]
                VStack(alignment: .leading, spacing: 2) {
                    Text(row[safe: model.mapping[.title] ?? -1] ?? "")
                        .font(.body)
                    Text(previewSubtitle(row))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String.localizedStringWithFormat(
                LString.CSVImport.previewRowsTemplate, model.previewRows().count))
        }
    }

    private var summarySection: some View {
        Section(LString.CSVImport.sectionSummary) {
            if let summary = model.summary {
                Text(String.localizedStringWithFormat(
                    LString.CSVImport.summaryImportedTemplate, summary.imported))
                if summary.skipped > 0 {
                    Text(String.localizedStringWithFormat(
                        LString.CSVImport.summarySkippedTemplate, summary.skipped))
                        .foregroundStyle(.secondary)
                }
                if summary.failed > 0 {
                    Text(String.localizedStringWithFormat(
                        LString.CSVImport.summaryFailedTemplate, summary.failed))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func previewSubtitle(_ row: [String]) -> String {
        let username = row[safe: model.mapping[.username] ?? -1] ?? ""
        let url = row[safe: model.mapping[.url] ?? -1] ?? ""
        return [username, url].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
