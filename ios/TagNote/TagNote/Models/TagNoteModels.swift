import Foundation
import SwiftUI

struct User: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let createdAt: Date
    let emailVerified: Bool
    let hasPassword: Bool
    let hasGoogle: Bool

    init(id: String, email: String, displayName: String, createdAt: Date, emailVerified: Bool, hasPassword: Bool, hasGoogle: Bool) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.emailVerified = emailVerified
        self.hasPassword = hasPassword
        self.hasGoogle = hasGoogle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? email
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
        hasPassword = try container.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? true
        hasGoogle = try container.decodeIfPresent(Bool.self, forKey: .hasGoogle) ?? false
    }
}

struct AuthResponse: Codable {
    let token: String?
    let user: User?
    let pendingVerify: Bool?
    let pendingVerifyEmail: String?
}

struct SubNote: Codable, Identifiable, Equatable {
    let id: String
    let shortID: String
    var content: String
    var snippet: String?
    let createdAt: Date
    var updatedAt: Date?
    var tags: [String]
    var pinned: Bool

    var routeID: String { shortID.isEmpty ? id : shortID }
    var displayDate: Date { updatedAt ?? createdAt }

    enum CodingKeys: String, CodingKey {
        case id
        case shortID = "shortId"
        case content
        case snippet
        case createdAt
        case updatedAt
        case tags
        case pinned
    }
}

struct CreateNoteResponse: Codable {
    let id: String
    let shortID: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case shortID = "shortId"
        case createdAt
    }
}

struct CreateNoteRequest: Encodable {
    let content: String
    let tags: [String]
}

struct UpdateNoteRequest: Encodable {
    let content: String?
    let tags: [String]?
}

struct TagInfo: Codable, Identifiable, Equatable {
    let name: String
    var status: String
    var noteCount: Int
    var importance: Int
    var urgency: Int

    var id: String { name }
    var isUnreviewed: Bool { status == "unreviewed" || status == "pending" }
}

struct TagRenameRequest: Encodable {
    let newName: String
}

struct TagPriorityRequest: Encodable {
    let importance: Int?
    let urgency: Int?
}

struct TagNoteSettings: Codable, Equatable {
    var theme: String
    var previewMode: String
    var noteWidth: String

    static let fallback = TagNoteSettings(theme: "everforest-light", previewMode: "plain", noteWidth: "")
}

struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}

enum PreviewMode: String, CaseIterable, Identifiable {
    case write
    case preview

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum SaveStatus: Equatable {
    case idle
    case invalid(String)
    case unsaved
    case saving
    case saved
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            return ""
        case .invalid(let message):
            return message
        case .unsaved:
            return "Unsaved"
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed(let message):
            return message
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case everforestLight = "everforest-light"
    case everforestDark = "everforest-dark"
    case solarizedLight = "solarized-light"
    case solarizedDark = "solarized-dark"
    case gruvboxLight = "gruvbox-light"
    case gruvboxDark = "gruvbox-dark"
    case nordLight = "nord-light"
    case nordDark = "nord-dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everforestLight: return "Everforest Light"
        case .everforestDark: return "Everforest Dark"
        case .solarizedLight: return "Solarized Light"
        case .solarizedDark: return "Solarized Dark"
        case .gruvboxLight: return "Gruvbox Light"
        case .gruvboxDark: return "Gruvbox Dark"
        case .nordLight: return "Nord Light"
        case .nordDark: return "Nord Dark"
        }
    }
}

struct TagNotePalette {
    let background: Color
    let card: Color
    let border: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let tagBackground: Color
    let destructive: Color

    static func palette(for theme: String) -> TagNotePalette {
        switch Theme(rawValue: theme) {
        case .everforestDark:
            return TagNotePalette(background: Color(hex: 0x272E33), card: Color(hex: 0x2D353B), border: Color(hex: 0x374145), text: Color(hex: 0xD3C6AA), secondaryText: Color(hex: 0x9DA9A0), accent: Color(hex: 0xA7C080), tagBackground: Color(hex: 0x374145), destructive: Color(hex: 0xE67E80))
        case .solarizedLight:
            return TagNotePalette(background: Color(hex: 0xEEE8D5), card: Color(hex: 0xFDF6E3), border: Color(hex: 0xD3CBB7), text: Color(hex: 0x657B83), secondaryText: Color(hex: 0x839496), accent: Color(hex: 0x268BD2), tagBackground: Color(hex: 0xE6DFCC), destructive: Color(hex: 0xDC322F))
        case .solarizedDark:
            return TagNotePalette(background: Color(hex: 0x002B36), card: Color(hex: 0x073642), border: Color(hex: 0x0A404D), text: Color(hex: 0x839496), secondaryText: Color(hex: 0x586E75), accent: Color(hex: 0x268BD2), tagBackground: Color(hex: 0x0A404D), destructive: Color(hex: 0xDC322F))
        case .gruvboxLight:
            return TagNotePalette(background: Color(hex: 0xF2E5BC), card: Color(hex: 0xFBF1C7), border: Color(hex: 0xD5C4A1), text: Color(hex: 0x3C3836), secondaryText: Color(hex: 0x7C6F64), accent: Color(hex: 0x79740E), tagBackground: Color(hex: 0xEBDBB2), destructive: Color(hex: 0xCC241D))
        case .gruvboxDark:
            return TagNotePalette(background: Color(hex: 0x282828), card: Color(hex: 0x3C3836), border: Color(hex: 0x504945), text: Color(hex: 0xEBDBB2), secondaryText: Color(hex: 0xA89984), accent: Color(hex: 0xB8BB26), tagBackground: Color(hex: 0x504945), destructive: Color(hex: 0xFB4934))
        case .nordLight:
            return TagNotePalette(background: Color(hex: 0xE5E9F0), card: Color(hex: 0xECEFF4), border: Color(hex: 0xD8DEE9), text: Color(hex: 0x2E3440), secondaryText: Color(hex: 0x4C566A), accent: Color(hex: 0x5E81AC), tagBackground: Color(hex: 0xD8DEE9), destructive: Color(hex: 0xBF616A))
        case .nordDark:
            return TagNotePalette(background: Color(hex: 0x2E3440), card: Color(hex: 0x3B4252), border: Color(hex: 0x434C5E), text: Color(hex: 0xECEFF4), secondaryText: Color(hex: 0xD8DEE9), accent: Color(hex: 0x88C0D0), tagBackground: Color(hex: 0x434C5E), destructive: Color(hex: 0xBF616A))
        default:
            return TagNotePalette(background: Color(hex: 0xF3EAD3), card: Color(hex: 0xFDF6E3), border: Color(hex: 0xD5C4A1), text: Color(hex: 0x5C6A72), secondaryText: Color(hex: 0x829181), accent: Color(hex: 0x8DA101), tagBackground: Color(hex: 0xEAE2CC), destructive: Color(hex: 0xF85552))
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
