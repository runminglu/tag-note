import XCTest
@testable import TagNote

final class TagNoteModelDecodingTests: XCTestCase {
    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: value) ?? plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
    }

    func testAuthResponseDecodesMinimalUserWithDefaults() throws {
        let data = Data("""
        {
          "token": "jwt-token",
          "user": {
            "id": "user-1",
            "email": "test@test.com"
          }
        }
        """.utf8)

        let response = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertEqual(response.token, "jwt-token")
        XCTAssertEqual(response.user?.id, "user-1")
        XCTAssertEqual(response.user?.email, "test@test.com")
        XCTAssertEqual(response.user?.displayName, "test@test.com")
        XCTAssertFalse(response.user?.emailVerified ?? true)
        XCTAssertTrue(response.user?.hasPassword ?? false)
        XCTAssertFalse(response.user?.hasGoogle ?? true)
    }

    func testAuthResponseDecodesPendingVerificationWithoutToken() throws {
        let data = Data("""
        {
          "user": {
            "id": "user-1",
            "email": "test@test.com",
            "display_name": "Test User",
            "created_at": "2026-05-28T08:00:00Z"
          },
          "pending_verify": true,
          "pending_verify_email": "test@test.com"
        }
        """.utf8)

        let response = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertNil(response.token)
        XCTAssertEqual(response.user?.displayName, "Test User")
        XCTAssertEqual(response.pendingVerify, true)
        XCTAssertEqual(response.pendingVerifyEmail, "test@test.com")
    }

    func testCreateNoteResponseDecodesShortID() throws {
        let data = Data("""
        {
          "id": "01J00000000000000000000000",
          "short_id": "01J0000000",
          "created_at": "2026-05-28T08:00:00.123Z"
        }
        """.utf8)

        let response = try decoder.decode(CreateNoteResponse.self, from: data)

        XCTAssertEqual(response.id, "01J00000000000000000000000")
        XCTAssertEqual(response.shortID, "01J0000000")
    }

    func testSubNoteDecodesServerSnakeCaseFields() throws {
        let data = Data("""
        {
          "id": "01J00000000000000000000000",
          "short_id": "01J0000000",
          "content": "### Hello world",
          "snippet": "Hello world",
          "created_at": "2026-05-28T08:00:00Z",
          "updated_at": "2026-05-28T08:01:00Z",
          "tags": ["hello", "ios"],
          "pinned": true
        }
        """.utf8)

        let note = try decoder.decode(SubNote.self, from: data)

        XCTAssertEqual(note.shortID, "01J0000000")
        XCTAssertEqual(note.routeID, "01J0000000")
        XCTAssertEqual(note.tags, ["hello", "ios"])
        XCTAssertTrue(note.pinned)
    }
}
