//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

#if targetEnvironment(macCatalyst)
import AppKit
import KeePassiumLib
import SwiftUI

/// Phase 11d (ADR-017): compact secondary window for searching the currently
/// unlocked database and copying username/password/TOTP without switching to
/// the main window. Catalyst-only.
///
/// Security model: reads entries of the CURRENT unlocked database session
/// only; observes the same lock/unlock lifecycle as the main window and
/// clears its list on lock. No secret is persisted anywhere new.
final class QuickAccessWindowController {
    static let shared = QuickAccessWindowController()

    private(set) var window: NSWindow?
    private let viewModel = QuickAccessViewModel()
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: QuickAccessNotifications.databaseDidUnlock,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let databaseFile = notification.object as? DatabaseFile else { return }
            self?.viewModel.setDatabase(databaseFile.database)
        })
        observers.append(center.addObserver(
            forName: QuickAccessNotifications.databaseDidLock,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.clear()
            self?.hideWindow()
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func showWindow() {
        if window == nil {
            makeWindow()
        }
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    private func makeWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = NSLocalizedString(
            "quickAccess.window.title",
            value: "Quick Access",
            comment: "Quick-access window: title")
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 380, height: 480))
        window.center()

        let hostingController = NSHostingController(
            rootView: QuickAccessView(viewModel: viewModel))
        window.contentViewController = hostingController
        self.window = window
    }
}
#endif
