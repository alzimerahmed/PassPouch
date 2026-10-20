//  PassPouch — Testing Foundation (Phase 5)
//  Copyright © 2025 Alzimer Ahmed. Part of PassPouch, a GPLv3 fork of KeePassium.
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/.

@testable import KeePassiumLib
import XCTest

/// Malformed-KDBX corpus tests. Fixtures are generated programmatically by
/// mutating a valid in-memory database — no binary fixtures are committed.
/// The contract under test: the loader must fail gracefully with a thrown
/// error (never crash, never hang) on corrupted input.
final class MalformedKDBXTests: XCTestCase {
    private let masterPassword = "correct horse battery staple"

    private func makeCompositeKey(password: String) throws -> CompositeKey {
        let keyHelper = KeyHelper2()
        let passwordData = keyHelper.getPasswordData(password: password)
        let combined = try keyHelper.combineComponents(
            passwordData: passwordData,
            keyFileData: SecureBytes.empty())
        return CompositeKey(staticComponents: combined, challengeHandler: nil)
    }

    /// A minimal valid KDBX4 database with weak KDF parameters, saved to bytes.
    private func makeValidDatabaseData() throws -> ByteArray {
        let db = Database2.makeNewV4(.v4)
        guard let root = db.root as? Group2 else {
            XCTFail("New database must have a Group2 root")
            throw DatabaseError.loadError(reason: .formatError(reason: "No root group"))
        }
        let entry = Entry2(database: db)
        entry.uuid = UUID()
        entry.setField(name: EntryField.title, value: "Example")
        entry.setField(name: EntryField.password, value: "s3cr3t!", isProtected: true)
        root.add(entry: entry)

        db.header.applyEncryptionSettings(settings: EncryptionSettings(
            dataCipher: .chaCha20,
            kdf: .argon2id,
            iterations: 2,
            memory: 1 << 20,
            parallelism: 1))
        db.changeCompositeKey(to: try makeCompositeKey(password: masterPassword))
        return try db.save()
    }

    private func assertLoadingFails(
        _ data: ByteArray,
        password: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let db = Database2()
        let warnings = DatabaseLoadingWarnings()
        XCTAssertThrowsError(
            try db.load(
                dbFileName: "malformed.kdbx",
                dbFileData: data,
                compositeKey: try makeCompositeKey(password: password),
                useStreams: false,
                warnings: warnings),
            "Corrupted input must fail with an error, not a crash",
            file: file,
            line: line)
    }

    // MARK: - Corpus

    func testEmptyFileFailsGracefully() throws {
        try assertLoadingFails(ByteArray(), password: masterPassword)
    }

    func testGarbageBytesFailGracefully() throws {
        let garbage = ByteArray(bytes: [UInt8](repeating: 0xA5, count: 1024))
        try assertLoadingFails(garbage, password: masterPassword)
    }

    func testWrongMagicNumberFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        var data = validData.asData
        // KDBX signatures are the first 8 bytes; scramble them.
        for index in 0..<8 {
            data[index] = 0xFF
        }
        try assertLoadingFails(ByteArray(data: data), password: masterPassword)
    }

    func testTruncatedFileFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        let truncated = validData.asData.prefix(validData.count / 2)
        XCTAssertFalse(truncated.isEmpty)
        try assertLoadingFails(ByteArray(data: Data(truncated)), password: masterPassword)
    }

    func testTruncatedToHeaderOnlyFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        let headerOnly = validData.asData.prefix(16)
        try assertLoadingFails(ByteArray(data: Data(headerOnly)), password: masterPassword)
    }

    func testCorruptedHeaderFieldFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        var data = validData.asData
        // Corrupt a version-signature byte (bytes 8..11 carry the KDBX format
        // version after the two 4-byte magic numbers) — the loader must
        // deterministically reject an unsupported/corrupt version.
        data[10] ^= 0xFF
        try assertLoadingFails(ByteArray(data: data), password: masterPassword)
    }

    func testCorruptedCiphertextFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        var data = validData.asData
        // Flip a byte near the end — inside the encrypted payload.
        data[data.count - 10] ^= 0xFF
        try assertLoadingFails(ByteArray(data: data), password: masterPassword)
    }

    func testWrongPasswordOnValidFileFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        try assertLoadingFails(validData, password: "not the password")
    }

    func testEmptyPasswordOnPasswordProtectedFileFailsGracefully() throws {
        let validData = try makeValidDatabaseData()
        try assertLoadingFails(validData, password: "")
    }
}
