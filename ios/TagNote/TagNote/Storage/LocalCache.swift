import Foundation

actor LocalCache {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.keyEncodingStrategy = .convertToSnakeCase
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.tagnoteCacheFractional.date(from: value) ?? ISO8601DateFormatter.tagnoteCache.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
    }

    func notes() -> [SubNote] {
        read([SubNote].self, key: "cache.notes") ?? []
    }

    func saveNotes(_ notes: [SubNote]) {
        write(notes, key: "cache.notes")
    }

    func tags() -> [TagInfo] {
        read([TagInfo].self, key: "cache.tags") ?? []
    }

    func saveTags(_ tags: [TagInfo]) {
        write(tags, key: "cache.tags")
    }

    func settings() -> TagNoteSettings? {
        read(TagNoteSettings.self, key: "cache.settings")
    }

    func saveSettings(_ settings: TagNoteSettings) {
        write(settings, key: "cache.settings")
    }

    func clear() {
        defaults.removeObject(forKey: "cache.notes")
        defaults.removeObject(forKey: "cache.tags")
        defaults.removeObject(forKey: "cache.settings")
    }

    private func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

private extension ISO8601DateFormatter {
    static let tagnoteCacheFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let tagnoteCache: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
