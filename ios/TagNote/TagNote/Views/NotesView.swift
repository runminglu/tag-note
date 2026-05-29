import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: NotesViewModel
    @State private var activeSheet: NotesSheet?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !viewModel.selectedTags.isEmpty || !viewModel.query.isEmpty {
                    ActiveFiltersBar(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }

                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    emptyState
                }

                ForEach(viewModel.notes) { note in
                    NoteCard(
                        note: note,
                        availableTags: viewModel.availableTags,
                        onTagTap: { tag in
                            Task { await viewModel.toggleTagFilter(tag) }
                        },
                        onExpand: {
                            activeSheet = .edit(note)
                        },
                        onEdit: {
                            activeSheet = .edit(note)
                        },
                        onDelete: {
                            Task { await viewModel.delete(note) }
                        },
                        onPin: {
                            Task { await viewModel.togglePin(note) }
                        }
                    )
                    .accessibilityIdentifier("note-card-\(note.routeID)")
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: note) }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(appState.palette.accent)
                        .padding(.vertical, 18)
                }
            }
        }
        .background(appState.palette.background)
        .refreshable { await viewModel.refresh() }
        .accessibilityIdentifier("notes-screen")
        .task {
            await viewModel.loadCached()
            await viewModel.refresh()
            presentCreateIfRequested()
        }
        .onChange(of: viewModel.isCreateRequested) { _, _ in
            presentCreateIfRequested()
        }
        .sheet(item: $activeSheet, onDismiss: { Task { await viewModel.refresh() } }) { sheet in
            switch sheet {
            case .create:
                EditorView(viewModel: EditorViewModel(note: nil, api: viewModel.api))
                    .environmentObject(appState)
            case .edit(let note):
                EditorView(viewModel: EditorViewModel(note: note, api: viewModel.api))
                    .environmentObject(appState)
            }
        }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var hasActiveFilters: Bool {
        !viewModel.selectedTags.isEmpty || !viewModel.query.isEmpty
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            if hasActiveFilters {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 34, weight: .semibold))
                Text("No notes match the selected tags.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 34, weight: .semibold))
                Text("Write your first note.")
                    .font(.headline)
                    .foregroundStyle(appState.palette.text)
                Button {
                    activeSheet = .create
                } label: {
                    Label("New note", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.palette.accent)
                .accessibilityIdentifier("empty-new-note")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 56)
        .foregroundStyle(appState.palette.secondaryText)
        .accessibilityIdentifier("notes-empty-state")
    }

    private func presentCreateIfRequested() {
        guard viewModel.isCreateRequested else { return }
        viewModel.consumeCreateRequest()
        activeSheet = .create
    }
}

private enum NotesSheet: Identifiable {
    case create
    case edit(SubNote)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let note):
            return "edit-\(note.routeID)"
        }
    }
}

