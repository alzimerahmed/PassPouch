//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import CoreImage
import CoreImage.CIFilterBuiltins
import KeePassiumLib
import SwiftUI
import UIKit

// MARK: - QR helper (no dependency; CoreImage is a system framework)

enum QRImageMaker {
    static func makeQRCode(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Split screen

/// Splits a manually entered master password into printable Shamir shares
/// (ADR-016). The password and shares live only in memory; nothing is
/// persisted and nothing leaves the device.
struct ShamirSplitView: View {
    @State private var password = ""
    @State private var sharesCount = 5
    @State private var threshold = 3
    @State private var shares: [Shamir.Share] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LString.emergencySplitExplanation)
                .font(.footnote)
                .foregroundColor(.secondary)
            SecureField(
                NSLocalizedString(
                    "[Emergency/Split/PasswordPlaceholder]",
                    value: "Master password",
                    comment: "Placeholder of the master-password field in the Shamir split screen"),
                text: $password)
            Stepper(
                "\(LString.emergencySharesCount): \(sharesCount)",
                value: $sharesCount, in: 2...10)
            Stepper(
                "\(LString.emergencyThresholdCount): \(threshold)",
                value: $threshold, in: 2...sharesCount)
                .onChange(of: sharesCount) { newCount in
                    if threshold > newCount { threshold = newCount }
                }
            Button(LString.emergencySplitButton) { splitPassword() }
                .disabled(password.isEmpty)
            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
            if !shares.isEmpty {
                Text(sharesHeader).font(.footnote).foregroundColor(.secondary)
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    ShareRow(index: index, shareText: Shamir.encodeShare(share))
                }
                Text(LString.emergencyKitWarning)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sharesHeader: String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "[Emergency/Split/SharesReady]",
                value: "Your %d shares — copy, print or scan them; store separately",
                comment: "Header of the generated Shamir shares list. Parameter: number of shares"),
            shares.count)
    }

    private func splitPassword() {
        shares = []
        errorMessage = nil
        do {
            let secret = Data(password.utf8)
            shares = try Shamir.split(
                secret: secret,
                threshold: threshold,
                sharesCount: sharesCount)
            password = "" // erase from memory as soon as possible
        } catch {
            Diag.error("Shamir split failed")
            errorMessage = error.localizedDescription
        }
    }
}

/// One printable share: text with copy/share buttons and a QR code.
struct ShareRow: View {
    let index: Int
    let shareText: String

    @State private var showQR = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Emergency/Split/ShareN]",
                        value: "Share %d",
                        comment: "Title of one Shamir share. Parameter: share number"),
                    index + 1))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    Clipboard.general.copyWithTimeout(shareText)
                    HapticFeedback.play(.copiedToClipboard)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: LString.titleCopiedToClipboard)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(LString.actionCopy)
                Button {
                    showQR = true
                } label: {
                    Image(systemName: "qrcode")
                }
                .accessibilityLabel(LString.actionShowAsQRCode)
            }
            Text(shareText)
                .font(.system(.caption, design: .monospaced))
        }
        .sheet(isPresented: $showQR) {
            ShareSheet(items: [shareText, QRImageMaker.makeQRCode(for: shareText)].compactMap { $0 })
        }
    }
}

// MARK: - Combine screen

/// Combines pasted/scanned shares and reveals the master password exactly
/// once. The result is never stored.
struct ShamirCombineView: View {
    @State private var sharesText = ""
    @State private var revealedPassword: String?
    @State private var errorMessage: String?
    @State private var autoClearTask: Task<Void, Never>?

    /// How long the revealed password stays on screen before being erased.
    private static let revealAutoClearSeconds: TimeInterval = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $sharesText)
                .frame(minHeight: 120)
                .font(.system(.footnote, design: .monospaced))
                .accessibilityLabel(LString.emergencyCombinePlaceholder)
                .accessibilityHint(LString.emergencyCombinePlaceholder)
            Button(LString.emergencyCombineButton) { combine() }
                .disabled(sharesText.isEmpty)
            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
            if let revealedPassword {
                Text(LString.emergencyRevealOnceWarning)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(revealedPassword)
                    .font(.system(.title3, design: .monospaced))
                    .accessibilityLabel(LString.emergencyRevealedPasswordA11y)
            }
        }
        .onDisappear {
            autoClearTask?.cancel()
            revealedPassword = nil
        }
    }

    private func combine() {
        revealedPassword = nil
        errorMessage = nil
        let lines = sharesText
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var shares: [Shamir.Share] = []
        for line in lines {
            do {
                shares.append(try Shamir.decodeShare(line))
            } catch {
                errorMessage = LString.emergencyBadShares
                return
            }
        }
        do {
            let secret = try Shamir.combine(shares: shares)
            guard let password = String(data: secret, encoding: .utf8) else {
                errorMessage = LString.emergencyBadShares
                return
            }
            revealedPassword = password
            scheduleAutoClear()
        } catch Shamir.ShamirError.notEnoughShares {
            errorMessage = LString.emergencyNotEnoughShares
        } catch {
            errorMessage = LString.emergencyBadShares
        }
        sharesText = "" // erase input as soon as possible
    }

    /// Erases the revealed password after a short window so it never
    /// lingers on screen unattended.
    private func scheduleAutoClear() {
        autoClearTask?.cancel()
        autoClearTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(Self.revealAutoClearSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            revealedPassword = nil
        }
    }
}

// MARK: - Shared UIKit helpers

/// UIActivityViewController wrapper for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Emergency Access container screen

/// Settings → Emergency Access (ADR-016): Emergency Kit PDF, Shamir split,
/// and share recovery — all offline.
struct EmergencyAccessView: View {
    let databaseLocations: [String]
    let appVersion: String
    let onGenerateKit: (String) -> Void // manualHint

    @State private var manualHint = ""

    var body: some View {
        Form {
            Section(header: Text(LString.emergencyKitSection)) {
                Text(LString.emergencyKitWarning)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                ForEach(databaseLocations, id: \.self) { location in
                    Label(location, systemImage: "doc")
                        .font(.footnote)
                }
                TextField(
                    LString.emergencyKitHintPlaceholder,
                    text: $manualHint,
                    axis: .vertical)
                    .lineLimit(2...4)
                Button(LString.emergencyKitGenerate) {
                    onGenerateKit(manualHint)
                }
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Section(header: Text(LString.emergencySplitSection)) {
                ShamirSplitView()
            }
            Section(header: Text(LString.emergencyCombineSection)) {
                ShamirCombineView()
            }
        }
    }
}
