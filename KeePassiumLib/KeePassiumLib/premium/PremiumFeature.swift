//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum PremiumFeature: Int {
    public static let all: [PremiumFeature] = [
        .canUseMultipleDatabases,
        .canUseHardwareKeys,
        .canRelocateAcrossDatabases,
        .canUseQuickTypeAutoFill,
        .canUseBusinessClouds,
        .canAuditPasswords,
        .canOpenLinkedDatabases,
        .canCreateEntriesInAutoFill,
    ]

    case canUseMultipleDatabases = 0

    /* case canUseLongDatabaseTimeouts = 2 */

    /* case canPreviewAttachments = 3 */

    case canUseHardwareKeys = 4

    /* case canKeepMasterKeyOnDatabaseTimeout = 5 */

    /* case canChangeAppIcon = 6 */

    /* case canUseExpressUnlock = 7 */

    /* case canViewFieldReferences = 8 */

    case canRelocateAcrossDatabases = 9

    case canUseQuickTypeAutoFill = 10

    case canUseBusinessClouds = 11

    case canAuditPasswords = 12

    case canOpenLinkedDatabases = 13

    case canCreateEntriesInAutoFill = 14

    /// PassPouch is fully free (ADR-003): every feature is available to
    /// everyone. The API surface is kept for a minimal diff against upstream.
    public func isAvailable(in status: PremiumManager.Status, fallbackDate: Date?) -> Bool {
        return true
    }
}
