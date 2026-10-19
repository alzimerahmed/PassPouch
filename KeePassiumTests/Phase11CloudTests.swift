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

/// Phase 11b (direct cloud backends) tests: WebDAV PROPFIND XML parsing,
/// URL/path normalization, ETag/If-Match conflict logic, HTTP-date parsing,
/// credential keychain round-trip, and the SFTP connector seam.
/// No network calls — all server payloads are inline mocks.
final class Phase11CloudTests: XCTestCase {

    // MARK: - WebDAV ETag precondition logic

    func testIfMatchHeaderUsesObservedETag() {
        XCTAssertEqual(
            WebDAVETagPrecondition.ifMatchHeader(observedETag: "\"abc123\""),
            "\"abc123\"")
    }

    func testIfMatchHeaderNilWhenNoETagObserved() {
        XCTAssertNil(WebDAVETagPrecondition.ifMatchHeader(observedETag: nil))
        XCTAssertNil(WebDAVETagPrecondition.ifMatchHeader(observedETag: ""))
        XCTAssertNil(WebDAVETagPrecondition.ifMatchHeader(observedETag: "   "))
    }

    func testIfMatchHeaderDropsWeakValidator() {
        // Weak validators (W/"...") are not valid in If-Match; upload must
        // stay unconditional rather than send a server-rejected header.
        XCTAssertNil(WebDAVETagPrecondition.ifMatchHeader(observedETag: "W/\"abc\""))
    }

    func testConflictDetectionIs412Only() {
        XCTAssertTrue(WebDAVETagPrecondition.isConflict(statusCode: 412))
        XCTAssertFalse(WebDAVETagPrecondition.isConflict(statusCode: 200))
        XCTAssertFalse(WebDAVETagPrecondition.isConflict(statusCode: 404))
        XCTAssertFalse(WebDAVETagPrecondition.isConflict(statusCode: 500))
    }

    // MARK: - PROPFIND XML parsing (inline mock payloads)

    private let propfindXMLPrefixed = """
    <?xml version="1.0" encoding="utf-8"?>
    <d:multistatus xmlns:d="DAV:">
      <d:response>
        <d:href>/dav/</d:href>
        <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
        <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
      </d:response>
      <d:response>
        <d:href>/dav/vault.kdbx</d:href>
        <d:propstat><d:prop><d:resourcetype/></d:prop>
        <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
      </d:response>
      <d:response>
        <d:href>/dav/backups/</d:href>
        <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
        <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
      </d:response>
    </d:multistatus>
    """

