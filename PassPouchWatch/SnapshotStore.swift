//  PassPouch — Password Manager (watchOS companion)
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
import Security

/// Keychain-backed storage for the watch snapshot (ADR-013). One generic
/// password item, device-only accessibility, no plain-file persistence.
enum SnapshotStore {
    private enum Constants {
        static let service = "com.passpouch.watch.snapshot"
        static let account = "snapshot"
    }

    static func save(data: Data) {
        guard let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else {
            clear()
            return
        }
        guard let payload = try? JSONEncoder().encode(snapshot) else {
            return
        }
        clear()

        var query = baseQuery()
        query[kSecValueData as String] = payload
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> WatchSnapshot? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(WatchSnapshot.self, from: data)
    }

    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: Constants.account
        ]
    }
}
