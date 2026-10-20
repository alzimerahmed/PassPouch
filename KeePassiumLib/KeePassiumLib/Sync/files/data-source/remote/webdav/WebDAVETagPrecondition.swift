//  PassPouch — Password Manager
//  Copyright © 2025 Alzimer Ahmed <alzimerahmed84@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).

import Foundation

/// Pure decision logic for WebDAV conditional uploads (Phase 11b).
///
/// When a previous GET/HEAD observed an `ETag` for the file, the next `PUT`
/// carries that value in an `If-Match` header. If the file changed on the
/// server in the meantime, the server must answer `412 Precondition Failed`
/// and we surface it as a conflict instead of silently overwriting.
/// Servers that do not return ETags simply get an unconditional `PUT`,
/// exactly like before (upstream behavior); conflict detection then falls
/// back to the existing content-hash comparison in `DatabaseSaver`.
public enum WebDAVETagPrecondition {
    /// Returns the `If-Match` header value for an observed ETag, or `nil`
    /// when no conditional request should be made.
    /// Weak validators (`W/"..."`) are not usable in `If-Match`, so they are
    /// dropped and the upload stays unconditional.
    public static func ifMatchHeader(observedETag: String?) -> String? {
        guard let observedETag, !observedETag.isEmpty else { return nil }
        let trimmed = observedETag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("W/") { return nil }
        return trimmed
    }

    /// True if the HTTP status means the `If-Match` precondition failed,
    /// i.e. the remote file was modified by someone else.
    public static func isConflict(statusCode: Int) -> Bool {
        return statusCode == 412
    }
}

extension LString {
    public static let errorWebDAVFileModifiedRemotely = NSLocalizedString(
        "[WebDAV/Error/FileModifiedRemotely]",
        bundle: Bundle.framework,
        value: "The file was modified on the server while you were editing. "
            + "Please reload the database and try again.",
        comment: "Error message when a WebDAV upload was rejected because the "
            + "remote file changed since it was downloaded (HTTP 412).")
}
