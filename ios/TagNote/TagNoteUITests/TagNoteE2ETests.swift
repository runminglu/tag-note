import XCTest

final class TagNoteE2ETests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment["TAGNOTE_E2E_SERVER_URL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_SERVER_URL"] ?? "http://localhost:3777"
        app.launchEnvironment["TAGNOTE_E2E_EMAIL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_EMAIL"] ?? "test@test.com"
        app.launchEnvironment["TAGNOTE_E2E_PASSWORD"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_PASSWORD"] ?? "testpass123"
        app.launchEnvironment["TAGNOTE_UI_CREATE_NOTE"] = "1"
        app.launchArguments.append("-ui-testing")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLoginCreateTaggedNoteAndReturnToFeed() throws {
        app.launch()

        configureServerIfNeeded()
        loginIfNeeded()

        let tagField = app.textFields["tag-input-field"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 15))
        tagField.tap()
        tagField.typeText("ios-e2e")
        app.descendants(matching: .any)["add-tag-button"].tap()

        let editor = app.textViews["note-content-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("### iOS E2E note\nCreated from XCUITest")

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 8))

        app.terminate()
        app = XCUIApplication()
        app.launchEnvironment["TAGNOTE_E2E_SERVER_URL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_SERVER_URL"] ?? "http://localhost:3777"
        app.launchEnvironment["TAGNOTE_E2E_EMAIL"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_EMAIL"] ?? "test@test.com"
        app.launchEnvironment["TAGNOTE_E2E_PASSWORD"] = ProcessInfo.processInfo.environment["TAGNOTE_E2E_PASSWORD"] ?? "testpass123"
        app.launchArguments.append("-ui-testing")
        app.launch()

        configureServerIfNeeded()
        loginIfNeeded()

        let notesScreen = app.descendants(matching: .any)["notes-screen"]
        XCTAssertTrue(notesScreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "iOS E2E note")).firstMatch.waitForExistence(timeout: 10))

        let searchField = app.textFields["note-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Created from XCUITest")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "iOS E2E note")).firstMatch.waitForExistence(timeout: 10))
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
}
