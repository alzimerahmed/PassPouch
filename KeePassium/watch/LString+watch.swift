//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

extension LString {
    // swiftlint:disable line_length
    public static let titleWatchSettings = NSLocalizedString(
        "[Settings/Watch/title]",
        value: "Apple Watch",
        comment: "Settings item that opens the Apple Watch companion settings screen.")

    public static let watchAllowOnWatch = NSLocalizedString(
        "[Settings/Watch/AllowOnWatch/title]",
        value: "Allow on Apple Watch",
        comment: "Toggle: whether the watch companion app may show shared entries at all.")

    public static let watchSharedEntriesHeader = NSLocalizedString(
        "[Settings/Watch/SharedEntries/header]",
        value: "Shared Entries",
        comment: "Section header in watch settings: the list of entries shared with the watch.")

    public static let watchNoDatabaseUnlocked = NSLocalizedString(
        "[Settings/Watch/NoDatabase/message]",
        value: "Unlock a database on this device to choose which entries appear on your watch.",
        comment: "Message in watch settings when no database is currently unlocked.")

    public static let watchNoEntriesSelected = NSLocalizedString(
        "[Settings/Watch/NoEntries/message]",
        value: "No entries are shared. Turn on the entries below — nothing is sent to the watch until you do.",
        comment: "Message in watch settings when sharing is on but no entries are selected.")

    public static let watchPrivacyFooter = NSLocalizedString(
        "[Settings/Watch/Privacy/footer]",
        value: "Only the entries you select here are sent to your paired watch, over the encrypted Bluetooth connection. The watch stores them in its own secure keychain and deletes them when the database locks. The database file itself never leaves this device.",
        comment: "Privacy explanation shown in watch settings.")
    // swiftlint:enable line_length
}
