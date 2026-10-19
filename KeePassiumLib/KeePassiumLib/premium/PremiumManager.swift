//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

/// PassPouch monetization neutralization (ADR-003): the upstream freemium/IAP
/// layer (StoreKit products, receipt analysis, paywall) has been removed.
/// This manager keeps a minimal API surface so the many feature-availability
/// call sites keep compiling; it always reports "premium features available".
public class PremiumManager: NSObject {
    public static let shared = PremiumManager()

    public enum Status {
        case initialGracePeriod
        case subscribed
        case lapsed
        case fallback
        case freeLightUse
        case freeHeavyUse
    }

    /// Always "subscribed": every premium feature is available to everyone.
    public var status: Status = .subscribed

    public static let statusUpdateNotification =
        Notification.Name("com.passpouch.premiumManager.statusUpdated")

    fileprivate func notifyStatusChanged() {
        NotificationCenter.default.post(name: PremiumManager.statusUpdateNotification, object: self)
    }

    public let usageMonitor = UsageMonitor()

    private override init() {
        super.init()
    }

    public func updateStatus() {
        // No-op: status is permanently .subscribed in PassPouch.
    }

    /// Always true: there is no paid support tier in PassPouch.
    public func isPremiumSupportAvailable() -> Bool {
        return true
    }

    public func isAvailable(feature: PremiumFeature) -> Bool {
        return feature.isAvailable(in: status, fallbackDate: nil)
    }

    /// Always nil: no purchase history exists in PassPouch.
    public var fallbackDate: Date? { return nil }
}
