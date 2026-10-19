//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import Foundation
import KeePassiumLib
import UIKit

/// Offline Emergency Kit PDF (Phase 11c, ADR-016), built with
/// UIGraphicsPDFRenderer — no third-party dependency.
///
/// Contents: PassPouch identity + app version, the list of known database
/// file locations, offline recovery instructions, and a user-optional
/// manual hint field.
///
/// Security: the master password is NEVER inserted into the PDF — neither
/// automatically nor by this code path. The hint field is typed manually
/// by the user and its content is their responsibility.
enum EmergencyKitPDF {
    static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi

    /// Generates the kit PDF. `databaseLocations` are human-readable names
    /// of the user's registered databases; `manualHint` is whatever the
    /// user chose to write (never auto-filled).
    static func generate(
        appVersion: String,
        databaseLocations: [String],
        manualHint: String
    ) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "PassPouch Emergency Kit",
            kCGPDFContextCreator as String: "PassPouch"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()

            var y: CGFloat = 48
            draw("PassPouch — Emergency Kit", at: &y,
                 font: .boldSystemFont(ofSize: 22), color: .black)
            draw("App version: \(appVersion)   Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))",
                 at: &y, font: .systemFont(ofSize: 10), color: .darkGray)

            y += 12
            draw("Your databases", at: &y, font: .boldSystemFont(ofSize: 14), color: .black)
            if databaseLocations.isEmpty {
                draw("No databases found.", at: &y, font: .systemFont(ofSize: 11), color: .darkGray)
            } else {
                for location in databaseLocations {
                    draw("•  \(location)", at: &y, font: .systemFont(ofSize: 11), color: .black)
                }
            }

            y += 12
            draw("How to recover access (offline)", at: &y,
                 font: .boldSystemFont(ofSize: 14), color: .black)
            for line in recoveryInstructions {
                draw(line, at: &y, font: .systemFont(ofSize: 11), color: .darkGray)
            }

            y += 12
            draw("My hints (written by hand)", at: &y,
                 font: .boldSystemFont(ofSize: 14), color: .black)
            draw(manualHint.isEmpty ? "—" : manualHint, at: &y,
                 font: .systemFont(ofSize: 11), color: .black)

            y += 16
            draw(
                "PassPouch never stores or prints your master password. Keep this kit "
                    + "and any Shamir share slips in separate, safe places.",
                at: &y, font: .italicSystemFont(ofSize: 10), color: .darkGray)
        }
    }

    private static var recoveryInstructions: [String] {
        [
            "1. Find the database file (.kdbx) listed above — on this device, in iCloud Drive,",
            "    or in your cloud/WebDAV storage. Copy it to a safe place.",
            "2. Open PassPouch on any iOS device and unlock the database with your master",
            "    password (or key file, if you use one).",
            "3. If the master password is lost, use your printed Shamir shares: Settings →",
            "    Emergency Access → \"Recover from Shares\". Any M of your N shares reveal it.",
            "4. Each share alone reveals nothing. Never keep all shares together.",
            "5. PassPouch is fully offline-capable: no account, no server, no telemetry."
        ]
    }

    private static func draw(
        _ text: String,
        at y: inout CGFloat,
        font: UIFont,
        color: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let maxWidth = pageRect.width - 2 * 48
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil)
        let rect = CGRect(x: 48, y: y, width: maxWidth, height: ceil(bounding.height))
        (text as NSString).draw(in: rect, withAttributes: attributes)
        y += ceil(bounding.height) + 4
    }
}
