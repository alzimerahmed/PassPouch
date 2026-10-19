//  PassPouch — Testing Foundation (Phase 5)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

@testable import KeePassiumLib
import XCTest

/// KDBX 3/4 round-trip tests: create a database in memory, save it, reload it,
/// and assert content fidelity. Guards the trusted core (KeePassiumLib) against
/// regressions in format/crypto handling.
final class KDBXRoundTripTests: XCTestCase {
    private let masterPassword = "correct horse battery staple"

    // MARK: - Fixtures

    private func makeCompositeKey(password: String) throws -> CompositeKey {
        let keyHelper = KeyHelper2()
        let passwordData = keyHelper.getPasswordData(password: password)
        let combined = try keyHelper.combineComponents(
            passwordData: passwordData,
            keyFileData: SecureBytes.empty())
        return CompositeKey(staticComponents: combined, challengeHandler: nil)
    }

    /// Creates an in-memory KDBX database with a known content set, using
    /// deliberately weak KDF parameters to keep CI fast.
    private func makeDatabase(formatVersion: Database2.FormatVersion) throws -> Database2 {
        let db = Database2.makeNewV4(.v4)
        guard let root = db.root as? Group2 else {
            XCTFail("New database must have a Group2 root")
            throw DatabaseError.loadError(reason: .formatError(reason: "No root group"))
        }

        let group = Group2(database: db)
        group.name = "Web"
        root.add(group: group)

        let entry = Entry2(database: db)
        entry.setField(name: EntryField.title, value: "Example")
        entry.setField(name: EntryField.userName, value: "alice")
        entry.setField(name: EntryField.password, value: "s3cr3t!", isProtected: true)
        entry.setField(name: EntryField.url, value: "https://example.com/login")
        entry.setField(name: EntryField.notes, value: "Round-trip fixture")
        entry.setField(
            name: EntryField.totp,
            value: "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        group.add(entry: entry)

        switch formatVersion {
        case .v3:
            db.header.setFormatVersionForTesting(.v3)
            db.header.applyEncryptionSettings(settings: EncryptionSettings(
                dataCipher: .aes,
                kdf: .aesKdf,
                iterations: 1000,
                memory: nil,
                parallelism: nil))
            // KDBX3 requires the legacy Salsa20 inner stream cipher.
            db.header.innerStreamAlgorithm = .Salsa20
        case .v4:
            db.header.applyEncryptionSettings(settings: EncryptionSettings(
                dataCipher: .chaCha20,
                kdf: .argon2id,
                iterations: 2,
                memory: 1 << 20,
                parallelism: 1))
        case .v4_1:
            db.header.applyEncryptionSettings(settings: EncryptionSettings(
                dataCipher: .twofish,
                kdf: .argon2d,
                iterations: 2,
                memory: 1 << 20,
                parallelism: 1))
        }

        db.changeCompositeKey(to: try makeCompositeKey(password: masterPassword))
        return db
    }

    private func reload(_ data: ByteArray, password: String) throws -> Database2 {
        let db = Database2()
        let warnings = DatabaseLoadingWarnings()
        try db.load(
            dbFileName: "round-trip.kdbx",
            dbFileData: data,
            compositeKey: try makeCompositeKey(password: password),
            useStreams: false,
            warnings: warnings)
        return db
    }

    private func assertRoundTrip(formatVersion: Database2.FormatVersion) throws {
        let db = try makeDatabase(formatVersion: formatVersion)
        let savedData = try db.save()
        XCTAssertFalse(savedData.isEmpty, "Saved database must not be empty")

        let reloaded = try reload(savedData, password: masterPassword)

        XCTAssertEqual(reloaded.root?.name, "/", "Root group name must survive the round trip")
        XCTAssertEqual(reloaded.header.formatVersion, formatVersion, "Format version must persist")

        var allEntries = [Entry]()
        reloaded.root?.collectAllEntries(to: &allEntries)
        XCTAssertEqual(allEntries.count, 1, "Entry count must survive the round trip")

        guard let entry = allEntries.first as? Entry2 else {
            XCTFail("Reloaded entry must be an Entry2")
            return
        }
        XCTAssertEqual(entry.resolvedTitle, "Example")
        XCTAssertEqual(entry.resolvedUserName, "alice")
        XCTAssertEqual(entry.resolvedPassword, "s3cr3t!", "Protected field must survive the round trip")
        XCTAssertEqual(entry.resolvedURL, "https://example.com/login")
        XCTAssertEqual(entry.resolvedNotes, "Round-trip fixture")
        XCTAssertTrue(entry.hasValidTOTP, "TOTP configuration must survive the round trip")

        var groupNames = [String]()
        reloaded.root?.applyToAllChildren(
            groupHandler: { groupNames.append($0.name) },
            entryHandler: nil)
        XCTAssertEqual(groupNames, ["Web"], "Group hierarchy must survive the round trip")
    }

    // MARK: - Round trips

    func testRoundTripKDBX3_AES_AESKDF() throws {
        try assertRoundTrip(formatVersion: .v3)
    }

    func testRoundTripKDBX4_Argon2ID_ChaCha20() throws {
        try assertRoundTrip(formatVersion: .v4)
    }

    func testRoundTripKDBX41_Argon2D_Twofish() throws {
        try assertRoundTrip(formatVersion: .v4_1)
    }

    // MARK: - Modify → save → reload

    func testModificationSurvivesResave() throws {
        let db = try makeDatabase(formatVersion: .v4)
        var allEntries = [Entry]()
        db.root?.collectAllEntries(to: &allEntries)
        guard let entry = allEntries.first as? Entry2 else {
            XCTFail("Fixture entry must be an Entry2")
            return
        }

        entry.setField(name: EntryField.password, value: "rotated-secret")
        entry.rawTitle = "Example (renamed)"

        let savedData = try db.save()
        let reloaded = try reload(savedData, password: masterPassword)

        var reloadedEntries = [Entry]()
        reloaded.root?.collectAllEntries(to: &reloadedEntries)
        guard let reloadedEntry = reloadedEntries.first as? Entry2 else {
            XCTFail("Reloaded entry must be an Entry2")
            return
        }
        XCTAssertEqual(reloadedEntry.resolvedPassword, "rotated-secret")
        XCTAssertEqual(reloadedEntry.resolvedTitle, "Example (renamed)")
        XCTAssertEqual(reloadedEntry.resolvedUserName, "alice", "Untouched fields must persist")
    }

    // MARK: - Key handling

    func testReloadWithWrongPasswordFails() throws {
        let db = try makeDatabase(formatVersion: .v4)
        let savedData = try db.save()

        XCTAssertThrowsError(try reload(savedData, password: "wrong password"))
    }

    func testReloadWithWrongPasswordFailsKDBX3() throws {
        let db = try makeDatabase(formatVersion: .v3)
        let savedData = try db.save()

        XCTAssertThrowsError(try reload(savedData, password: "wrong password"))
    }
}
