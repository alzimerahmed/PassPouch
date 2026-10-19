//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

/// Connection settings for a direct SFTP backend (Phase 11b, ADR-014).
///
/// The SSH transport itself is deliberately NOT implemented yet — no
/// GPLv3-compatible Swift SSH library exists that we can safely add, and
/// vendoring random GitHub SSH code is forbidden by AGENTS.md. This file
/// defines the seam (settings + connector protocol) so that when a transport
/// lands (recommended: Apple's Apache-2.0 `swift-nio-ssh` + a hand-written
/// SFTP subsystem client, per ADR-014), only the transport implementation
/// changes; the settings model and call sites stay stable.
public struct SFTPConnectionSettings: Equatable {
    public var host: String
    public var port: Int
    public var path: String
    public var username: String
    public var auth: SFTPAuthMethod

    public init(
        host: String,
        port: Int = 22,
        path: String = "/",
        username: String,
        auth: SFTPAuthMethod
    ) {
        self.host = host
        self.port = port
        self.path = path
        self.username = username
        self.auth = auth
    }

    public var isValid: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty, port > 0, port <= 65_535 else {
            return false
        }
        return auth.isComplete
    }
}

public enum SFTPAuthMethod: Equatable {
    case password(String)
    case privateKey(pem: String, passphrase: String?)

    public var isComplete: Bool {
        switch self {
        case .password(let password):
            return !password.isEmpty
        case .privateKey(let pem, _):
            return pem.contains("PRIVATE KEY")
        }
    }
}

public enum SFTPError: LocalizedError {
    /// The SSH/SFTP transport is not implemented in this build (ADR-014).
    case transportUnavailable
    case invalidConfiguration
    case connectionFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .transportUnavailable:
            return LString.errorSFTPTransportUnavailable
        case .invalidConfiguration:
            return LString.errorSFTPInvalidConfiguration
        case .connectionFailed(let message):
            return message
        }
    }
}

/// A single established SFTP connection.
public protocol SFTPSession {
    func listDirectory(at path: String) async throws -> [SFTPFileEntry]
    func downloadFile(at path: String) async throws -> Data
    func uploadFile(_ data: Data, to path: String) async throws
    func close() async
}

public struct SFTPFileEntry: Equatable {
    public let name: String
    public let isFolder: Bool
    public let size: Int64?

    public init(name: String, isFolder: Bool, size: Int64?) {
        self.name = name
        self.isFolder = isFolder
        self.size = size
    }
}

/// Transport-level seam: produces authenticated SFTP sessions.
public protocol SFTPConnector {
    func connect(settings: SFTPConnectionSettings) async throws -> SFTPSession
}

/// The only connector shipped in Phase 11b: fails fast with an explicit,
/// honest "not available yet" error — never a fake capability.
public struct UnavailableSFTPConnector: SFTPConnector {
    public init() {}

    public func connect(settings: SFTPConnectionSettings) async throws -> SFTPSession {
        guard settings.isValid else {
            throw SFTPError.invalidConfiguration
        }
        throw SFTPError.transportUnavailable
    }
}

extension LString {
    public static let errorSFTPTransportUnavailable = NSLocalizedString(
        "[SFTP/Error/TransportUnavailable]",
        value: "Direct SFTP connections are not available in PassPouch yet. "
            + "Please use an SFTP provider from the Files app (for example "
            + "Secure ShellFish) for now.",
        comment: "Error message shown when the user tries a direct SFTP "
            + "connection, which is planned but not yet implemented.")

    public static let errorSFTPInvalidConfiguration = NSLocalizedString(
        "[SFTP/Error/InvalidConfiguration]",
        value: "The SFTP connection settings are incomplete.",
        comment: "Error message when SFTP connection settings are missing "
            + "required fields (host, username, or credentials).")
}
