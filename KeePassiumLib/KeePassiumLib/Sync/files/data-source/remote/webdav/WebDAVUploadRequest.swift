//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

final class WebDAVUploadRequest: WebDAVRequestBase {
    typealias Completion = (Result<Void, FileAccessError>) -> Void

    let completionQueue: OperationQueue
    let completion: Completion
    let dataToUpload: ByteArray
    /// ETag observed at the last download/info request; sent as `If-Match`
    /// so the server rejects the upload with 412 if the file changed since.
    let ifMatch: String?

    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        data: ByteArray,
        ifMatch: String? = nil,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping Completion
    ) {
        self.completionQueue = completionQueue
        self.completion = completion
        self.dataToUpload = data
        self.ifMatch = ifMatch
        super.init(
            url: url,
            credential: credential,
            allowUntrustedCertificate: allowUntrustedCertificate,
            timeout: timeout
        )
    }

    override func makeURLRequest() -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .forContent,
            timeout: timeout
        )
        request.httpMethod = "PUT"
        request.httpBody = dataToUpload.asData
        if let ifMatch = WebDAVETagPrecondition.ifMatchHeader(observedETag: ifMatch) {
            request.addValue(ifMatch, forHTTPHeaderField: "If-Match")
        }
        return request
    }

    override func handleResponse(_ httpResponse: HTTPURLResponse) {
        if WebDAVETagPrecondition.isConflict(statusCode: httpResponse.statusCode) {
            Diag.error("WebDAV upload rejected: file modified on the server (412)")
            finishWith(error: .serverSideError(
                message: LString.errorWebDAVFileModifiedRemotely))
            return
        }
        super.handleResponse(httpResponse)
    }

    override func finishWith(error: FileAccessError) {
        completionQueue.addOperation {
            self.completion(.failure(error))
        }
    }

    override func finishWith(success response: HTTPURLResponse, data: Data) {
        assert((200...299).contains(response.statusCode))
        completionQueue.addOperation {
            self.completion(.success)
        }
    }
}
