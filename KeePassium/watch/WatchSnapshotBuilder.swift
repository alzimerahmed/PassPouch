//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import KeePassiumLib
import Foundation

/// Builds the sanitized snapshot sent to the watchOS companion app (ADR-013).
///
/// Privacy rules enforced here:
/// - only entries explicitly selected by the user (default: none) are included;
/// - only title / username / password / TOTP parameters are extracted — notes,
///   URLs, attachments and every other custom field are dropped;
/// - all strings are trimmed and length-capped;
/// - entries with neither a password nor a usable TOTP are skipped.
public enum WatchSnapshotBuilder {
    /// Hard cap on snapshot size: the watch shows a short quick-view list.
    public static let maxEntries = 32
    /// Hard cap per string field, so a hostile/huge entry cannot bloat the
    /// Bluetooth message or the watch keychain item.
    public static let maxFieldLength = 256

    // MARK: - Snapshot building

    public static func buildSnapshot(
        database: Database,
        databaseName: String,
        selectedEntryIDs: Set<UUID>
    ) -> WatchSnapshot? {
        guard !selectedEntryIDs.isEmpty else {
            return nil
        }
        var entries = [WatchEntrySnapshot]()
        collectEntries(from: database.root, selectedEntryIDs: selectedEntryIDs, into: &entries)
        guard !entries.isEmpty else {
            return nil
        }
        return WatchSnapshot(
            databaseName: sanitize(databaseName),
            generatedAt: Date(),
            entries: entries
        )
    }

    private static func collectEntries(
        from group: Group?,
        selectedEntryIDs: Set<UUID>,
        into entries: inout [WatchEntrySnapshot]
    ) {
        guard let group, entries.count < maxEntries else { return }
        for entry in group.entries where selectedEntryIDs.contains(entry.uuid) {
            guard entries.count < maxEntries,
                  let snapshot = makeSnapshot(for: entry)
            else { continue }
            entries.append(snapshot)
        }
        for subgroup in group.groups {
            collectEntries(from: subgroup, selectedEntryIDs: selectedEntryIDs, into: &entries)
        }
    }

    private static func makeSnapshot(for entry: Entry) -> WatchEntrySnapshot? {
        let password = sanitize(entry.resolvedPassword)
        let totp = totpParams(for: entry)
        guard !password.isEmpty || totp != nil else {
            return nil // nothing useful to show on the watch
        }
        return WatchEntrySnapshot(
            id: entry.uuid.uuidString,
            title: sanitize(entry.resolvedTitle),
            userName: sanitize(entry.resolvedUserName),
            password: password,
            totp: totp
        )
    }

    private static func sanitize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxFieldLength else {
            return trimmed
        }
        return String(trimmed.prefix(maxFieldLength))
    }

    // MARK: - TOTP parameter extraction

    /// Extracts TOTP parameters for the watch from any of the three upstream
    /// TOTP storage formats. Uses `TOTPGeneratorFactory` (KeePassiumLib) as the
    /// source of truth for "does this entry have a usable TOTP", so the watch
    /// never receives a seed the phone itself could not use.
    public static func totpParams(for entry: Entry) -> WatchTOTPParams? {
        guard TOTPGeneratorFactory.makeGenerator(for: entry) != nil else {
            return nil
        }
        if let otpField = entry.getField(EntryField.otp) {
            return parseOTPAuthURI(otpField.resolvedValue)
        }
        if let seedField = entry.getField(EntryField.otpConfig2Seed) {
            return parseSplitFormat(
                seed: seedField.resolvedValue,
                settings: entry.getField(EntryField.otpConfig2Settings)?.resolvedValue
            )
        }
        if let secretField = entry.getField(EntryField.timeOtpSecret) {
            return parseKeePassFormat(
                secret: secretField.resolvedValue,
                period: entry.getField(EntryField.timeOtpPeriod)?.resolvedValue,
                digits: entry.getField(EntryField.timeOtpLength)?.resolvedValue,
                algorithm: entry.getField(EntryField.timeOtpAlgorithm)?.resolvedValue
            )
        }
        return nil
    }

    /// `otpauth://totp/...?secret=...&period=...&digits=...&algorithm=...`
    /// Steam TOTP is not supported on the watch (custom alphabet) — returns nil.
    private static func parseOTPAuthURI(_ uriString: String) -> WatchTOTPParams? {
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme == "otpauth",
              components.host == "totp"
        else {
            return nil
        }
        let params = (components.queryItems ?? []).reduce(into: [String: String]()) {
            $0[$1.name] = $1.value
        }
        if params["encoder"] == "steam" || params["issuer"] == "Steam" {
            return nil
        }
        guard let seed = params["secret"] else {
            return nil
        }
        return makeParams(
            seed: seed,
            period: params["period"],
            digits: params["digits"],
            algorithm: params["algorithm"]
        )
    }

    /// Split field format: `TOTP Seed` + `TOTP Settings` (`period;digits`).
    /// Steam (`period;S`) is not supported on the watch — returns nil.
    private static func parseSplitFormat(seed: String, settings: String?) -> WatchTOTPParams? {
        let cleanedSeed = seed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "")
        let parts = (settings ?? "30;6").split(separator: ";")
        guard parts.count >= 2 else {
            return nil
        }
        if parts[1] == TOTPGeneratorSteam.typeSymbol {
            return nil
        }
        return makeParams(
            seed: cleanedSeed,
            period: String(parts[0]),
            digits: String(parts[1]),
            algorithm: nil
        )
    }

    /// KeePass format: `TimeOtp-Secret-Base32` + `TimeOtp-*` fields.
    private static func parseKeePassFormat(
        secret: String,
        period: String?,
        digits: String?,
        algorithm: String?
    ) -> WatchTOTPParams? {
        let mappedAlgorithm: String?
        switch algorithm {
        case "HMAC-SHA-1":
            mappedAlgorithm = "SHA1"
        case "HMAC-SHA-256":
            mappedAlgorithm = "SHA256"
        case "HMAC-SHA-512":
            mappedAlgorithm = "SHA512"
        case nil:
            mappedAlgorithm = nil
        default:
            return nil
        }
        return makeParams(
            seed: secret.trimmingCharacters(in: .whitespaces),
            period: period,
            digits: digits,
            algorithm: mappedAlgorithm
        )
    }

    private static func makeParams(
        seed: String,
        period: String?,
        digits: String?,
        algorithm: String?
    ) -> WatchTOTPParams? {
        let periodValue = period.flatMap { Int($0) } ?? WatchTOTPCore.defaultPeriod
        let digitsValue = digits.flatMap { Int($0) } ?? WatchTOTPCore.defaultDigits
        guard periodValue > 0, (4...8).contains(digitsValue) else {
            return nil
        }
        let algorithmValue = algorithm
            .flatMap { TOTPHashAlgorithm.fromString($0)?.asString }
            ?? TOTPHashAlgorithm.sha1.asString
        guard WatchTOTPCore.base32Decode(seed) != nil else {
            return nil
        }
        return WatchTOTPParams(
            base32Seed: seed,
            period: periodValue,
            digits: digitsValue,
            algorithm: algorithmValue
        )
    }
}
