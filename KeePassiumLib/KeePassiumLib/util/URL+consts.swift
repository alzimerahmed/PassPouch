//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension URL {
    public enum Prefs {
        private static let autoFillPreferencesURL_macOS =
            URL(string: "x-apple.systempreferences:com.apple.Passwords-Settings.extension?Options")!

        private static let autoFillPreferencesURL_iOS = URL(string: "App-prefs:PASSWORDS&path=PASSWORD_OPTIONS")!

        private static let appPermissionsURL_iOS = URL(string: UIApplication.openSettingsURLString)!

        private static let cameraPermissionPreferencesURL_macOS =
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!

        public static var autoFillPreferences: URL {
            if ProcessInfo.isRunningOnMac {
                return autoFillPreferencesURL_macOS
            } else {
                return autoFillPreferencesURL_iOS
            }
        }

        public static var cameraPermissionsURL: URL {
            if ProcessInfo.isRunningOnMac {
                return cameraPermissionPreferencesURL_macOS
            } else {
                return appPermissionsURL_iOS
            }
        }
    }

    public enum AppHelp {
        public static let helpIndex = URL(string: "https://passpouch.org/apphelp/")!
        public static var changeLog = URL(string: "https://passpouch.org/changelog/")!

        public static let termsAndConditions = URL(string: "https://passpouch.org/terms/app")!
        public static let privacyPolicyOfflineMode = URL(string: "https://passpouch.org/privacy/app")!
        public static let privacyPolicyOnlineMode = URL(string: "https://passpouch.org/privacy/app")!
        public static var currentPrivacyPolicy: URL {
            if Settings.current.isNetworkAccessAllowed {
                return privacyPolicyOnlineMode
            } else {
                return privacyPolicyOfflineMode
            }
        }

        public static let quickAutoFillIntro = URL(string: "https://passpouch.org/apphelp/quick-autofill/")!
        public static let autoFillMemoryLimits = URL(string: "https://passpouch.org/apphelp/autofill-memory-limits/")!
        public static let autoFillSetupGuide_iOS = URL(string: "https://passpouch.org/apphelp/how-to-set-up-autofill-ios/")!
        public static let autoFillSetupGuide_macOS = URL(string: "https://passpouch.org/apphelp/how-to-set-up-autofill-macos/")!
        public static var autoFillSetupGuide: URL {
            if ProcessInfo.isRunningOnMac {
                return autoFillSetupGuide_macOS
            } else {
                return autoFillSetupGuide_iOS
            }
        }

        public static let perpetualFallback = URL(string: "https://passpouch.org/apphelp/perpetual-fallback-license/")!
        public static let familySharing = URL(string: "https://passpouch.org/apphelp/family-sharing/")!

        public static let yubikeySetup = URL(string: "https://passpouch.org/apphelp/yubikey-setup/")!

        public static let usingFallbackDatabase = URL(string: "https://passpouch.org/apphelp/database-unreachable-using-fallback/")!
        public static let databaseFileIsInTrashWarning = URL(string: "https://passpouch.org/apphelp/database-recently-deleted-warning/")!
        public static let temporaryBackupDatabaseWarning = URL(string: "https://passpouch.org/apphelp/temporary-backup-database-warning/")!

        public static let hibpMoreInfoURLString = "https://www.troyhunt.com/ive-just-launched-pwned-passwords-version-2/#cloudflareprivacyandkanonymity"

        public static let smartGroups = URL(string: "https://passpouch.org/apphelp/smart-groups/")!

        public static let linkedDatabases = URL(string: "https://passpouch.org/apphelp/linked-databases/")!

        public static let invalidDatabasePassword = URL(string: "https://passpouch.org/apphelp/invalid-database-password/")!
        public static let fileDoesNotExist = URL(string: "https://passpouch.org/apphelp/does-not-exist/")!
        public static let fileProviderUnresponsive = URL(string: "https://passpouch.org/apphelp/file-provider-unresponsive/")!
    }

}
