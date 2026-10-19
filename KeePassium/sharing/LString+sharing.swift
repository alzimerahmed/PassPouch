//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation

extension LString {
    // swiftlint:disable line_length

    // MARK: Entry sharing (gap #9, ADR-015)

    public static let shareEntryActionTitle = NSLocalizedString(
        "[Entry/Share/action]",
        value: "Share Entry…",
        comment: "Action to share selected fields of an entry as an encrypted link")

    public static let shareScreenTitle = NSLocalizedString(
        "[Share/EntryPicker/title]",
        value: "Share Entry",
        comment: "Title of the entry-share field-selection screen")

    public static let shareScreenSubtitle = NSLocalizedString(
        "[Share/EntryPicker/subtitle]",
        value: "Choose the fields to include. They will be encrypted into a single link — no server involved.",
        comment: "Explanation on the entry-share field-selection screen")

    public static let shareWarningLinkIsSecret = NSLocalizedString(
        "[Share/EntryPicker/LinkIsSecret]",
        value: "The link itself contains the secret. Anyone who obtains it can read the shared fields. Send it only through channels you trust.",
        comment: "Security warning on the entry-share screen")

    public static let shareExpiryLabel = NSLocalizedString(
        "[Share/EntryPicker/Expiry]",
        value: "Expires",
        comment: "Label for the optional share expiry picker")

    public static let shareExpiryNone = NSLocalizedString(
        "[Share/EntryPicker/ExpiryNone]",
        value: "Never",
        comment: "Option: the shared link never expires")

    public static let shareExpiryOneHour = NSLocalizedString(
        "[Share/EntryPicker/ExpiryOneHour]",
        value: "1 hour",
        comment: "Option: the shared link expires in one hour")

    public static let shareExpiryOneDay = NSLocalizedString(
        "[Share/EntryPicker/ExpiryOneDay]",
        value: "24 hours",
        comment: "Option: the shared link expires in 24 hours")

    public static let shareExpiryOneWeek = NSLocalizedString(
        "[Share/EntryPicker/ExpiryOneWeek]",
        value: "7 days",
        comment: "Option: the shared link expires in 7 days")

    public static let shareGenerateButton = NSLocalizedString(
        "[Share/EntryPicker/Generate]",
        value: "Create Share Link",
        comment: "Button that generates the encrypted share link")

    public static let shareNoFieldsSelected = NSLocalizedString(
        "[Share/error/NoFields]",
        value: "Select at least one field to share.",
        comment: "Error when no fields are selected for sharing")

    // MARK: Shared item viewer (recipient side)

    public static let sharedItemTitle = NSLocalizedString(
        "[SharedItem/title]",
        value: "Shared Item",
        comment: "Title of the read-only viewer for a received share link")

    public static let sharedItemBanner = NSLocalizedString(
        "[SharedItem/banner]",
        value: "Shared snapshot — not part of any database. It will disappear when you close this screen.",
        comment: "Banner in the shared-item viewer explaining the item is ephemeral")

    public static let sharedItemKeepOpen = NSLocalizedString(
        "[SharedItem/keepOpen]",
        value: "Keep open",
        comment: "Button that cancels the shared-item auto-close countdown")

    public static let a11yShowValue = NSLocalizedString(
        "[A11y/showValue]",
        value: "Show value",
        comment: "Accessibility label of the reveal-value (eye) toggle when the value is hidden")

    public static let a11yHideValue = NSLocalizedString(
        "[A11y/hideValue]",
        value: "Hide value",
        comment: "Accessibility label of the reveal-value (eye) toggle when the value is shown")

    public static let sharedItemExpired = NSLocalizedString(
        "[SharedItem/expired]",
        value: "This shared link has expired.",
        comment: "Error when a received share link is past its expiry timestamp")

    public static let sharedItemInvalid = NSLocalizedString(
        "[SharedItem/invalid]",
        value: "This link is not a valid PassPouch share link.",
        comment: "Error when a received link cannot be parsed as a share link")

    public static let sharedItemWrongKey = NSLocalizedString(
        "[SharedItem/wrongKey]",
        value: "This link is damaged or incomplete. Ask the sender to resend it — copying a link can drop its secret part.",
        comment: "Error when a received share link cannot be decrypted")

    // MARK: Emergency access (gap #12, ADR-016)

    public static let emergencyAccessTitle = NSLocalizedString(
        "[Settings/EmergencyAccess/title]",
        value: "Emergency Access",
        comment: "Settings item that opens the offline emergency-access screen")

    public static let emergencyKitSection = NSLocalizedString(
        "[Emergency/Kit/section]",
        value: "Emergency Kit (PDF)",
        comment: "Section header for the printable emergency kit")

    public static let emergencyKitHintPlaceholder = NSLocalizedString(
        "[Emergency/Kit/HintPlaceholder]",
        value: "Optional hint (e.g. where you stored the printed shares). Never type the master password itself here.",
        comment: "Placeholder of the manual hint field in the emergency kit")

    public static let emergencyKitGenerate = NSLocalizedString(
        "[Emergency/Kit/Generate]",
        value: "Create Emergency Kit PDF",
        comment: "Button that generates the emergency kit PDF")

    public static let emergencyKitWarning = NSLocalizedString(
        "[Emergency/Kit/Warning]",
        value: "PassPouch never writes your master password into the kit. Store the printed kit and your share slips in different places.",
        comment: "Warning about what the emergency kit contains")

    public static let emergencySplitSection = NSLocalizedString(
        "[Emergency/Split/section]",
        value: "Split the Master Password (Shamir)",
        comment: "Section header for the Shamir split screen")

