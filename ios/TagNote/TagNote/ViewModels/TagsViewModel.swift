import Foundation

@MainActor
final class TagsViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case unreviewed
        case approved

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    @Published var tags: [TagInfo] = []
    @Published var query = ""
    @Published var filter: Filter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: TagNoteAPI
    private let cache: LocalCache

    var visibleTags: [TagInfo] {
        tags.filter { tag in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .unreviewed:
                matchesFilter = tag.isUnreviewed
            case .approved:
                matchesFilter = tag.status == "approved"
            }
            let matchesQuery = query.trimmed.isEmpty || tag.name.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesQuery
        }
        .sorted { $0.name < $1.name }
    }

    init(api: TagNoteAPI, cache: LocalCache) {
        self.api = api
        self.cache = cache
    }

    func loadCached() async {
        tags = await cache.tags()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tags = try await api.listTagsDetailed()
            await cache.saveTags(tags)
        } catch {
            errorMessage = error.localizedDescription
            if tags.isEmpty {
                tags = await cache.tags()
            }
        }
    }

    func approve(_ tag: TagInfo) async {
        await mutate {
            try await api.approveTag(tag.name)
        }
    }

    func approveAll() async {
        await mutate {
            try await api.approveAllTags()
        }
    }

    func rename(_ tag: TagInfo, to newName: String) async {
        await mutate {
            try await api.renameTag(tag.name, to: newName)
        }
    }

    func updatePriority(_ tag: TagInfo, importance: Int, urgency: Int) async {
        await mutate {
            try await api.updateTagPriority(tag.name, importance: importance, urgency: urgency)
        }
    }

    func delete(_ tag: TagInfo) async {
        await mutate {
            try await api.deleteTag(tag.name)
        }
    }

    private func mutate(_ action: () async throws -> Void) async {
        do {
            try await action()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var notes: [SubNote] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: TagNoteAPI

    init(api: TagNoteAPI) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            notes = try await api.listTrash()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(_ note: SubNote) async {
        do {
            try await api.restoreNote(id: note.routeID)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purge(_ note: SubNote) async {
        do {
            try await api.purgeNote(id: note.routeID)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
