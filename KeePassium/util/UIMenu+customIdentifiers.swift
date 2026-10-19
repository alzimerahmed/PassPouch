//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

extension UIMenu.Identifier {
    static let tools = UIMenu.Identifier("com.passpouch.menu.tools")
    static let passwordGenerator = UIMenu.Identifier("com.passpouch.menu.passwordGenerator")

    static let databaseFile = UIMenu.Identifier("com.passpouch.menu.databaseFile")
    static let lockDatabase = UIMenu.Identifier("com.passpouch.menu.lockDatabase")
    static let exportDatabase = UIMenu.Identifier("com.passpouch.menu.exportDatabase")
    static let fileSortOrder = UIMenu.Identifier("com.passpouch.menu.fileSortOrder")
    static let itemsSortOrder = UIMenu.Identifier("com.passpouch.menu.itemsSortOrder")
    static let reloadDatabase = UIMenu.Identifier("com.passpouch.menu.reloadDatabase")
    static let importDatabase = UIMenu.Identifier("com.passpouch.menu.importDatabase")
}
