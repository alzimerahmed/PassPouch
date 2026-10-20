//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

/// Phase 11a (Watch companion) tests: snapshot builder/sanitizer, TOTP
/// parameter extraction, RFC 6238 code generation and display formatting.
final class Phase11WatchTests: XCTestCase {
    // MARK: - Helpers

    private func makeDatabase() throws -> (Database2, Group2) {
        let db = Database2.makeNewV4(.v4)
        let root = try XCTUnwrap(db.root as? Group2)
        return (db, root)
    }

    private func makeEntry(
        in group: Group2,
        title: String,
        userName: String = "user",
        password: String,
        otp: String? = nil,
        totpSeed: String? = nil,
        totpSettings: String? = nil,
        timeOtpSecret: String? = nil
    ) -> Entry2 {
        let entry = Entry2(database: group.database)
        entry.uuid = UUID()
        entry.rawTitle = title
        entry.rawUserName = userName
        entry.rawPassword = password
        if let otp {
            entry.setField(name: EntryField.otp, value: otp, isProtected: true)
        }
        if let totpSeed {
            entry.setField(name: EntryField.otpConfig2Seed, value: totpSeed, isProtected: true)
        }
        if let totpSettings {
            entry.setField(name: EntryField.otpConfig2Settings, value: totpSettings)
        }
        if let timeOtpSecret {
            entry.setField(name: EntryField.timeOtpSecret, value: timeOtpSecret, isProtected: true)
        }
        group.add(entry: entry)
        return entry
    }

    // MARK: - Snapshot builder: selection + sanitization

