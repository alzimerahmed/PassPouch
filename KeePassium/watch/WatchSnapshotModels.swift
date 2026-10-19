//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

/// Wire format for the sanitized entry snapshot sent to the watchOS companion
/// app over WatchConnectivity (ADR-013). Deliberately minimal: only fields the
/// watch needs for its read-only quick view. Notes, URLs, attachments and all
/// other custom fields are never included.
public struct WatchEntrySnapshot: Codable, Equatable {
    /// Entry UUID as a string (stable across snapshot refreshes).
    public let id: String
    public let title: String
    public let userName: String
    public let password: String
    /// TOTP parameters for live code generation on the watch, if the entry has TOTP.
    public let totp: WatchTOTPParams?

    public init(
        id: String,
        title: String,
        userName: String,
        password: String,
        totp: WatchTOTPParams?
    ) {
        self.id = id
        self.title = title
        self.userName = userName
        self.password = password
        self.totp = totp
    }
}

/// Snapshot of the currently-unlocked database's explicitly shared entries.
public struct WatchSnapshot: Codable, Equatable {
    public let databaseName: String
    public let generatedAt: Date
    public let entries: [WatchEntrySnapshot]

    public init(databaseName: String, generatedAt: Date, entries: [WatchEntrySnapshot]) {
        self.databaseName = databaseName
        self.generatedAt = generatedAt
        self.entries = entries
    }
}

/// Message keys for the WatchConnectivity protocol between the iOS app and the
/// watch app (ADR-013). Values are plain JSON-encoded payloads.
public enum WatchMessage {
    /// Data (JSON-encoded `WatchSnapshot`) sent phone → watch.
    public static let snapshotData = "passpouch.snapshot.data"
    /// Boolean sent phone → watch when the database locks: wipe the snapshot.
    public static let locked = "passpouch.snapshot.locked"
    /// Boolean sent watch → phone asking for a fresh snapshot.
    public static let snapshotRequest = "passpouch.snapshot.request"
}
