import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: NotesViewModel
    @State private var activeSheet: NotesSheet?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(appState.palette.secondaryText)
                        TextField("Search content", text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.refresh() }
                            }
                            .accessibilityIdentifier("note-search-field")
                        Button {
                            activeSheet = .filter
                        } label: {
                            Image(systemName: viewModel.selectedTags.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        }
                        .accessibilityLabel("Filter by tags")
                        .accessibilityIdentifier("tag-filter-button")
                    }
                    .padding(12)
                    .background(appState.palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border))
                    .listRowSeparator(.hidden)
                    .listRowBackground(appState.palette.background)

                    if !viewModel.selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.selectedTags, id: \.self) { tag in
                                    TagChip(tag, isActive: true) {
                                        Task { await viewModel.toggleTagFilter(tag) }
                                    }
                                }
                                Button("Clear") {
                                    Task { await viewModel.clearFilters() }
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(appState.palette.background)
                    }

                    if viewModel.notes.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No notes", systemImage: "doc.text.magnifyingglass", description: Text("Create a note or adjust your filters."))
                            .listRowBackground(appState.palette.background)
                    }

                    ForEach(viewModel.notes) { note in
                        NoteCard(note: note) { tag in
                            Task { await viewModel.toggleTagFilter(tag) }
                        }
                        .accessibilityIdentifier("note-card-\(note.routeID)")
                        .contentShape(Rectangle())
                        .onTapGesture { activeSheet = .edit(note) }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.togglePin(note) }
                            } label: {
                                Label(note.pinned ? "Unpin" : "Pin", systemImage: "pin")
                            }
                            .tint(appState.palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(note) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(appState.palette.background)
                        .onAppear {
                            Task { await viewModel.loadMoreIfNeeded(current: note) }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(appState.palette.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(appState.palette.background)
                .refreshable { await viewModel.refresh() }
                .accessibilityIdentifier("notes-screen")

                Button {
                    activeSheet = .create
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3.weight(.semibold))
                        .frame(width: 54, height: 54)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .shadow(radius: 4)
                .padding()
                .accessibilityLabel("Compose")
                .accessibilityIdentifier("new-note-button")
            }
            .navigationTitle("TagNote")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .create
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Compose")
                    .accessibilityIdentifier("new-note-toolbar-button")
                }
                ToolbarItem {
                    Button {
                        activeSheet = .filter
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("Filter by tags")
                }
                ToolbarItem {
                    Menu {
                        Picker("Sort", selection: $viewModel.sort) {
                            Text("Newest first").tag("newest")
                            Text("Recently updated").tag("updated")
                        }
                        .onChange(of: viewModel.sort) { _, _ in
                            Task { await viewModel.refresh() }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .onChange(of: viewModel.query) { _, _ in
                searchTask?.cancel()
                searchTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 350_000_000)
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    await viewModel.refresh()
                }
            }
            .task {
                await viewModel.loadCached()
                await viewModel.refresh()
            }
            .sheet(item: $activeSheet, onDismiss: { Task { await viewModel.refresh() } }) { sheet in
                switch sheet {
                case .create:
                    EditorView(viewModel: EditorViewModel(note: nil, api: viewModel.api))
                        .environmentObject(appState)
                case .edit(let note):
                    EditorView(viewModel: EditorViewModel(note: note, api: viewModel.api))
                        .environmentObject(appState)
                case .filter:
                    TagFilterSheet(viewModel: viewModel)
                        .environmentObject(appState)
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

}

private enum NotesSheet: Identifiable {
    case create
    case edit(SubNote)
    case filter

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let note):
            return "edit-\(note.routeID)"
        case .filter:
            return "filter"
        }
    }
}

struct TagFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: NotesViewModel
    @State private var tagQuery = ""

    private var visibleTags: [TagInfo] {
        let q = tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return viewModel.availableTags }
        return viewModel.availableTags.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.selectedTags.isEmpty {
                    Text("Choose one or more tags. Notes match all selected tags.")
                        .font(.footnote)
                        .foregroundStyle(appState.palette.secondaryText)
                        .listRowBackground(appState.palette.background)
                }

                ForEach(visibleTags) { tag in
                    Button {
                        Task { await viewModel.toggleTagFilter(tag.name) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.name)
                                    .foregroundStyle(appState.palette.text)
                                Text("\(tag.noteCount) notes")
                                    .font(.caption)
                                    .foregroundStyle(appState.palette.secondaryText)
                            }
                            Spacer()
                            if viewModel.selectedTags.contains(tag.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(appState.palette.accent)
                            }
                        }
                    }
                    .accessibilityIdentifier("tag-filter-option-\(tag.name)")
                    .listRowBackground(appState.palette.background)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(appState.palette.background)
            .navigationTitle("Filter by Tags")
            .searchable(text: $tagQuery, prompt: "Search tags")
            .toolbar {
                ToolbarItem {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear Filters") {
                        Task { await viewModel.clearFilters() }
                    }
                    .disabled(viewModel.selectedTags.isEmpty && viewModel.query.isEmpty)
                }
            }
            .task {
                await viewModel.refreshTagFilters()
            }
        }
    }
}

struct NoteCard: View {
    @EnvironmentObject private var appState: AppState
    let note: SubNote
    let onTagTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(note.displayDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(appState.palette.secondaryText)
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(appState.palette.accent)
                }
                Spacer()
            }

            Text(note.snippet?.isEmpty == false ? note.snippet! : note.content)
                .font(.body)
                .lineLimit(6)
                .foregroundStyle(appState.palette.text)

            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(note.tags, id: \.self) { tag in
                            TagChip(tag) { onTagTap(tag) }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(appState.palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(priorityBorder)
    }

    private var priorityBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(note.pinned ? appState.palette.accent : appState.palette.border, lineWidth: note.pinned ? 2 : 1)
    }
}

struct TagChip: View {
    @EnvironmentObject private var appState: AppState
    let label: String
    var isActive = false
    var action: (() -> Void)?

    init(_ label: String, isActive: Bool = false, action: (() -> Void)? = nil) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isActive ? appState.palette.card : appState.palette.text)
                .background(isActive ? appState.palette.accent : appState.palette.tagBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
