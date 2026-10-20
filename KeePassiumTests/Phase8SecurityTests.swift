//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import CryptoKit
import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

/// Phase 8 (Security & Trust) pure-logic tests: HIBP k-anonymity helpers,
/// base64url decoding, passkey KPEX round-trip and Bitwarden passkey import.
final class Phase8SecurityTests: XCTestCase {
    // MARK: - SHA-1 hash / prefix

    func testSHA1HexHashKnownVectors() {
        // Well-known SHA-1 test vectors (uppercase hex).
        XCTAssertEqual(
            PasswordBreachCheck.sha1HexHash(of: "password"),
            "5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8")
        XCTAssertEqual(
            PasswordBreachCheck.sha1HexHash(of: ""),
            "DA39A3EE5E6B4B0D3255BFEF95601890AFD80709")
        XCTAssertEqual(
            PasswordBreachCheck.sha1HexHash(of: "abc"),
            "A9993E364706816ABA3E25717850C26C9CD0D89D")
    }

    func testHashPrefixIsFiveUppercaseHexChars() {
        let prefix = PasswordBreachCheck.hashPrefix(of: "password")
        XCTAssertEqual(prefix, "5BAA6")
        XCTAssertEqual(prefix.count, PasswordBreachCheck.defaultHashPrefixLength)
        XCTAssertTrue(prefix.allSatisfy({ $0.isHexDigit }))
        XCTAssertEqual(prefix, prefix.uppercased())
    }

    func testHashPrefixNeverContainsFullHash() {
        let password = "correct horse battery staple"
        let prefix = PasswordBreachCheck.hashPrefix(of: password)
        let fullHash = PasswordBreachCheck.sha1HexHash(of: password)
        XCTAssertLessThan(prefix.count, fullHash.count)
        XCTAssertTrue(fullHash.hasPrefix(prefix))
    }

    // MARK: - HIBP range response parsing

