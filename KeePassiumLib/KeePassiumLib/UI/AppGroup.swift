//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class AppGroup {
    public static var id: String = {
        if BusinessModel.isIntuneEdition {
            fatalError("Intune edition is not supported in PassPouch")
        } else {
            return "group.com.passpouch"
        }
    }()

    public static let appURLScheme: String = {
        if BusinessModel.isIntuneEdition {
            fatalError("Intune edition is not supported in PassPouch")
        }
        switch BusinessModel.type {
        case .freemium:
            return "passpouch"
        case .prepaid:
            return "passpouch.pro"
        }
    }()

    public static let launchMainAppURL = URL(string: appURLScheme + "://")!

    public static var isMainApp: Bool {
        return applicationShared != nil
    }

    public static var isAppExtension: Bool {
        return !isMainApp
    }

    public static weak var applicationShared: UIApplication?
}
