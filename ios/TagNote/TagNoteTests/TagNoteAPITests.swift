import XCTest
@testable import TagNote

final class TagNoteAPITests: XCTestCase {
    private var api: TagNoteAPI!

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        api = TagNoteAPI(session: URLSession(configuration: configuration))
        api.configure(serverURL: URL(string: "https://notes.example.test"), token: "jwt-token")
    }

    override func tearDown() {
        api = nil
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testLoginPostsToAuthEndpointAndDecodesToken() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/auth/login")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

            let body = try XCTUnwrap(request.bodyData)
            let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]
            XCTAssertEqual(payload?["email"], "test@test.com")
            XCTAssertEqual(payload?["password"], "testpass123")

            return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
            {
              "token": "server-token",
              "user": {
                "id": "user-1",
                "email": "test@test.com",
                "display_name": "Test User",
                "created_at": "2026-05-28T08:00:00Z",
                "email_verified": true,
                "has_password": true,
                "has_google": false
              }
            }
            """)
        }

        let response = try await api.login(email: "test@test.com", password: "testpass123")

        XCTAssertEqual(response.token, "server-token")
        XCTAssertEqual(response.user?.email, "test@test.com")
    }

    func testCreateNoteUsesBearerTokenAndDecodesShortID() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/notes")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")

            let body = try XCTUnwrap(request.bodyData)
            let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(payload?["content"] as? String, "### Hello world")
            XCTAssertEqual(payload?["tags"] as? [String], ["hello"])

            return HTTPURLResponse.stub(url: request.url!, statusCode: 201, body: """
            {
              "id": "01J00000000000000000000000",
              "short_id": "01J0000000",
              "created_at": "2026-05-28T08:00:00Z"
            }
            """)
        }

        let response = try await api.createNote(content: "### Hello world", tags: ["hello"])

        XCTAssertEqual(response.shortID, "01J0000000")
    }

    func testRegisterPostsDisplayNameWithoutAuthorization() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/auth/register")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

            let payload = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.bodyData)) as? [String: String]
            XCTAssertEqual(payload?["email"], "new@test.com")
            XCTAssertEqual(payload?["password"], "testpass123")
            XCTAssertEqual(payload?["display_name"], "New User")

            return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
            {
              "token": "new-token",
              "user": {
                "id": "user-2",
                "email": "new@test.com",
                "display_name": "New User",
                "created_at": "2026-05-28T08:00:00Z"
              }
            }
            """)
        }

        let response = try await api.register(email: "new@test.com", password: "testpass123", displayName: "New User")

        XCTAssertEqual(response.token, "new-token")
        XCTAssertEqual(response.user?.displayName, "New User")
    }

    func testAuthUtilityEndpointsUseExpectedMethods() async throws {
        var seenPaths: [String] = []
        URLProtocolStub.handler = { request in
            seenPaths.append(request.url?.path ?? "")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
        }

        try await api.requestMagicLink(email: "test@test.com")
        try await api.forgotPassword(email: "test@test.com")

        XCTAssertEqual(seenPaths, ["/api/v1/auth/magic-link", "/api/v1/auth/forgot-password"])
    }

    func testMeAndLogoutUseAuthenticatedSession() async throws {
        var seen: [(String, String)] = []
        URLProtocolStub.handler = { request in
            seen.append((request.httpMethod ?? "", request.url?.path ?? ""))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")
            if request.url?.path == "/api/v1/auth/me" {
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
                {
                  "id": "user-1",
                  "email": "test@test.com",
                  "display_name": "Test User",
                  "created_at": "2026-05-28T08:00:00Z"
                }
                """)
            }
            return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
        }

        let user = try await api.me()
        await api.logout()

        XCTAssertEqual(user.email, "test@test.com")
        XCTAssertEqual(seen.map(\.0), ["GET", "POST"])
        XCTAssertEqual(seen.map(\.1), ["/api/v1/auth/me", "/api/v1/auth/logout"])
    }

    func testListNotesBuildsFilterQuery() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/notes")

            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let items = components?.queryItems ?? []
            XCTAssertEqual(items.filter { $0.name == "tag" }.map(\.value), ["hello", "ios"])
            XCTAssertTrue(items.contains(URLQueryItem(name: "q", value: "markdown")))
            XCTAssertTrue(items.contains(URLQueryItem(name: "sort", value: "updated")))
            XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "30")))
            XCTAssertTrue(items.contains(URLQueryItem(name: "offset", value: "60")))

            return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: "[]")
        }

        let notes = try await api.listNotes(tags: ["hello", "ios"], query: "markdown", sort: "updated", limit: 30, offset: 60)

        XCTAssertEqual(notes, [])
    }

    func testContentSearchAddsQueryParameter() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/notes")

            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let items = components?.queryItems ?? []
            XCTAssertTrue(items.contains(URLQueryItem(name: "q", value: "invoice renewal")))
            XCTAssertFalse(items.contains { $0.name == "tag" })

            return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
            [
              {
                "id": "01J00000000000000000000000",
                "short_id": "01J0000000",
                "content": "invoice renewal",
                "created_at": "2026-05-28T08:00:00Z",
                "tags": ["finance"],
                "pinned": false
              }
            ]
            """)
        }

        let notes = try await api.listNotes(tags: [], query: "invoice renewal", sort: "newest", limit: 30, offset: 0)

        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.content, "invoice renewal")
    }

    func testNoteDetailUpdatePinDeleteRestorePurgeAndTrashEndpoints() async throws {
        var seen: [(String, String)] = []
        URLProtocolStub.handler = { request in
            seen.append((request.httpMethod ?? "", request.url?.path ?? ""))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")

            switch request.url?.path {
            case "/api/v1/notes/01J0000000":
                if request.httpMethod == "GET" {
                    return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: Self.noteJSON(content: "Loaded note", tags: ["loaded"], pinned: false))
                }
                if request.httpMethod == "DELETE" {
                    return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
                }
                let payload = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.bodyData)) as? [String: Any]
                XCTAssertEqual(payload?["content"] as? String, "Updated note")
                XCTAssertEqual(payload?["tags"] as? [String], ["updated"])
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: Self.noteJSON(content: "Updated note", tags: ["updated"], pinned: false))
            case "/api/v1/notes/01J0000000/pin",
                 "/api/v1/notes/01J0000000/restore",
                 "/api/v1/notes/01J0000000/permanent":
                return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
            case "/api/v1/notes/trash":
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: "[\(Self.noteJSON(content: "Deleted note", tags: ["trash"], pinned: false))]")
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "") \(request.url?.path ?? "")")
                return HTTPURLResponse.stub(url: request.url!, statusCode: 500, body: "{}")
            }
        }

        let loaded = try await api.getNote(id: "01J0000000")
        let updated = try await api.updateNote(id: "01J0000000", content: "Updated note", tags: ["updated"])
        try await api.togglePin(id: "01J0000000")
        try await api.deleteNote(id: "01J0000000")
        let trash = try await api.listTrash()
        try await api.restoreNote(id: "01J0000000")
        try await api.purgeNote(id: "01J0000000")

        XCTAssertEqual(loaded.content, "Loaded note")
        XCTAssertEqual(updated.tags, ["updated"])
        XCTAssertEqual(trash.first?.content, "Deleted note")
        XCTAssertEqual(seen.map(\.1), [
            "/api/v1/notes/01J0000000",
            "/api/v1/notes/01J0000000",
            "/api/v1/notes/01J0000000/pin",
            "/api/v1/notes/01J0000000",
            "/api/v1/notes/trash",
            "/api/v1/notes/01J0000000/restore",
            "/api/v1/notes/01J0000000/permanent"
        ])
    }

    func testTagsSettingsAndAutocompleteEndpoints() async throws {
        var seenPaths: [String] = []
        URLProtocolStub.handler = { request in
            seenPaths.append(request.url?.path ?? "")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")

            switch request.url?.path {
            case "/api/v1/tags/detailed":
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
                [{"name":"ios","status":"approved","note_count":2,"importance":3,"urgency":4}]
                """)
            case "/api/v1/tags/autocomplete":
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                XCTAssertTrue(items.contains(URLQueryItem(name: "q", value: "io")))
                XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "5")))
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: #"["ios","iphone"]"#)
            case "/api/v1/tags/ios/approve",
                 "/api/v1/tags/approve-all",
                 "/api/v1/tags/ios/priority",
                 "/api/v1/tags/ios":
                return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
            case "/api/v1/tags/ios/rename":
                let payload = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.bodyData)) as? [String: String]
                XCTAssertEqual(payload?["new_name"], "mobile")
                return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
            case "/api/v1/settings":
                if request.httpMethod == "GET" {
                    return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
                    {"theme":"nord-dark","preview_mode":"markdown","note_width":"wide"}
                    """)
                }
                let payload = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.bodyData)) as? [String: String]
                XCTAssertEqual(payload?["theme"], "gruvbox-dark")
                return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
                {"theme":"gruvbox-dark","preview_mode":"plain","note_width":"compact"}
                """)
            default:
                XCTFail("Unexpected request: \(request.url?.path ?? "")")
                return HTTPURLResponse.stub(url: request.url!, statusCode: 500, body: "{}")
            }
        }

        let tags = try await api.listTagsDetailed()
        let suggestions = try await api.autocompleteTags(query: "io", limit: 5)
        try await api.approveTag("ios")
        try await api.approveAllTags()
        try await api.renameTag("ios", to: "mobile")
        try await api.updateTagPriority("ios", importance: 3, urgency: 4)
        try await api.deleteTag("ios")
        let settings = try await api.getSettings()
        let saved = try await api.saveSettings(TagNoteSettings(theme: "gruvbox-dark", previewMode: "plain", noteWidth: "compact"))

        XCTAssertEqual(tags.first?.name, "ios")
        XCTAssertEqual(suggestions, ["ios", "iphone"])
        XCTAssertEqual(settings.theme, "nord-dark")
        XCTAssertEqual(saved.theme, "gruvbox-dark")
        XCTAssertTrue(seenPaths.contains("/api/v1/tags/detailed"))
        XCTAssertTrue(seenPaths.contains("/api/v1/settings"))
    }

    func testImageUploadBuildsMultipartRequestAndReturnsPath() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/images")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
            let body = String(data: try XCTUnwrap(request.bodyData), encoding: .utf8)
            XCTAssertTrue(body?.contains(#"name="file"; filename="note-image.png""#) == true)
            XCTAssertTrue(body?.contains("Content-Type: image/png") == true)
            XCTAssertTrue(body?.contains("png-bytes") == true)
            return HTTPURLResponse.stub(url: request.url!, statusCode: 200, body: """
            {"data":{"file_path":"/uploads/note-image.png"}}
            """)
        }

        let path = try await api.uploadImage(data: Data("png-bytes".utf8), fileName: "note-image.png", mimeType: "image/png")

        XCTAssertEqual(path, "/uploads/note-image.png")
    }

    func testErrorsAndMissingConfigurationAreSurfaced() async throws {
        api.configure(serverURL: nil, token: "jwt-token")
        await XCTAssertThrowsErrorAsync({
            _ = try await api.listNotes(tags: [], query: "", sort: "newest", limit: 30, offset: 0)
        }) { error in
            guard case TagNoteAPIError.invalidServerURL = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        api.configure(serverURL: URL(string: "https://notes.example.test"), token: nil)
        await XCTAssertThrowsErrorAsync({
            _ = try await api.listNotes(tags: [], query: "", sort: "newest", limit: 30, offset: 0)
        }) { error in
            guard case TagNoteAPIError.missingToken = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        api.configure(serverURL: URL(string: "https://notes.example.test"), token: "jwt-token")
        URLProtocolStub.handler = { request in
            HTTPURLResponse.stub(url: request.url!, statusCode: 400, body: #"{"error":"bad request"}"#)
        }

        await XCTAssertThrowsErrorAsync({
            _ = try await api.listTagsDetailed()
        }) { error in
            guard case TagNoteAPIError.http(400, "bad request") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTagNameIsPathEscaped() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/api/v1/tags/hello%2Fios/rename")
            return HTTPURLResponse.stub(url: request.url!, statusCode: 204, body: "")
        }

        try await api.renameTag("hello/ios", to: "hello-ios")
    }

    private static func noteJSON(content: String, tags: [String], pinned: Bool) -> String {
        let tagJSON = tags.map { #""\#($0)""# }.joined(separator: ",")
        return """
        {
          "id": "01J00000000000000000000000",
          "short_id": "01J0000000",
          "content": "\(content)",
          "created_at": "2026-05-28T08:00:00Z",
          "updated_at": "2026-05-28T09:00:00Z",
          "tags": [\(tagJSON)],
          "pinned": \(pinned)
        }
        """
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

private final class URLProtocolStub: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    static var handler: Handler?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension HTTPURLResponse {
    static func stub(url: URL, statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(body.utf8))
    }
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            return nil
        }
        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: bufferSize)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