    func testParseRangeResponseValidLines() {
        let suffix35 = String(repeating: "A", count: 35)
        let text = """
        \(suffix35):5
        \(String(repeating: "b", count: 35)):0
        """
        let results = PasswordBreachCheck.parseRangeResponse(text)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].hashSuffix, suffix35)
        XCTAssertEqual(results[0].count, 5)
        XCTAssertEqual(results[1].hashSuffix, String(repeating: "B", count: 35))
        XCTAssertEqual(results[1].count, 0)
    }

    func testParseRangeResponseSkipsInvalidLines() {
        let validSuffix = String(repeating: "1", count: 35)
        let text = """
        no-colon-line
        \(validSuffix):not-a-number
        \(String(repeating: "2", count: 34)):-3
        \(String(repeating: "g", count: 35)):7
        \(String(repeating: "3", count: 36)):7
        :7
        \(validSuffix):12
        """
        let results = PasswordBreachCheck.parseRangeResponse(text)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].hashSuffix, validSuffix)
        XCTAssertEqual(results[0].count, 12)
    }

    func testParseRangeResponseDeduplicatesSuffixes() {
        let suffix = String(repeating: "A", count: 35)
        let text = "\(suffix):1\n\(suffix):2\n"
        let results = PasswordBreachCheck.parseRangeResponse(text)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].count, 1)
    }

    func testParseRangeResponseEmptyAndWhitespace() {
        XCTAssertTrue(PasswordBreachCheck.parseRangeResponse("").isEmpty)
        XCTAssertTrue(PasswordBreachCheck.parseRangeResponse("\n  \r\n").isEmpty)
    }

    func testBreachCountMatching() {
        let password = "password"
        let fullHash = PasswordBreachCheck.sha1HexHash(of: password)
        let suffix = String(fullHash.dropFirst(5))
        let otherSuffix = String(repeating: "F", count: 35)

        let results = [
            PasswordBreachCheck.RangeResult(hashSuffix: otherSuffix, count: 99),
            PasswordBreachCheck.RangeResult(hashSuffix: suffix, count: 12345),
        ]
        XCTAssertEqual(PasswordBreachCheck.breachCount(of: password, in: results), 12345)

        XCTAssertEqual(
            PasswordBreachCheck.breachCount(of: password, in: []),
            nil,
            "No matching suffix must mean 'not found', not zero")
    }

    // MARK: - base64url decoding (incl. padding fix)

    func testBase64URLRoundTripVariousLengths() {
        for length in 1...8 {
            let data = Data((0..<length).map { UInt8($0 * 17 + 3) })
            let encoded = data.base64URLEncodedString()
            XCTAssertFalse(encoded.contains("+"))
            XCTAssertFalse(encoded.contains("/"))
            XCTAssertFalse(encoded.contains("="))
            XCTAssertEqual(Data(base64URLEncoded: encoded), data, "length \(length)")
        }
    }

    func testBase64URLDecodeRequiresNoPaddingForLengthMod3() {
        // "ajA" (3 chars, length % 4 == 3) is base64url for bytes 0x6A 0x30.
        // Regression test: the old decoder appended the wrong amount of '='
        // padding for this case and failed to decode.
        XCTAssertEqual(Data(base64URLEncoded: "ajA"), Data([0x6A, 0x30]))
        XCTAssertEqual(Data(base64URLEncoded: "aGk"), Data([0x61, 0x69]))
    }

    // MARK: - Passkey KPEX field round-trip

    private func makeDatabase2() throws -> Database2 {
        let db = Database2.makeNewV4(.v4)
        guard db.root is Group2 else {
            XCTFail("New database must have a Group2 root")
            throw DatabaseError.loadError(reason: .formatError(reason: "No root group"))
        }
        return db
    }

    func testPasskeyEntryFieldRoundTrip() throws {
        let db = try makeDatabase2()
        let entry = Entry2(database: db)

        let credentialID = Data((0..<32).map { UInt8($0) })
        let userHandle = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let rpID = "example.com"
        let username = "alice@example.com"

        entry.setField(
            name: EntryField.passkeyCredentialID,
            value: credentialID.base64URLEncodedString(),
            isProtected: true)
        entry.setField(
            name: EntryField.passkeyPrivateKeyPEM,
            value: try P256TestKey.makePEM(),
            isProtected: true)
        entry.setField(name: EntryField.passkeyRelyingParty, value: rpID, isProtected: false)
        entry.setField(
            name: EntryField.passkeyUserHandle,
            value: userHandle.base64URLEncodedString(),
            isProtected: true)
        entry.setField(name: EntryField.passkeyUsername, value: username, isProtected: false)
        entry.setField(name: EntryField.passkeyFlagBE, value: "1", isProtected: false)
        entry.setField(name: EntryField.passkeyFlagBS, value: "0", isProtected: false)

        let passkey = Passkey.make(from: entry)
        XCTAssertNotNil(passkey)
        XCTAssertEqual(passkey?.credentialID, credentialID)
        XCTAssertEqual(passkey?.userHandle, userHandle)
        XCTAssertEqual(passkey?.relyingParty, rpID)
        XCTAssertEqual(passkey?.username, username)
        XCTAssertEqual(passkey?.beFlag, true)
        XCTAssertEqual(passkey?.bsFlag, false)

        switch Passkey.checkPresence(in: entry) {
        case .passkeyPresent(let isUsable):
            // bsFlag = false makes the passkey present but not usable.
            XCTAssertFalse(isUsable)
        case .noPasskey:
            XCTFail("Passkey presence was not detected")
        }
    }

    func testPasskeyPresenceAbsentForPlainEntry() throws {
        let db = try makeDatabase2()
        let entry = Entry2(database: db)
        entry.setField(name: EntryField.title, value: "Just a login")
        entry.setField(name: EntryField.password, value: "hunter2")
        switch Passkey.checkPresence(in: entry) {
        case .noPasskey:
            break
        case .passkeyPresent:
            XCTFail("Plain entry must not be detected as a passkey")
        }
    }

    // MARK: - Bitwarden fido2Credentials → Passkey conversion

    /// Builds a valid PKCS#8 (PrivateKeyInfo) DER for an EC P-256 key with the
    /// given scalar, mirroring the structure Bitwarden exports in `keyValue`.
    /// The embedded public key is derived from the scalar (real Bitwarden
    /// exports are self-consistent).
    private func makePKCS8DER(scalar: Data) throws -> Data {
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: scalar)
        let publicKey = privateKey.publicKey.rawRepresentation // 0x04 || X || Y

        var der = Data()
        der.append(contentsOf: [0x02, 0x01, 0x01]) // INTEGER 1 (version)
        der.append(contentsOf: [0x30, 0x13]) // AlgorithmIdentifier SEQUENCE
        der.append(contentsOf: [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]) // OID id-ecPublicKey
        der.append(contentsOf: [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]) // OID P-256
        der.append(contentsOf: [0x04, 0x6D]) // OCTET STRING (109 bytes)
        der.append(contentsOf: [0x30, 0x6B]) // ECPrivateKey SEQUENCE (107 bytes)
        der.append(contentsOf: [0x02, 0x01, 0x01]) // INTEGER 1
        der.append(contentsOf: [0x04, 0x20]) // OCTET STRING (32)
        der.append(scalar)
        der.append(contentsOf: [0xA1, 0x44]) // [1] explicit (68 bytes)
        der.append(contentsOf: [0x03, 0x42, 0x04]) // BIT STRING (66, 0 unused bits)
        der.append(publicKey) // 65 bytes: 0x04 || X || Y
        // outer SEQUENCE header
        var result = Data([0x30, UInt8(der.count)])
        result.append(der)
        return result
    }

    func testBitwardenFIDO2CredentialToPasskey() throws {
        let scalar = Data((1...32).map { UInt8($0) })
        let der = try makePKCS8DER(scalar: scalar)

        let credentialID = Data((0..<16).map { UInt8($0) })
        let userHandle = Data([0x01, 0x02, 0x03])

        let passkey = Passkey.make(
            fromBitwardenFIDO2Credential: credentialID.base64URLEncodedString(),
            privateKeyBase64URL: der.base64URLEncodedString(),
            relyingParty: "example.com",
            username: "bob@example.com",
            userHandleBase64URL: userHandle.base64URLEncodedString())

        XCTAssertNotNil(passkey)
        XCTAssertEqual(passkey?.credentialID, credentialID)
        XCTAssertEqual(passkey?.userHandle, userHandle)
        XCTAssertEqual(passkey?.relyingParty, "example.com")
        XCTAssertEqual(passkey?.username, "bob@example.com")

        // The produced PEM must parse as the same P-256 key.
        let pem = try XCTUnwrap(passkey?.privateKeyPEM)
        let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
        XCTAssertEqual(key.rawRepresentation, scalar)
    }

    func testBitwardenFIDO2CredentialRejectsGarbage() {
        XCTAssertNil(Passkey.make(
            fromBitwardenFIDO2Credential: "!!!not-base64url!!!",
            privateKeyBase64URL: "!!!not-base64url!!!",
            relyingParty: "example.com",
            username: "bob@example.com",
            userHandleBase64URL: "AAAA"))

        XCTAssertNil(Passkey.make(
            fromBitwardenFIDO2Credential: "AAAA",
            privateKeyBase64URL: "AAAA", // 3 zero bytes — not a PKCS#8 key
            relyingParty: "example.com",
            username: "bob@example.com",
            userHandleBase64URL: "AAAA"))
    }

    func testBitwardenFIDO2CredentialRejectsKeyMismatch() throws {
        // A DER whose embedded public key does not match the private scalar
        // must be rejected — a naive byte-scan would silently import a
        // wrong-but-valid key.
        let scalar = Data((1...32).map { UInt8($0) })
        var der = try makePKCS8DER(scalar: scalar)
        // Flip one byte inside the embedded public key (last byte of the DER).
        der[der.count - 1] ^= 0xFF

        XCTAssertNil(Passkey.make(
            fromBitwardenFIDO2Credential: "AAAA",
            privateKeyBase64URL: der.base64URLEncodedString(),
            relyingParty: "example.com",
            username: "bob@example.com",
            userHandleBase64URL: "AAAA"))
    }

    func testBitwardenImporterImportsPasskeys() throws {
        let scalar = Data((1...32).map { UInt8($0) })
        let der = try makePKCS8DER(scalar: scalar)
        let credentialID = Data((0..<16).map { UInt8($0) })
        let userHandle = Data([0x01, 0x02, 0x03])

        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Passkey Login",
                    "login": {
                        "username": "bob@example.com",
                        "password": "hunter2",
                        "fido2Credentials": [
                            {
                                "credentialId": "\(credentialID.base64URLEncodedString())",
                                "keyType": "public-key",
                                "keyAlgorithm": "ECDSA",
                                "keyCurve": "P-256",
                                "keyValue": "\(der.base64URLEncodedString())",
                                "rpId": "example.com",
                                "userHandle": "\(userHandle.base64URLEncodedString())",
                                "userName": "bob@example.com",
                                "discoverable": "true"
                            }
                        ]
                    }
                }
            ]
        }
        """

        let database = Database2.makeNewV4(.v4)
        let root = try XCTUnwrap(database.root as? Group2)
        let importer = BitwardenImporter()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (entries, _) = try importer.importFromJSON(fileURL: tempURL, group: root)
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries[0] as? Entry2)

        let passkey = try XCTUnwrap(Passkey.make(from: entry))
        XCTAssertEqual(passkey.credentialID, credentialID)
        XCTAssertEqual(passkey.userHandle, userHandle)
        XCTAssertEqual(passkey.relyingParty, "example.com")
        XCTAssertEqual(passkey.username, "bob@example.com")
        XCTAssertEqual(entry.rawPassword, "hunter2")
        XCTAssertEqual(entry.rawURL, "https://example.com")
    }

    // MARK: - KDBX round-trip of passkey fields

    func testPasskeyFieldsSurviveKDBXRoundTrip() throws {
        let masterPassword = "phase8-test"
        let db = try makeDatabase2()
        let root = try XCTUnwrap(db.root as? Group2)
        let entry = Entry2(database: db)
        entry.setField(name: EntryField.title, value: "Passkey entry")
        entry.setField(
            name: EntryField.passkeyCredentialID,
            value: Data(repeating: 7, count: 32).base64URLEncodedString(),
            isProtected: true)
        entry.setField(
            name: EntryField.passkeyPrivateKeyPEM,
            value: try P256TestKey.makePEM(),
            isProtected: true)
        entry.setField(name: EntryField.passkeyRelyingParty, value: "roundtrip.example", isProtected: false)
        entry.setField(
            name: EntryField.passkeyUserHandle,
            value: Data([0x42]).base64URLEncodedString(),
            isProtected: true)
        entry.setField(name: EntryField.passkeyUsername, value: "carol", isProtected: false)
        root.add(entry: entry)

        let keyHelper = KeyHelper2()
        let passwordData = keyHelper.getPasswordData(password: masterPassword)
        let combined = try keyHelper.combineComponents(
            passwordData: passwordData,
            keyFileData: SecureBytes.empty())
        db.changeCompositeKey(to: CompositeKey(staticComponents: combined, challengeHandler: nil))

        let data = try db.save()
        XCTAssertFalse(data.isEmpty)

        let reloaded = Database2()
        let warnings = DatabaseLoadingWarnings()
        try reloaded.load(
            dbFileName: "phase8-passkey.kdbx",
            dbFileData: data,
            compositeKey: CompositeKey(staticComponents: combined, challengeHandler: nil),
            useStreams: false,
            warnings: warnings)

        var allEntries = [Entry]()
        reloaded.root?.collectAllEntries(to: &allEntries)
        let found = allEntries.first { $0.rawTitle == "Passkey entry" }
        let passkey = found.flatMap { Passkey.make(from: $0) }
        XCTAssertNotNil(passkey)
        XCTAssertEqual(passkey?.relyingParty, "roundtrip.example")
        XCTAssertEqual(passkey?.username, "carol")
        XCTAssertEqual(passkey?.credentialID, Data(repeating: 7, count: 32))
    }
}

/// Generates a fresh, valid P-256 key per call (test-only, not a real credential).
private enum P256TestKey {
    static func makePEM() throws -> String {
        return P256.Signing.PrivateKey().pemRepresentation
    }
}