    func testEmptySelectionProducesNoSnapshot() throws {
        let (db, root) = try makeDatabase()
        _ = makeEntry(in: root, title: "Site", password: "secret")
        XCTAssertNil(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: []
            ),
            "Privacy-first: with nothing selected, no snapshot must be built."
        )
    }

    func testOnlySelectedEntriesAreIncluded() throws {
        let (db, root) = try makeDatabase()
        let shared = makeEntry(in: root, title: "Shared", password: "s1")
        _ = makeEntry(in: root, title: "Private", password: "s2")

        let snapshot = try XCTUnwrap(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: [shared.uuid]
            )
        )
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries[0].id, shared.uuid.uuidString)
        XCTAssertEqual(snapshot.entries[0].title, "Shared")
        XCTAssertEqual(snapshot.entries[0].password, "s1")
        XCTAssertFalse(snapshot.entries.map { $0.title }.contains("Private"))
    }

    func testSelectedEntriesInNestedGroupsAreFound() throws {
        let (db, root) = try makeDatabase()
        let subgroup = Group2(database: db)
        subgroup.name = "Nested"
        root.add(group: subgroup)
        let entry = makeEntry(in: subgroup, title: "Deep", password: "p")

        let snapshot = try XCTUnwrap(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: [entry.uuid]
            )
        )
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries[0].title, "Deep")
    }

    func testSnapshotSanitizesAndSkipsUselessEntries() throws {
        let (db, root) = try makeDatabase()
        // No password and no TOTP: nothing useful on the watch — skipped.
        _ = makeEntry(in: root, title: "Bare", password: "")
        // Long values are truncated; whitespace trimmed.
        let longPassword = String(repeating: "x", count: 1000)
        let padded = makeEntry(in: root, title: "  Padded  ", password: "  \(longPassword)  ")

        let snapshot = try XCTUnwrap(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: [padded.uuid]
            )
        )
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries[0].title, "Padded")
        XCTAssertEqual(snapshot.entries[0].password.count, WatchSnapshotBuilder.maxFieldLength)
    }

    func testSnapshotEntryCountIsCapped() throws {
        let (db, root) = try makeDatabase()
        var selected = Set<UUID>()
        for index in 0..<(WatchSnapshotBuilder.maxEntries + 5) {
            let entry = makeEntry(in: root, title: "Entry \(index)", password: "p\(index)")
            selected.insert(entry.uuid)
        }
        let snapshot = try XCTUnwrap(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: selected
            )
        )
        XCTAssertEqual(snapshot.entries.count, WatchSnapshotBuilder.maxEntries)
    }

    func testSnapshotCodableRoundTrip() throws {
        let (db, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "GitHub",
            password: "s3cret",
            otp: "otpauth://totp/GitHub:octocat?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
        )
        let snapshot = try XCTUnwrap(
            WatchSnapshotBuilder.buildSnapshot(
                database: db,
                databaseName: "test.kdbx",
                selectedEntryIDs: [entry.uuid]
            )
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WatchSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    // MARK: - TOTP parameter extraction (reuses TOTPGeneratorFactory as gate)

    func testTOTPParamsFromOTPAuthURI() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "T",
            password: "p",
            otp: "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&period=60&digits=8&algorithm=SHA256"
        )
        let params = try XCTUnwrap(WatchSnapshotBuilder.totpParams(for: entry))
        XCTAssertEqual(params.base32Seed, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(params.period, 60)
        XCTAssertEqual(params.digits, 8)
        XCTAssertEqual(params.algorithm, "SHA256")
    }

    func testTOTPParamsFromSplitFields() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "T",
            password: "p",
            totpSeed: "JBSWY3DPEHPK3PXP",
            totpSettings: "30;6"
        )
        let params = try XCTUnwrap(WatchSnapshotBuilder.totpParams(for: entry))
        XCTAssertEqual(params.period, 30)
        XCTAssertEqual(params.digits, 6)
        XCTAssertEqual(params.algorithm, "SHA1")
    }

    func testTOTPParamsFromKeePassTimeOtpFields() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "T",
            password: "p",
            timeOtpSecret: "JBSWY3DPEHPK3PXP"
        )
        let params = try XCTUnwrap(WatchSnapshotBuilder.totpParams(for: entry))
        XCTAssertEqual(params.algorithm, "SHA1")
        XCTAssertEqual(params.period, WatchTOTPCore.defaultPeriod)
    }

    func testSteamTOTPNotSharedToWatch() throws {
        let (_, root) = try makeDatabase()
        let otpEntry = makeEntry(
            in: root,
            title: "T",
            password: "p",
            otp: "otpauth://totp/Steam:me?secret=JBSWY3DPEHPK3PXP&encoder=steam"
        )
        let splitEntry = makeEntry(
            in: root,
            title: "T2",
            password: "p",
            totpSeed: "JBSWY3DPEHPK3PXP",
            totpSettings: "30;S"
        )
        XCTAssertNil(WatchSnapshotBuilder.totpParams(for: otpEntry))
        XCTAssertNil(WatchSnapshotBuilder.totpParams(for: splitEntry))
    }

    func testEntryWithoutTOTPHasNoParams() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(in: root, title: "T", password: "p")
        XCTAssertNil(WatchSnapshotBuilder.totpParams(for: entry))
    }

    func testInvalidSeedIsRejected() throws {
        let (_, root) = try makeDatabase()
        let entry = makeEntry(
            in: root,
            title: "T",
            password: "p",
            otp: "otpauth://totp/T?secret=!!!not-base32!!!"
        )
        XCTAssertNil(WatchSnapshotBuilder.totpParams(for: entry))
    }

    // MARK: - RFC 6238 code generation (RFC 6238 appendix test vectors)

    /// Seed = ASCII "12345678901234567890" (RFC 6238 test secret).
    private let rfcSeed = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ======"

    private func rfcParams(digits: Int, algorithm: String = "SHA1") -> WatchTOTPParams {
        return WatchTOTPParams(
            base32Seed: rfcSeed,
            period: 30,
            digits: digits,
            algorithm: algorithm
        )
    }

    func testTOTPRFC6238Vectors() {
        let t59 = Date(timeIntervalSince1970: 59)
        let t1111111109 = Date(timeIntervalSince1970: 1_111_111_109)
        XCTAssertEqual(
            WatchTOTPCore.generateCode(params: rfcParams(digits: 8), at: t59),
            "94287082"
        )
        XCTAssertEqual(
            WatchTOTPCore.generateCode(params: rfcParams(digits: 8), at: t1111111109),
            "07081804"
        )
        XCTAssertEqual(
            WatchTOTPCore.generateCode(params: rfcParams(digits: 6), at: t59),
            "287082"
        )
    }

    func testTOTPSHA256Vector() {
        // RFC 6238: SHA256, seed = "12345678901234567890123456789012" (32 bytes),
        // T=1111111109 → 68084774 (8 digits). Base32 of that seed:
        let seed32 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA===="
        let params = WatchTOTPParams(
            base32Seed: seed32,
            period: 30,
            digits: 8,
            algorithm: "SHA256"
        )
        XCTAssertEqual(
            WatchTOTPCore.generateCode(params: params, at: Date(timeIntervalSince1970: 1_111_111_109)),
            "68084774"
        )
    }

    func testTOTPInvalidParamsReturnNil() {
        XCTAssertNil(WatchTOTPCore.generateCode(params: rfcParams(digits: 3)))
        XCTAssertNil(WatchTOTPCore.generateCode(params: rfcParams(digits: 9)))
        var badSeed = rfcParams(digits: 6)
        badSeed.base32Seed = "not-base32!"
        XCTAssertNil(WatchTOTPCore.generateCode(params: badSeed))
        var badPeriod = rfcParams(digits: 6)
        badPeriod.period = 0
        XCTAssertNil(WatchTOTPCore.generateCode(params: badPeriod))
    }

    func testDisplayFormatting() {
        XCTAssertEqual(WatchTOTPCore.formatForDisplay("123456"), "123 456")
        XCTAssertEqual(WatchTOTPCore.formatForDisplay("12345678"), "1234 5678")
        XCTAssertEqual(WatchTOTPCore.formatForDisplay("12345"), "12345") // odd → unchanged
    }

    // MARK: - Selection store

    func testSelectionStoreDefaultsToPrivacyFirst() {
        let defaults = UserDefaults(suiteName: "Phase11WatchTests")!
        defaults.removePersistentDomain(forName: "Phase11WatchTests")
        let store = WatchSelectionStore(defaults: defaults)
        XCTAssertFalse(store.isSharingEnabled)
        XCTAssertTrue(store.selectedEntryIDs.isEmpty)
    }

    func testSelectionStoreRoundTripAndMasterToggleClearsSelection() {
        let defaults = UserDefaults(suiteName: "Phase11WatchTests")!
        defaults.removePersistentDomain(forName: "Phase11WatchTests")
        let store = WatchSelectionStore(defaults: defaults)

        store.isSharingEnabled = true
        let id = UUID()
        store.selectedEntryIDs = [id]
        XCTAssertEqual(store.selectedEntryIDs, [id])

        // Turning the master toggle off must wipe the selection.
        store.isSharingEnabled = false
        XCTAssertTrue(store.selectedEntryIDs.isEmpty)
    }
}
