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

/// Phase 11c (entry sharing / ephemeral links + emergency access) tests:
/// share payload encrypt/decrypt round-trip, wrong-key failure, expiry
/// enforcement, field-selection serialization, URL assembly/parsing, and
/// Shamir secret sharing split/combine behavior. No network, no UI.
final class Phase11SharingTests: XCTestCase {

    // MARK: - Deterministic RNG for Shamir tests

    /// Simple deterministic RNG so Shamir tests are reproducible.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            // xorshift64*
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 0x2545F4914F6CDD1D
        }
    }

    // MARK: - Share payload: round-trip

    private func makeEntry() -> Entry {
        let entry = Entry(database: nil)
        entry.setField(name: EntryField.title, value: "Example Site")
        entry.setField(name: EntryField.userName, value: "alice@example.com")
        entry.setField(name: EntryField.password, value: "s3cr3t-π-password")
        entry.setField(name: EntryField.url, value: "https://example.com")
        entry.setField(name: EntryField.notes, value: "line one\nline two")
        return entry
    }

    func testRoundTripAllFields() throws {
        let entry = makeEntry()
        let allFields = Set(EntryShareField.allCases.subtracting([.totp]))
        let payload = try EntrySharePayload.make(from: entry, fields: allFields, expiresAt: nil)
        let (payloadData, key) = try EntrySharePayload.encrypt(payload)
        let decrypted = try EntrySharePayload.decrypt(payloadData, key: key)

        XCTAssertEqual(decrypted.fields[EntryField.title], "Example Site")
        XCTAssertEqual(decrypted.fields[EntryField.userName], "alice@example.com")
        XCTAssertEqual(decrypted.fields[EntryField.password], "s3cr3t-π-password")
        XCTAssertEqual(decrypted.fields[EntryField.url], "https://example.com")
        XCTAssertEqual(decrypted.fields[EntryField.notes], "line one\nline two")
        XCTAssertNil(decrypted.expiresAt)
    }

    func testRoundTripSelectedFieldsOnly() throws {
        let entry = makeEntry()
        let payload = try EntrySharePayload.make(
            from: entry,
            fields: [.title, .password],
            expiresAt: nil)
        let (payloadData, key) = try EntrySharePayload.encrypt(payload)
        let decrypted = try EntrySharePayload.decrypt(payloadData, key: key)

        XCTAssertEqual(decrypted.fields[EntryField.title], "Example Site")
        XCTAssertEqual(decrypted.fields[EntryField.password], "s3cr3t-π-password")
        XCTAssertNil(decrypted.fields[EntryField.userName], "unselected field must not be in payload")
        XCTAssertNil(decrypted.fields[EntryField.notes], "unselected field must not be in payload")
        XCTAssertNil(decrypted.fields[EntryField.url], "unselected field must not be in payload")
    }

    func testEmptySelectionThrows() {
        let entry = makeEntry()
        XCTAssertThrowsError(
            try EntrySharePayload.make(from: entry, fields: [], expiresAt: nil)
        ) { error in
            XCTAssertEqual(error as? ShareLinkError, .nothingSelected)
        }
    }

    func testEmptyValuesAreExcluded() throws {
        let entry = Entry(database: nil)
        entry.setField(name: EntryField.title, value: "Only title")
        let payload = try EntrySharePayload.make(
            from: entry, fields: [.title, .password], expiresAt: nil)
        XCTAssertEqual(payload.fields.keys.sorted(), [EntryField.title])
    }

    // MARK: - Share payload: wrong key / tampering

    func testWrongKeyFails() throws {
        let entry = makeEntry()
        let payload = try EntrySharePayload.make(
            from: entry, fields: [.password], expiresAt: nil)
        let (payloadData, _) = try EntrySharePayload.encrypt(payload)

        var wrongKey = Data(repeating: 0x42, count: 32)
        XCTAssertThrowsError(try EntrySharePayload.decrypt(payloadData, key: wrongKey))
        // Corrupted payload with the right key must also fail (AEAD).
        let (_, key) = try EntrySharePayload.encrypt(payload)
        wrongKey = key
        var tampered = payloadData
        tampered[tampered.count - 1] ^= 0xFF
        XCTAssertThrowsError(try EntrySharePayload.decrypt(tampered, key: wrongKey))
    }

    func testExpiryEnforced() throws {
        let entry = makeEntry()
        let past = Date().addingTimeInterval(-60)
        let future = Date().addingTimeInterval(3600)

        let expiredPayload = try EntrySharePayload.make(
            from: entry, fields: [.password], expiresAt: past)
        let (expiredData, expiredKey) = try EntrySharePayload.encrypt(expiredPayload)
        XCTAssertThrowsError(try EntrySharePayload.decrypt(expiredData, key: expiredKey)) {
            error in
            XCTAssertEqual(error as? ShareLinkError, .expired)
        }

        let validPayload = try EntrySharePayload.make(
            from: entry, fields: [.password], expiresAt: future)
        let (validData, validKey) = try EntrySharePayload.encrypt(validPayload)
        XCTAssertNoThrow(try EntrySharePayload.decrypt(validData, key: validKey))
    }

    // MARK: - Link assembly / parsing

    func testLinkRoundTrip() throws {
        let entry = makeEntry()
        let payload = try EntrySharePayload.make(
            from: entry, fields: [.title, .password], expiresAt: nil)
        let (payloadData, key) = try EntrySharePayload.encrypt(payload)
        let link = try EntrySharePayload.makeLink(payloadData: payloadData, key: key)

        XCTAssertEqual(link.scheme, "passpouch")
        XCTAssertEqual(link.host, "share")
        XCTAssertNotNil(link.fragment, "key must live in the URL fragment")
        XCTAssertFalse(link.absoluteString.contains("+"), "must be base64url, not base64")

        let (parsedPayload, parsedKey) = try EntrySharePayload.parseLink(link)
        XCTAssertEqual(parsedKey, key)
        let decrypted = try EntrySharePayload.decrypt(parsedPayload, key: parsedKey)
        XCTAssertEqual(decrypted, payload)
    }

    func testParseRejectsForeignLinks() {
        let foreign = URL(string: "https://example.com/share/abc")!
        XCTAssertThrowsError(try EntrySharePayload.parseLink(foreign))
        let bare = URL(string: "passpouch://share")!
        XCTAssertThrowsError(try EntrySharePayload.parseLink(bare))
    }

    func testParseRejectsWrongKeyLength() throws {
        let entry = makeEntry()
        let payload = try EntrySharePayload.make(
            from: entry, fields: [.title], expiresAt: nil)
        let (payloadData, key) = try EntrySharePayload.encrypt(payload)
        let link = try EntrySharePayload.makeLink(payloadData: payloadData, key: key)
        // Truncate the fragment (simulates a link damaged by a URL shortener)
        let truncated = URL(string: link.absoluteString.dropLast(4).description)!
        XCTAssertThrowsError(try EntrySharePayload.parseLink(truncated))
    }

    // MARK: - Shamir: GF(256) sanity

    func testGF256MultiplicationKnownVector() {
        // Classic AES-field example: {53}·{CA} = {01}
        XCTAssertEqual(Shamir.gf256Multiply(0x53, 0xCA), 0x01)
        XCTAssertEqual(Shamir.gf256Multiply(0x02, 0x80), 0x1B) // x^8 reduction
        XCTAssertEqual(Shamir.gf256Multiply(0x00, 0xFF), 0x00)
        XCTAssertEqual(Shamir.gf256Multiply(0x01, 0x57), 0x57)
    }

    // MARK: - Shamir: split/combine

    private let secretString = "correct horse battery staple ünïcode"

    func testSplitCombineRoundTripAllSubsets() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 0xC0FFEE)
        let shares = try Shamir.split(
            secret: secret, threshold: 3, sharesCount: 5, using: &rng)

        XCTAssertEqual(shares.count, 5)
        XCTAssertEqual(Set(shares.map { $0.x }).count, 5, "x values must be distinct")
        XCTAssertEqual(Set(shares.map { $0.setID }).count, 1, "one split = one set ID")

        // Every 3-subset must reconstruct the secret.
        for first in 0..<5 {
            for second in (first + 1)..<5 {
                for third in (second + 1)..<5 {
                    let subset = [shares[first], shares[second], shares[third]]
                    let reconstructed = try Shamir.combine(shares: subset)
                    XCTAssertEqual(reconstructed, secret)
                }
            }
        }
    }

    func testFewerThanThresholdFails() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 7)
        let shares = try Shamir.split(
            secret: secret, threshold: 3, sharesCount: 5, using: &rng)
        XCTAssertThrowsError(try Shamir.combine(shares: Array(shares.prefix(2)))) { error in
            XCTAssertEqual(error as? Shamir.ShamirError, .notEnoughShares)
        }
    }

    func testMixedSetsRejected() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 11)
        let sharesA = try Shamir.split(secret: secret, threshold: 2, sharesCount: 3, using: &rng)
        let sharesB = try Shamir.split(secret: secret, threshold: 2, sharesCount: 3, using: &rng)
        XCTAssertNotEqual(sharesA[0].setID, sharesB[0].setID)
        XCTAssertThrowsError(
            try Shamir.combine(shares: [sharesA[0], sharesA[1], sharesB[0]])
        ) { error in
            XCTAssertEqual(error as? Shamir.ShamirError, .setIDMismatch)
        }
    }

    func testTamperedShareDetected() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 13)
        var shares = try Shamir.split(secret: secret, threshold: 2, sharesCount: 3, using: &rng)

        // Flip one byte of a share's y value.
        var tamperedY = shares[0].y
        tamperedY[0] ^= 0x01
        shares[0] = Shamir.Share(
            threshold: shares[0].threshold,
            setID: shares[0].setID,
            x: shares[0].x,
            y: tamperedY)

        XCTAssertThrowsError(try Shamir.combine(shares: Array(shares.prefix(2)))) { error in
            XCTAssertEqual(error as? Shamir.ShamirError, .checksumMismatch)
        }
    }

    func testDuplicateShareIndexRejected() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 17)
        let shares = try Shamir.split(secret: secret, threshold: 2, sharesCount: 3, using: &rng)
        let duplicated = [shares[0], shares[0]]
        XCTAssertThrowsError(try Shamir.combine(shares: duplicated)) { error in
            XCTAssertEqual(error as? Shamir.ShamirError, .duplicateShareIndex)
        }
    }

    func testInvalidSplitParameters() {
        let secret = Data(secretString.utf8)
        XCTAssertThrowsError(try Shamir.split(secret: secret, threshold: 1, sharesCount: 3))
        XCTAssertThrowsError(try Shamir.split(secret: secret, threshold: 4, sharesCount: 3))
        XCTAssertThrowsError(try Shamir.split(secret: Data(), threshold: 2, sharesCount: 3))
    }

    // MARK: - Shamir: printable encoding

    func testShareEncodeDecodeRoundTrip() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 19)
        let shares = try Shamir.split(secret: secret, threshold: 3, sharesCount: 5, using: &rng)

        for share in shares {
            let text = Shamir.encodeShare(share)
            XCTAssertTrue(text.hasPrefix("PPSH1-"), "share must be printable with prefix")
            let decoded = try Shamir.decodeShare(text)
            XCTAssertEqual(decoded, share)
        }

        // Whitespace tolerance (copy-paste friendliness).
        let padded = "  \(Shamir.encodeShare(shares[0]))\n"
        XCTAssertEqual(try Shamir.decodeShare(padded), shares[0])

        XCTAssertThrowsError(try Shamir.decodeShare("GARBAGE")) { error in
            XCTAssertEqual(error as? Shamir.ShamirError, .invalidShareFormat)
        }
    }

    func testPrintableSharesSurviveCombine() throws {
        let secret = Data(secretString.utf8)
        var rng = SeededRNG(seed: 23)
        let shares = try Shamir.split(secret: secret, threshold: 2, sharesCount: 4, using: &rng)
        let texts = shares.map { Shamir.encodeShare($0) }
        let decoded = try texts.map { try Shamir.decodeShare($0) }
        XCTAssertEqual(try Shamir.combine(shares: [decoded[0], decoded[2]]), secret)
    }

    // MARK: - CRC-32 sanity

    func testCRC32KnownVector() {
        // zlib reference: CRC-32("123456789") = 0xCBF43926
        XCTAssertEqual(Shamir.crc32(Data("123456789".utf8)), Data([0xCB, 0xF4, 0x39, 0x26]))
    }
}