private struct ActiveFiltersBar: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: NotesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.query.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(viewModel.query)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        Task {
                            viewModel.query = ""
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appState.palette.secondaryText)
            }

            if !viewModel.selectedTags.isEmpty {
                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(viewModel.selectedTags, id: \.self) { tag in
                        TagChip(tag, isActive: true, tagInfo: viewModel.availableTags.first { $0.name == tag }) {
                            Task { await viewModel.toggleTagFilter(tag) }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.palette.card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct NoteCard: View {
    @EnvironmentObject private var appState: AppState
    let note: SubNote
    var availableTags: [TagInfo] = []
    let onTagTap: (String) -> Void
    var onExpand: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onPin: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 6) {
                Button {
                    onPin?()
                } label: {
                    Image(systemName: note.pinned ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(note.pinned ? appState.palette.accent : appState.palette.secondaryText)
                .accessibilityLabel(note.pinned ? "Unpin note" : "Pin note")

                FlowLayout(spacing: 6, rowSpacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        TagChip(tag, tagInfo: availableTags.first { $0.name == tag }) { onTagTap(tag) }
                    }
                }

                Spacer(minLength: 0)

                if let priority = priorityStyle {
                    Text(priority.label)
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(priority.text)
                        .background(priority.wash)
                        .overlay(Capsule().stroke(priority.border, lineWidth: 1))
                        .clipShape(Capsule())
                        .accessibilityLabel("Priority: \(priority.label)")
                }
            }

            HStack(alignment: .center) {
                Text(RelativeTime.format(note.displayDate))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(appState.palette.secondaryText)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    CardIconButton(systemName: "arrow.up.left.and.arrow.down.right", label: "Open note") {
                        onExpand?()
                    }
                    CardIconButton(systemName: "square.and.pencil", label: "Edit note") {
                        onEdit?()
                    }
                    CardIconButton(systemName: "trash", label: "Delete note", role: .destructive) {
                        onDelete?()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if let title = previewParts.title {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .lineSpacing(7)
                        .foregroundStyle(appState.palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !previewParts.body.isEmpty {
                    Text(previewParts.body)
                        .font(.system(size: 18, weight: .regular))
                        .lineSpacing(7)
                        .foregroundStyle(appState.palette.text)
                        .lineLimit(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isLongPreview {
                Button("Read more") {
                    onExpand?()
                }
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.plain)
                .foregroundStyle(appState.palette.info)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(priorityStyle?.wash ?? appState.palette.card)
        .overlay(
            Rectangle()
                .stroke(appState.palette.border, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            // Important/urgent priority is encoded on the left edge (ux_guidelines §11).
            if let priority = priorityStyle {
                Rectangle()
                    .fill(priority.border)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .top) {
            // Pinned notes carry a 2px accent top edge (ux_guidelines §11).
            if note.pinned {
                Rectangle()
                    .fill(appState.palette.accent)
                    .frame(height: 2)
            }
        }
    }

    private var priorityStyle: PriorityStyle? {
        guard let peak = TagPriority.peak(for: note.tags, in: availableTags) else { return nil }
        return TagPriority.cardStyle(importance: peak.importance, urgency: peak.urgency, isDark: appState.palette.isDark)
    }

    private var previewText: String {
        let raw = note.snippet?.isEmpty == false ? note.snippet ?? "" : note.content
        let stripped = raw
            .replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`>\[\]()]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? "Untitled note" : stripped
    }

    private var previewParts: (title: String?, body: String) {
        let raw = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return (nil, previewText) }
        let lines = raw.components(separatedBy: .newlines)
        guard let firstIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return (nil, previewText)
        }
        let first = lines[firstIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard first.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil else {
            return (nil, previewText)
        }
        let title = first
            .replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`>\[\]()]+"#, with: "", options: .regularExpression)
        let body = lines.dropFirst(firstIndex + 1)
            .joined(separator: "\n")
            .replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`>\[\]()]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.isEmpty ? nil : title, body)
    }

    private var isLongPreview: Bool {
        previewText.count > 260 || previewText.components(separatedBy: .newlines).count > 7
    }
}

private struct CardIconButton: View {
    @EnvironmentObject private var appState: AppState
    let systemName: String
    let label: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(role == .destructive ? appState.palette.secondaryText : appState.palette.secondaryText)
                .background(appState.palette.tagBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct TagChip: View {
    @EnvironmentObject private var appState: AppState
    let label: String
    var isActive = false
    var tagInfo: TagInfo?
    var action: (() -> Void)?

    init(_ label: String, isActive: Bool = false, tagInfo: TagInfo? = nil, action: (() -> Void)? = nil) {
        self.label = label
        self.isActive = isActive
        self.tagInfo = tagInfo
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            Text("#\(label)")
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // Chips are colored by their tag's Importance × Urgency when known (ux_guidelines §12).
    private var pill: (background: Color, text: Color)? {
        guard let info = tagInfo else { return nil }
        return TagPriority.pillStyle(importance: info.importance, urgency: info.urgency, isActive: isActive, isDark: appState.palette.isDark)
    }

    private var backgroundColor: Color {
        if let pill { return pill.background }
        if isActive { return appState.palette.accent }
        return appState.palette.tagBackground
    }

    private var foregroundColor: Color {
        if let pill { return pill.text }
        if isActive { return appState.palette.card }
        return appState.palette.secondaryText
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposal: proposal)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * rowSpacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, proposal: ProposedViewSize(width: bounds.width, height: proposal.height))
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(for subviews: Subviews, proposal: ProposedViewSize) -> [FlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width
            if nextWidth > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = FlowRow()
            }
            current.elements.append(FlowElement(index: index, size: size))
            current.width = current.elements.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.elements.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct FlowRow {
    var elements: [FlowElement] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}

private struct FlowElement {
    let index: Int
    let size: CGSize
}
