//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI

extension DatabaseViewerCoordinator {
    /// Presents the otpauth:// bulk import screen (SwiftUI in a form sheet).
    /// Entries are created in the currently viewed group and the database is
    /// saved with the standard DatabaseSaver flow (backup-before-save applies).
    func _showOtpauthBulkImporter() {
        guard databaseFileStatusAllowsEditing else {
            Diag.warning("Cannot bulk-import TOTP into a read-only database")
            _presenterForModals.showErrorAlert(
                NSLocalizedString(
                    "[OtpauthImport/ReadOnly] The database is read-only.",
                    value: "The database is read-only.",
                    comment: "Error message when trying to import TOTP into a read-only database"))
            return
        }
        guard _database is Database2 else {
            Diag.warning("Bulk TOTP import requires KDBX 4 (Database2)")
            _presenterForModals.showErrorAlert(
                NSLocalizedString(
                    "[OtpauthImport/NeedsKDBX4] TOTP import requires a KDBX 4 database.",
                    value: "TOTP import requires a KDBX 4 database.",
                    comment: "Error message when the open database is KDBX 1/3"))
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let coordinator = OtpauthImportCoordinator(
            router: modalRouter,
            databaseFile: _databaseFile,
            parent: _currentGroup ?? _database.root)
        coordinator.delegate = self
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: { [weak self] _ in
            self?.refresh()
        })
        _presenterForModals.present(modalRouter, animated: true, completion: nil)
    }

    private var databaseFileStatusAllowsEditing: Bool {
        !_databaseFile.status.contains(.readOnly)
    }
}

extension DatabaseViewerCoordinator: OtpauthImportCoordinator.Delegate {
    func didImportOtpauthEntries(_ coordinator: OtpauthImportCoordinator) {
        refresh()
    }
}

// MARK: - Import coordinator

final class OtpauthImportCoordinator: BaseCoordinator, DatabaseSaving {
    protocol Delegate: AnyObject {
        func didImportOtpauthEntries(_ coordinator: OtpauthImportCoordinator)
    }

    weak var delegate: Delegate?

    private let databaseFile: DatabaseFile
    private let parent: Group

    private var payloadText: String = ""
    private var selectedURIs: Set<String> = []

    private let hostingController: UIHostingController<OtpauthImportView>

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return _router }
    var saveSuccessHandler: (() -> Void)?

    init(router: NavigationRouter, databaseFile: DatabaseFile, parent: Group) {
        self.databaseFile = databaseFile
        self.parent = parent

        let view = OtpauthImportView(
            payloadText: .init(
                get: { [weak self] in self?.payloadText ?? "" },
                set: { [weak self] in self?.reparse($0) }),
            parsedItems: [],
            invalidLineCount: 0,
            selectedIDs: [],
            onToggle: { [weak self] uri in self?.toggle(uri) },
            onSelectAll: { [weak self] selectAll in self?.selectAll(selectAll) },
            onImport: { [weak self] in self?.importSelected() },
            onCancel: { [weak self] in self?.cancel() })
        hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .systemBackground
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: false)
    }

    private func reparse(_ newText: String) {
        payloadText = newText
        let result = OtpauthBulkImporter.parse(payload: newText)
        selectedURIs = selectedURIs.filter { uri in
            result.items.contains(where: { $0.uri == uri })
        }
        refreshView()
    }

    private func toggle(_ uri: String) {
        if selectedURIs.contains(uri) {
            selectedURIs.remove(uri)
        } else {
            selectedURIs.insert(uri)
        }
        refreshView()
    }

    private func selectAll(_ selectAll: Bool) {
        let result = OtpauthBulkImporter.parse(payload: payloadText)
        selectedURIs = selectAll ? Set(result.items.map(\.uri)) : []
        refreshView()
    }

    private func refreshView() {
        let result = OtpauthBulkImporter.parse(payload: payloadText)
        hostingController.rootView = OtpauthImportView(
            payloadText: .init(
                get: { [weak self] in self?.payloadText ?? "" },
                set: { [weak self] in self?.reparse($0) }),
            parsedItems: result.items,
            invalidLineCount: result.invalidLineCount,
            selectedIDs: selectedURIs,
            onToggle: { [weak self] uri in self?.toggle(uri) },
            onSelectAll: { [weak self] selectAll in self?.selectAll(selectAll) },
            onImport: { [weak self] in self?.importSelected() },
            onCancel: { [weak self] in self?.cancel() })
    }

    private func cancel() {
        dismiss()
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return hostingController
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        // Bulk import never relocates the database; required protocol method.
    }

    private func importSelected() {
        let result = OtpauthBulkImporter.parse(payload: payloadText)
        let itemsToImport = result.items.filter { selectedURIs.contains($0.uri) }
        guard !itemsToImport.isEmpty else { return }

        Diag.info("Will bulk-import TOTP entries [count: \(itemsToImport.count)]")
        for item in itemsToImport {
            let entry = parent.createEntry(detached: false)
            entry.populateStandardFields()
            entry.rawTitle = item.issuer.isEmpty ? item.accountName : item.issuer
            if !item.accountName.isEmpty {
                entry.rawUserName = item.accountName
            }
            entry.setField(name: EntryField.otp, value: item.uri, isProtected: true)
            entry.touch(.modified)
        }

        saveDatabase(databaseFile) { [weak self] in
            guard let self else { return }
            Diag.info("Bulk TOTP import saved OK")
            delegate?.didImportOtpauthEntries(self)
            dismiss()
        }
    }
}
