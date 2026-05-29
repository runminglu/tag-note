import XCTest

final class TagNoteE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment["TAGNOTE_E2E_SERVER_URL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_SERVER_URL"] ?? "http://localhost:3777"
        app.launchEnvironment["TAGNOTE_E2E_EMAIL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_EMAIL"] ?? "test@test.com"
        app.launchEnvironment["TAGNOTE_E2E_PASSWORD"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_PASSWORD"] ?? "testpass123"
        app.launchArguments.append("-ui-testing")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testLoginShowsSeededNoteAndSearchesContent() async throws {
        let seeded = try await seedNote()
        app.launch()

        configureServerIfNeeded()
        loginIfNeeded()

        let returnedNotesScreen = app.descendants(matching: .any)["notes-screen"]
        XCTAssertTrue(returnedNotesScreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", seeded.title)).firstMatch.waitForExistence(timeout: 10))

        app.descendants(matching: .any)["sidebar-open-button"].tap()

        let searchField = app.textFields["note-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(seeded.bodyNeedle)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", seeded.title)).firstMatch.waitForExistence(timeout: 10))
    }

    private func configureServerIfNeeded() {
        let serverField = app.textFields["server-url-field"]
        guard serverField.waitForExistence(timeout: 2) else { return }

        serverField.tap()
        serverField.typeText(app.launchEnvironment["TAGNOTE_E2E_SERVER_URL"] ?? "http://localhost:3777")
        app.descendants(matching: .any)["server-continue-button"].tap()
    }

    private func loginIfNeeded() {
        let emailField = app.textFields["login-email-field"]
        guard emailField.waitForExistence(timeout: 8) else { return }

        emailField.tap()
        emailField.typeText(app.launchEnvironment["TAGNOTE_E2E_EMAIL"] ?? "test@test.com")

        let passwordField = app.secureTextFields["login-password-field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(app.launchEnvironment["TAGNOTE_E2E_PASSWORD"] ?? "testpass123")

        app.descendants(matching: .any)["login-submit-button"].tap()
    }

    private func seedNote() async throws -> SeededNote {
        let baseURL = URL(string: ProcessInfo.processInfo.environment["TAGNOTE_E2E_SERVER_URL"] ?? "http://localhost:3777")!
        let email = ProcessInfo.processInfo.environment["TAGNOTE_E2E_EMAIL"] ?? "test@test.com"
        let password = ProcessInfo.processInfo.environment["TAGNOTE_E2E_PASSWORD"] ?? "testpass123"
        let title = "iOS seeded note \(Int(Date().timeIntervalSince1970))"
        let bodyNeedle = "drawer-search-\(UUID().uuidString.prefix(8))"

        let loginURL = baseURL.appending(path: "api/v1/auth/login")
        var loginRequest = URLRequest(url: loginURL)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (loginData, loginResponse) = try await URLSession.shared.data(for: loginRequest)
        try assertSuccess(loginResponse)
        let token = try JSONDecoder().decode(LoginPayload.self, from: loginData).token

        let noteURL = baseURL.appending(path: "api/v1/notes")
        var noteRequest = URLRequest(url: noteURL)
        noteRequest.httpMethod = "POST"
        noteRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        noteRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        noteRequest.httpBody = try JSONEncoder().encode(NotePayload(
            content: "### \(title)\nCreated for native iOS E2E \(bodyNeedle)",
            tags: ["ios-e2e"]
        ))
        let (_, noteResponse) = try await URLSession.shared.data(for: noteRequest)
        try assertSuccess(noteResponse)

        return SeededNote(title: title, bodyNeedle: bodyNeedle)
    }

    private func assertSuccess(_ response: URLResponse) throws {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        XCTAssertTrue((200..<300).contains(statusCode), "Unexpected HTTP status \(statusCode)")
    }
}

private struct LoginPayload: Decodable {
    let token: String
}

private struct SeededNote {
    let title: String
    let bodyNeedle: String
}

private struct NotePayload: Encodable {
    let content: String
    let tags: [String]
}