    public static let emergencySplitExplanation = NSLocalizedString(
        "[Emergency/Split/Explanation]",
        value: "PassPouch splits your master password into N printable shares. Any M of them reconstruct it. Each share alone reveals nothing — store them separately.",
        comment: "Explanation of Shamir secret sharing for emergency access")

    public static let emergencySplitButton = NSLocalizedString(
        "[Emergency/Split/Button]",
        value: "Split Password into Shares",
        comment: "Button that performs the Shamir split")

    public static let emergencySharesCount = NSLocalizedString(
        "[Emergency/Split/SharesCount]",
        value: "Number of shares (N)",
        comment: "Label for the total number of Shamir shares")

    public static let emergencyThresholdCount = NSLocalizedString(
        "[Emergency/Split/Threshold]",
        value: "Shares needed to recover (M)",
        comment: "Label for the Shamir threshold")

    public static let emergencyCombineSection = NSLocalizedString(
        "[Emergency/Combine/section]",
        value: "Recover from Shares",
        comment: "Section header for the Shamir combine screen")

    public static let emergencyRevealedPasswordA11y = NSLocalizedString(
        "[Emergency/Reveal/A11yLabel]",
        value: "Revealed master password",
        comment: "Accessibility label of the revealed master password text")

    // MARK: Emergency Kit PDF (ADR-016)

    public static let emergencyKitPDFTitle = NSLocalizedString(
        "[Emergency/Kit/PDFTitle]",
        value: "PassPouch — Emergency Kit",
        comment: "Title line of the printable Emergency Kit PDF")

    public static let emergencyKitPDFVersionLine = NSLocalizedString(
        "[Emergency/Kit/PDFVersionLine]",
        value: "App version: %@   Generated: %@",
        comment: "Version/generated line of the Emergency Kit PDF. Parameters: app version, generation date/time")

    public static let emergencyKitPDFDatabasesHeader = NSLocalizedString(
        "[Emergency/Kit/PDFDatabases]",
        value: "Your databases",
        comment: "Header of the database list in the Emergency Kit PDF")

    public static let emergencyKitPDFNoDatabases = NSLocalizedString(
        "[Emergency/Kit/PDFNoDatabases]",
        value: "No databases found.",
        comment: "Shown in the Emergency Kit PDF when no databases are registered")

    public static let emergencyKitPDFRecoveryHeader = NSLocalizedString(
        "[Emergency/Kit/PDFRecoveryHeader]",
        value: "How to recover access (offline)",
        comment: "Header of the recovery instructions in the Emergency Kit PDF")

    public static let emergencyKitPDFHintsHeader = NSLocalizedString(
        "[Emergency/Kit/PDFHintsHeader]",
        value: "My hints (written by hand)",
        comment: "Header of the manual hints section in the Emergency Kit PDF")

    public static let emergencyKitPDFFooter = NSLocalizedString(
        "[Emergency/Kit/PDFFooter]",
        value: "PassPouch never stores or prints your master password. Keep this kit and any Shamir share slips in separate, safe places.",
        comment: "Footer warning of the Emergency Kit PDF")

    public static let emergencyKitPDFRecoverySteps: [String] = [
        NSLocalizedString(
            "[Emergency/Kit/PDFStep1]",
            value: "1. Find the database file (.kdbx) listed above — on this device, in iCloud Drive,",
            comment: "Recovery step 1, line 1 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep1b]",
            value: "    or in your cloud/WebDAV storage. Copy it to a safe place.",
            comment: "Recovery step 1, line 2 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep2]",
            value: "2. Open PassPouch on any iOS device and unlock the database with your master",
            comment: "Recovery step 2, line 1 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep2b]",
            value: "    password (or key file, if you use one).",
            comment: "Recovery step 2, line 2 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep3]",
            value: "3. If the master password is lost, use your printed Shamir shares: Settings →",
            comment: "Recovery step 3, line 1 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep3b]",
            value: "    Emergency Access → \"Recover from Shares\". Any M of your N shares reveal it.",
            comment: "Recovery step 3, line 2 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep4]",
            value: "4. Each share alone reveals nothing. Never keep all shares together.",
            comment: "Recovery step 4 (Emergency Kit PDF)"),
        NSLocalizedString(
            "[Emergency/Kit/PDFStep5]",
            value: "5. PassPouch is fully offline-capable: no account, no server, no telemetry.",
            comment: "Recovery step 5 (Emergency Kit PDF)")
    ]

    public static let emergencyCombinePlaceholder = NSLocalizedString(
        "[Emergency/Combine/Placeholder]",
        value: "Paste shares here, one per line (PPSH1-…)",
        comment: "Placeholder of the share-input field in the combine screen")

    public static let emergencyCombineButton = NSLocalizedString(
        "[Emergency/Combine/Button]",
        value: "Reveal Password",
        comment: "Button that combines shares and reveals the master password once")

    public static let emergencyRevealOnceWarning = NSLocalizedString(
        "[Emergency/Reveal/Warning]",
        value: "The password is shown once and never stored. Memorize or write it down, then close.",
        comment: "Warning shown with the revealed master password")

    public static let emergencyNotEnoughShares = NSLocalizedString(
        "[Emergency/Combine/NotEnough]",
        value: "Not enough valid shares to reconstruct the password.",
        comment: "Error when too few shares were provided")

    public static let emergencyBadShares = NSLocalizedString(
        "[Emergency/Combine/BadShares]",
        value: "The shares do not match — they may be from different splits, damaged, or tampered with.",
        comment: "Error when share reconstruction fails validation")

    // swiftlint:enable line_length
}
