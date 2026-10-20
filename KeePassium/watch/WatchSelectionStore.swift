//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

/// User's watch-sharing preferences (ADR-013): a master toggle plus the
/// explicit per-entry selection. Privacy-first: the default is OFF and an
/// empty selection, so nothing is ever shared without explicit opt-in.
/// Stored in the app-local `UserDefaults` under the `PassPouch.*` namespace
/// (ADR-006) — no App Group involved.
public final class WatchSelectionStore {
    public static let shared = WatchSelectionStore()

    private enum Keys {
        static let isSharingEnabled = "PassPouch.watch.isSharingEnabled"
        static let selectedEntryIDs = "PassPouch.watch.selectedEntryIDs"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Master toggle. When turned off, the selection is cleared immediately.
    public var isSharingEnabled: Bool {
        get { defaults.bool(forKey: Keys.isSharingEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.isSharingEnabled)
            if !newValue {
                selectedEntryIDs = []
            }
        }
    }

    /// Explicitly selected entry UUIDs. Only meaningful while
    /// `isSharingEnabled` is true.
    public var selectedEntryIDs: Set<UUID> {
        get {
            let raw = defaults.stringArray(forKey: Keys.selectedEntryIDs) ?? []
            return Set(raw.compactMap(UUID.init(uuidString:)))
        }
        set {
            defaults.set(Array(newValue).map { $0.uuidString }, forKey: Keys.selectedEntryIDs)
        }
    }
}
