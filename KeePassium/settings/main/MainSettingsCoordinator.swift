//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication.LAContext
import SwiftUI

final class MainSettingsCoordinator: BaseCoordinator {
    private let mainSettingsVC: MainSettingsVC

    override init(router: NavigationRouter) {
        mainSettingsVC = MainSettingsVC()
        super.init(router: router)
        mainSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(mainSettingsVC, dismissButtonStyle: .close, animated: true)
        applySettingsToVC()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        mainSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        let settings = Settings.current
        mainSettingsVC.isAppProtectionVisible = ManagedAppConfig.shared.isAppProtectionAllowed
        mainSettingsVC.isAutoOpenPreviousDatabase = settings.isAutoUnlockStartupDatabase
        mainSettingsVC.biometryType = LAContext.getBiometryType()
        mainSettingsVC.isNetworkAccessAllowed = settings.isNetworkAccessAllowed
    }
}

extension MainSettingsCoordinator: MainSettingsVC.Delegate {
    func didPressShowAppHistory(in viewController: MainSettingsVC) {
        let coordinator = AppHistoryCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didToggleAutoOpenPreviousDatabase(_ isOn: Bool, in viewController: MainSettingsVC) {
        Settings.current.isAutoUnlockStartupDatabase = isOn
        viewController.showNotificationIfManaged(setting: .autoUnlockStartupDatabase)
        refresh()
    }

    func didPressAppearanceSettings(in viewController: MainSettingsVC) {
        let coordinator = AppearanceSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressSearchSettings(in viewController: MainSettingsVC) {
        let coordinator = SearchSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressAutoFillSettings(in viewController: MainSettingsVC) {
        let coordinator = AutoFillSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressAppProtectionSettings(in viewController: MainSettingsVC) {
        guard ManagedAppConfig.shared.isAppProtectionAllowed else {
            viewController.showManagedFeatureBlockedNotification()
            Diag.error("Blocked by organization's policy")
            assertionFailure("Should be hidden in UI")
            return
        }
        let coordinator = AppProtectionSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressDataProtectionSettings(in viewController: MainSettingsVC) {
        let coordinator = DataProtectionSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressNetworkAccessSettings(in viewController: MainSettingsVC) {
        let coordinator = NetworkAccessSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressBackupSettings(in viewController: MainSettingsVC) {
        let coordinator = BackupSettingsCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressWatchSettings(in viewController: MainSettingsVC) {
        // Phase 11a (ADR-013): SwiftUI screen per ADR-009.
        WatchConnectivityService.shared.activate()
        let hostingController = UIHostingController(rootView: WatchSettingsView())
        hostingController.navigationItem.title = LString.titleWatchSettings
        _router.push(hostingController, animated: true, onPop: nil)
    }

    func didPressEmergencyAccess(in viewController: MainSettingsVC) {
        // Phase 11c (ADR-016): offline emergency access, SwiftUI per ADR-009.
        let coordinator = EmergencyAccessCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressShowDiagnostics(in viewController: MainSettingsVC) {
        let coordinator = DiagnosticsViewerCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    func didPressContactSupport(in viewController: MainSettingsVC) {
        let popoverAnchor = viewController.view.asPopoverAnchor
        SupportEmailComposer.show(
            subject: .supportRequest,
            parent: viewController,
            popoverAnchor: popoverAnchor
        )
    }

    func didPressAboutApp(in viewController: MainSettingsVC) {
        let coordinator = AboutCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }
}
