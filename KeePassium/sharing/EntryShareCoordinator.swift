//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI
import UIKit

/// SwiftUI field-selection screen for creating an encrypted entry-share
/// link (ADR-015). Shows the security warning and an optional expiry.
struct EntryShareFieldPickerView: View {
    let availableFields: [EntryShareField]
    let onGenerate: (Set<EntryShareField>, Date?) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<EntryShareField> = [.title, .userName, .password]
    @State private var expiryChoice: ExpiryChoice = .none

    enum ExpiryChoice: Hashable {
        case none
        case oneHour
        case oneDay
        case oneWeek
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LString.shareScreenSubtitle)) {
                    ForEach(availableFields, id: \.self) { field in
                        Toggle(field.localizedTitle, isOn: binding(for: field))
                    }
                }
                Section {
                    Picker(LString.shareExpiryLabel, selection: $expiryChoice) {
                        Text(LString.shareExpiryNone).tag(ExpiryChoice.none)
                        Text(expiryTitle(.oneHour)).tag(ExpiryChoice.oneHour)
                        Text(expiryTitle(.oneDay)).tag(ExpiryChoice.oneDay)
                        Text(expiryTitle(.oneWeek)).tag(ExpiryChoice.oneWeek)
                    }
                }
                Section {
                    Label(LString.shareWarningLinkIsSecret, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section {
                    Button(LString.shareGenerateButton) {
                        onGenerate(selected, expiryDate(for: expiryChoice))
                    }
                    Button(LString.actionCancel, role: .cancel) {
                        onCancel()
                    }
                }
            }
            .navigationTitle(LString.shareScreenTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func binding(for field: EntryShareField) -> Binding<Bool> {
        Binding(
            get: { selected.contains(field) },
            set: { isOn in
                if isOn {
                    selected.insert(field)
                } else {
                    selected.remove(field)
                }
            })
    }

    private func expiryTitle(_ choice: ExpiryChoice) -> String {
        switch choice {
        case .oneHour: return LString.shareExpiryOneHour
        case .oneDay: return LString.shareExpiryOneDay
        case .oneWeek: return LString.shareExpiryOneWeek
        case .none: return ""
        }
    }

    private func expiryDate(for choice: ExpiryChoice) -> Date? {
        switch choice {
        case .none: return nil
        case .oneHour: return Date().addingTimeInterval(3600)
        case .oneDay: return Date().addingTimeInterval(24 * 3600)
        case .oneWeek: return Date().addingTimeInterval(7 * 24 * 3600)
        }
    }
}

/// Presents the entry-share flow: field selection → link generation →
/// system share sheet. Purely local: the link is never uploaded anywhere.
final class EntryShareCoordinator: BaseCoordinator {
    private let entry: Entry
    private lazy var hostingController: UIHostingController<EntryShareFieldPickerView> = {
        var availableFields = EntryShareField.allCases
        if !entry.hasValidTOTP {
            availableFields.removeAll { $0 == .totp }
        }

        let view = EntryShareFieldPickerView(
            availableFields: availableFields,
            onGenerate: { [weak self] fields, expiresAt in
                self?.generateLink(fields: fields, expiresAt: expiresAt)
            },
            onCancel: { [weak self] in self?.dismiss() })
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .systemBackground
        return controller
    }()

    init(entry: Entry, router: NavigationRouter) {
        self.entry = entry
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: true)
    }

    private func generateLink(fields: Set<EntryShareField>, expiresAt: Date?) {
        do {
            let payload = try EntrySharePayload.make(
                from: entry, fields: fields, expiresAt: expiresAt)
            let (payloadData, key) = try EntrySharePayload.encrypt(payload)
            let link = try EntrySharePayload.makeLink(payloadData: payloadData, key: key)
            // Security: the link (payload + key) is never logged.
            Diag.info("Share link generated [fields: \(fields.count), hasExpiry: \(expiresAt != nil)]")
            presentShareSheet(for: link)
        } catch ShareLinkError.nothingSelected {
            hostingController.showErrorAlert(LString.shareNoFieldsSelected)
        } catch {
            Diag.error("Failed to generate share link")
            hostingController.showErrorAlert(error.localizedDescription)
        }
    }

    private func presentShareSheet(for link: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [link],
            applicationActivities: nil)
        // iPad requires a popover anchor; iPhone/catalyst ignore this.
        activityVC.popoverPresentationController?.sourceView = hostingController.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: hostingController.view.bounds.midX,
            y: hostingController.view.bounds.maxY,
            width: 0, height: 0)
        _router.navigationController.present(activityVC, animated: true)
    }
}
