//  PassPouch — Password Manager (watchOS companion)
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

/// Wire format for the sanitized entry snapshot received from the iOS app
/// over WatchConnectivity (ADR-013). Must stay structurally identical to the
/// iOS-side `WatchSnapshotModels.swift` (the Codable payloads must round-trip).
struct WatchEntrySnapshot: Codable, Equatable {
    let id: String
    let title: String
    let userName: String
    let password: String
    let totp: WatchTOTPParams?
}

struct WatchSnapshot: Codable, Equatable {
    let databaseName: String
    let generatedAt: Date
    let entries: [WatchEntrySnapshot]
}

/// Message keys — must match the iOS-side `WatchMessage` enum (ADR-013).
enum WatchMessage {
    static let snapshotData = "passpouch.snapshot.data"
    static let locked = "passpouch.snapshot.locked"
    static let snapshotRequest = "passpouch.snapshot.request"
}
