//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension Coordinator {

    func startObservingPremiumStatus(_ selector: Selector) {
        NotificationCenter.default.addObserver(
            self,
            selector: selector,
            name: PremiumManager.statusUpdateNotification,
            object: nil)
    }

    /// PassPouch is fully free: every premium-gated feature is available to
    /// everyone, so the action handler is always executed. The premium-check
    /// API surface is kept for minimal diff against upstream.
    func performPremiumActionOrOfferUpgrade(
        for feature: PremiumFeature,
        allowBypass: Bool = false,
        bypassTitle: String = LString.actionContinue,
        in viewController: UIViewController,
        actionHandler: @escaping () -> Void
    ) {
        assert(PremiumManager.shared.isAvailable(feature: feature))
        actionHandler()
    }
}
