//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI
import UIKit

/// Read-only viewer for a received share link (ADR-015). Shows the
/// decrypted fields with copy buttons, a clear "shared snapshot" banner,
/// and auto-expires the display after a short on-screen window.
struct SharedItemView: View {
    let payload: SharePayload
    let onDismiss: () -> Void

    @State private var remainingSeconds: Int
    @State private var timer: Timer?

    /// On-screen display window for a shared snapshot, in seconds.
    static let displayWindowSeconds = 60
    /// Remaining-seconds value at which a VoiceOver announcement is posted.
    static let announcementAtSecondsRemaining = 10

    init(payload: SharePayload, onDismiss: @escaping () -> Void) {
        self.payload = payload
        self.onDismiss = onDismiss
        _remainingSeconds = State(initialValue: Self.displayWindowSeconds)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(LString.sharedItemBanner, systemImage: "envelope.badge.shield.half.filled")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(countdownText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let expiresAt = payload.expiresAt {
                    Section {
                        Label(
                            expiryText(expiresAt),
                            systemImage: "clock.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text(LString.sharedItemTitle)) {
                    ForEach(sortedFieldNames, id: \.self) { name in
                        SharedItemFieldRow(
                            fieldName: name,
                            value: payload.fields[name] ?? "")
                    }
                }
            }
            .navigationTitle(LString.sharedItemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if timer != nil {
                        Button(LString.sharedItemKeepOpen) {
                            stopCountdown()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LString.actionDone) { onDismiss() }
                }
            }
        }
        .onAppear(perform: startCountdown)
        .onDisappear(perform: stopCountdown)
    }

    private var countdownText: String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "[SharedItem/countdown]",
                value: "Auto-closes in %d s",
                comment: "Shared-item auto-close countdown. Parameter: seconds remaining"),
            remainingSeconds)
    }

    private var sortedFieldNames: [String] {
        payload.fields.keys.sorted()
    }

    private func expiryText(_ expiresAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return String.localizedStringWithFormat(
            NSLocalizedString(
                "[SharedItem/expiresAt]",
                value: "Expires: %@",
                comment: "Shared-item expiry display. First parameter: date/time"),
            formatter.string(from: expiresAt))
    }

    private func startCountdown() {
        stopCountdown()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            remainingSeconds -= 1
            if remainingSeconds == Self.announcementAtSecondsRemaining {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: countdownText)
            }
            if remainingSeconds <= 0 {
                stopCountdown()
                onDismiss()
            }
        }
    }

    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
    }
}

/// One field row with a copy button. Values are never logged. The password
/// field is masked by default with an eye/eye-slash reveal toggle.
struct SharedItemFieldRow: View {
    let fieldName: String
    let value: String

    @State private var isValueRevealed = false

    private var isPasswordField: Bool { fieldName == EntryField.password }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                if isPasswordField {
                    Button {
                        isValueRevealed.toggle()
                    } label: {
                        Image(systemName: isValueRevealed ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(isValueRevealed
                        ? LString.a11yHideValue
                        : LString.a11yShowValue)
                }
                Button {
                    Clipboard.general.copyWithTimeout(value)
                    HapticFeedback.play(.copiedToClipboard)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: LString.titleCopiedToClipboard)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(LString.actionCopy)
            }
            Text(displayValue)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private var displayValue: String {
        if isPasswordField && !isValueRevealed {
            return String(repeating: "•", count: max(value.count, 1))
        }
        return value
    }

    private var displayName: String {
        switch fieldName {
        case EntryField.title: return LString.shareFieldTitle
        case EntryField.userName: return LString.shareFieldUserName
        case EntryField.password: return LString.shareFieldPassword
        case EntryField.url: return LString.shareFieldURL
        case EntryField.notes: return LString.shareFieldNotes
        default: return fieldName
        }
    }
}

/// Presents the received share snapshot modally. The decrypted payload
/// lives only in memory of this screen; nothing is persisted.
final class SharedItemCoordinator: BaseCoordinator {
    private let payload: SharePayload
    private lazy var hostingController: UIHostingController<SharedItemView> = {
        let view = SharedItemView(payload: payload) { [weak self] in
            self?.dismiss()
        }
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .systemBackground
        return controller
    }()

    init(payload: SharePayload, router: NavigationRouter) {
        self.payload = payload
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: false)
    }
}
