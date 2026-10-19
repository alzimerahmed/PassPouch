//  PassPouch — Feature: Big Bets (Phase 11c)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import KeePassiumLib
import SwiftUI

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

    init(payload: SharePayload, onDismiss: @escaping () -> Void) {
        self.payload = payload
        self.onDismiss = onDismiss
        _remainingSeconds = State(initialValue: Self.displayWindowSeconds)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Label(LString.sharedItemBanner, systemImage: "envelope.badge.shield.half.filled")
                        .font(.footnote)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LString.actionDone) { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: startCountdown)
        .onDisappear(perform: stopCountdown)
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

/// One field row with a copy button. Values are never logged.
struct SharedItemFieldRow: View {
    let fieldName: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = value
                    HapticFeedback.play(.copiedToClipboard)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(LString.actionCopy)
            }
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
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
    private let hostingController: UIHostingController<SharedItemView>

    init(payload: SharePayload, router: NavigationRouter) {
        self.payload = payload
        let view = SharedItemView(payload: payload) { [weak self] in
            self?.dismiss()
        }
        hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .systemBackground
        super.init(router: router)
    }

    override func start() {
        super.start()
        _pushInitialViewController(hostingController, animated: false)
    }
}
