//  PassPouch — Feature: Onboarding & Import (Phase 9)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI

/// Presents the CSV import wizard (SwiftUI in a form sheet). Entries are
/// created in the currently viewed group and the database is saved with the
/// standard DatabaseSaver flow (backup-before-save applies).
final class CSVImportCoordinator: BaseCoordinator, DatabaseSaving {
    protocol Delegate: AnyObject {
        func didImportCSVEntries(_ coordinator: CSVImportCoordinator)
    }

    weak var delegate: Delegate?

    private let databaseFile: DatabaseFile
    private let parent: KeePassiumLib.Group
    private let wizardModel: CSVImportWizardModel

    private let hostingController: UIHostingController<CSVImportWizardView>

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return _router }
    var saveSuccessHandler: (() -> Void)?

    init(
        router: NavigationRouter,
        databaseFile: DatabaseFile,
        parent: KeePassiumLib.Group,
        fileName: String,
        csvText: String
    ) throws {
        self.databaseFile = databaseFile
        self.parent = parent
        wizardModel = try CSVImportWizardModel(fileName: fileName, csvText: csvText)

        let view = CSVImportWizardView(
            model: wizardModel,
            onImport: { [weak self] in self?.importEntries() },
            onDone: { [weak self] in self?.dismiss() })
        hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .systemBackground
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: false)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return hostingController
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        // CSV import never relocates the database; required protocol method.
    }

    private func importEntries() {
        let summary = wizardModel.importEntries(into: parent)
        Diag.info("CSV import finished [imported: \(summary.imported), " +
            "skipped: \(summary.skipped), failed: \(summary.failed)]")

        saveDatabase(databaseFile) { [weak self] in
            guard let self else { return }
            Diag.info("CSV import saved OK")
            delegate?.didImportCSVEntries(self)
        }
    }
}
