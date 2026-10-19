//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI

/// Presents the offline Emergency Access screen (ADR-016): Emergency Kit
/// PDF, Shamir split, and share recovery. No network, no storage.
final class EmergencyAccessCoordinator: BaseCoordinator {
    private let hostingController: UIHostingController<EmergencyAccessView>

    init(router: NavigationRouter) {
        let databaseLocations = FileKeeper.shared
            .getAllReferences(fileType: .database, includeBackup: false)
            .map { $0.visibleFileName }

        let view = EmergencyAccessView(
            databaseLocations: databaseLocations,
            appVersion: "\(AppInfo.version).\(AppInfo.build)",
            onGenerateKit: { [weak self] manualHint in
                self?.generateKitPDF(manualHint: manualHint)
            })
        hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .systemBackground
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: true)
    }

    /// Generates the Emergency Kit PDF and offers it via the share sheet.
    /// The master password is never inserted — see ADR-016.
    private func generateKitPDF(manualHint: String) {
        let pdfData = EmergencyKitPDF.generate(
            appVersion: "\(AppInfo.version).\(AppInfo.build)",
            databaseLocations: FileKeeper.shared
                .getAllReferences(fileType: .database, includeBackup: false)
                .map { $0.visibleFileName },
            manualHint: manualHint)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PassPouch-Emergency-Kit.pdf")
        do {
            try pdfData.write(to: temporaryURL, options: .atomic)
        } catch {
            Diag.error("Failed to write Emergency Kit PDF")
            hostingController.showErrorAlert(error)
            return
        }
        Diag.info("Emergency Kit PDF generated")
        let shareSheet = ShareSheet(items: [temporaryURL])
        let hosting = UIHostingController(rootView: shareSheet)
        hosting.modalPresentationStyle = .formSheet
        _router.navigationController.present(hosting, animated: true)
    }
}
