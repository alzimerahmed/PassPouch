//  PassPouch — Feature: Quick Wins (Phase 6)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

import SwiftUI
import UIKit
import WidgetKit

/// Recent-entries widget: metadata only (entry title + user name), dark mode
/// and Dynamic Type via system text styles, no hardcoded colors.
struct RecentEntriesWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: RecentEntry

    var body: some View {
        content
            .widgetURL(widgetFamily == .systemSmall ? DeepLink.openApp : nil)
            .containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
    }

    @ViewBuilder
    private var content: some View {
        if entry.entries.isEmpty {
            emptyState
        } else if widgetFamily == .systemSmall {
            // Small widgets ignore per-row Links — one tap target for the
            // whole widget (opens the app).
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(entry.entries.first?.title ?? "Recent Entries")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            listState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No recent entries")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(DeepLink.openApp)
    }

    private var listState: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(entry.entries.prefix(maxVisibleRows)) { recent in
                row(for: recent)
                if recent.id != visibleEntries.last?.id {
                    Divider()
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "key.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Recent Entries")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.bottom, 6)
    }

    private var visibleEntries: [SharedRecentEntry] {
        Array(entry.entries.prefix(maxVisibleRows))
    }

    private var maxVisibleRows: Int {
        // systemMedium fits ~3 rows comfortably; systemSmall shows only the header CTA.
        3
    }

    private func row(for recent: SharedRecentEntry) -> some View {
        Link(destination: DeepLink.entry(recent.entryUUID)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recent.title)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !recent.userName.isEmpty {
                    Text(recent.userName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the entry in PassPouch"))
    }
}

enum DeepLink {
    static let openApp = URL(string: "passpouch://open")!
    static func entry(_ uuid: UUID) -> URL {
        URL(string: "passpouch://entry/\(uuid.uuidString)")!
    }
}