    func testPropfindParsingWithStandardPrefix() throws {
        let baseURL = URL(string: "https://example.com/dav/")!
        let parser = PropFindResponseParser(baseURL: baseURL)
        let items = try parser.parse(data: Data(propfindXMLPrefixed.utf8))

        // First item is the folder itself, then children.
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].url.absoluteString, "https://example.com/dav/")
        XCTAssertTrue(items[0].isFolder)
        XCTAssertEqual(items[1].name, "vault.kdbx")
        XCTAssertFalse(items[1].isFolder)
        XCTAssertEqual(items[2].name, "backups")
        XCTAssertTrue(items[2].isFolder)
    }

    func testPropfindParsingWithoutNamespacePrefix() throws {
        let xml = """
        <?xml version="1.0"?>
        <multistatus xmlns="DAV:">
          <response>
            <href>/dav/</href>
            <propstat><prop><resourcetype><collection/></resourcetype></prop></propstat>
          </response>
          <response>
            <href>/dav/db.kdbx</href>
            <propstat><prop><resourcetype/></prop></propstat>
          </response>
        </multistatus>
        """
        let baseURL = URL(string: "https://example.com/dav/")!
        let parser = PropFindResponseParser(baseURL: baseURL)
        let items = try parser.parse(data: Data(xml.utf8))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[1].name, "db.kdbx")
        XCTAssertFalse(items[1].isFolder)
    }

    func testPropfindParsingWithCustomPrefix() throws {
        let xml = """
        <?xml version="1.0"?>
        <D:multistatus xmlns:D="DAV:">
          <D:response>
            <D:href>/dav/</D:href>
            <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>
          </D:response>
          <D:response>
            <D:href>/dav/sub/</D:href>
            <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>
          </D:response>
        </D:multistatus>
        """
        let baseURL = URL(string: "https://example.com/dav/")!
        let parser = PropFindResponseParser(baseURL: baseURL)
        let items = try parser.parse(data: Data(xml.utf8))
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[1].isFolder)
    }

    func testPropfindParsingGarbageThrows() {
        let baseURL = URL(string: "https://example.com/dav/")!
        let parser = PropFindResponseParser(baseURL: baseURL)
        // Malformed XML (unclosed elements) must throw, not silently yield items.
        XCTAssertThrowsError(
            try parser.parse(data: Data("<d:multistatus><d:response>".utf8)))
    }

    // MARK: - WebDAV URL scheme prefixing / normalization

    func testWebDAVFileURLRoundTrip() {
        let naked = URL(string: "https://example.com:8443/dav/vault.kdbx")!
        let prefixed = WebDAVFileURL.build(nakedURL: naked)
        XCTAssertTrue(prefixed.absoluteString.hasPrefix("webdav"))
        let back = WebDAVFileURL.getNakedURL(from: prefixed)
        XCTAssertEqual(back, naked)
    }

    func testWebDAVProviderBuildFullURLNextcloudPrefix() {
        let provider = WebDAVProvider.nextcloud
        let base = URL(string: "https://cloud.example.com")!
        let full = provider.buildFullURL(from: base, username: "alice")
        XCTAssertEqual(
            full.absoluteString,
            "https://cloud.example.com/remote.php/dav/files/alice/")
    }

    func testWebDAVProviderBuildFullURLJoinsBasePath() {
        let provider = WebDAVProvider.koofr
        let base = URL(string: "https://app.koofr.net/")!
        let full = provider.buildFullURL(from: base, username: "bob")
        XCTAssertEqual(full.absoluteString, "https://app.koofr.net/dav/Koofr")
    }

    func testWebDAVProviderBuildFullURLUsernamePlaceholder() {
        let provider = WebDAVProvider.hetzner
        let base = URL(string: "https://%25username%25.your-storagebox.de")!
        let full = provider.buildFullURL(from: base, username: "carol")
        XCTAssertEqual(full.absoluteString, "https://carol.your-storagebox.de")
    }

    // MARK: - HTTP date parsing (Last-Modified fallback)

    func testHTTPDateParsingIMFFormat() throws {
        let date = try XCTUnwrap(Date.parse(httpHeaderValue: "Mon, 19 Oct 2026 10:00:00 GMT"))
        var comps = DateComponents()
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = 2026
        comps.month = 10
        comps.day = 19
        comps.hour = 10
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expected = try XCTUnwrap(calendar.date(from: comps))
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
    }

    func testHTTPDateParsingNilAndGarbage() {
        XCTAssertNil(Date.parse(httpHeaderValue: nil))
        XCTAssertNil(Date.parse(httpHeaderValue: "not a date"))
    }

    // MARK: - Credential keychain round-trip

    func testNetworkCredentialKeychainRoundTrip() throws {
        let url = URL(
            string: "webdav://keychain-test/phase11b-\(UUID().uuidString).kdbx")!
        defer { CredentialManager.shared.remove(for: url) }

        let credential = NetworkCredential(
            username: "alice",
            password: "s3cr3t-pass",
            allowUntrustedCertificate: false)
        CredentialManager.shared.store(credential: credential, for: url)

        let restored = CredentialManager.shared.get(for: url)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.username, "alice")
        XCTAssertEqual(restored?.password, "s3cr3t-pass")
        XCTAssertEqual(restored?.allowUntrustedCertificate, false)

        CredentialManager.shared.remove(for: url)
        XCTAssertNil(CredentialManager.shared.get(for: url))
    }

    func testNetworkCredentialSerializationRoundTrip() throws {
        let credential = NetworkCredential(
            username: "bob",
            password: "p@ss w0rd",
            allowUntrustedCertificate: true)
        let data = credential.serialize()
        let restored = try XCTUnwrap(NetworkCredential.deserialize(from: data))
        XCTAssertEqual(restored.username, "bob")
        XCTAssertEqual(restored.password, "p@ss w0rd")
        XCTAssertEqual(restored.allowUntrustedCertificate, true)
    }

    // MARK: - SFTP connector seam (ADR-014)

    func testSFTPSettingsValidation() {
        let valid = SFTPConnectionSettings(
            host: "nas.example.com",
            username: "alice",
            auth: .password("secret"))
        XCTAssertTrue(valid.isValid)

        let emptyHost = SFTPConnectionSettings(
            host: " ", username: "alice", auth: .password("secret"))
        XCTAssertFalse(emptyHost.isValid)

        let badPort = SFTPConnectionSettings(
            host: "nas.example.com", port: 70_000,
            username: "alice", auth: .password("secret"))
        XCTAssertFalse(badPort.isValid)

        let emptyPassword = SFTPConnectionSettings(
            host: "nas.example.com", username: "alice", auth: .password(""))
        XCTAssertFalse(emptyPassword.isValid)

        let keyAuth = SFTPConnectionSettings(
            host: "nas.example.com",
            username: "alice",
            auth: .privateKey(
                pem: "-----BEGIN OPENSSH PRIVATE KEY-----", passphrase: nil))
        XCTAssertTrue(keyAuth.isValid)
    }

    func testUnavailableSFTPConnectorFailsExplicitly() async throws {
        let connector = UnavailableSFTPConnector()
        let settings = SFTPConnectionSettings(
            host: "nas.example.com",
            username: "alice",
            auth: .password("secret"))
        do {
            _ = try await connector.connect(settings: settings)
            XCTFail("Transport must not pretend to connect")
        } catch let error as SFTPError {
            XCTAssertEqual(error.localizedDescription, LString.errorSFTPTransportUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUnavailableSFTPConnectorRejectsInvalidSettings() async {
        let connector = UnavailableSFTPConnector()
        let settings = SFTPConnectionSettings(
            host: "", username: "", auth: .password(""))
        do {
            _ = try await connector.connect(settings: settings)
            XCTFail("Must reject invalid settings")
        } catch let error as SFTPError {
            XCTAssertEqual(error.localizedDescription, LString.errorSFTPInvalidConfiguration)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
