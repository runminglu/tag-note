import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        WebStyleAppShell(api: session.api, cache: session.cache)
    }
}

private struct WebStyleAppShell: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let api: TagNoteAPI
    let cache: LocalCache
    @StateObject private var notesViewModel: NotesViewModel
    @StateObject private var tagsViewModel: TagsViewModel
    @StateObject private var trashViewModel: TrashViewModel
    @State private var selection: AppSection = .notes
    @State private var isSidebarOpen = false
    @State private var activeEditorSheet: AppEditorSheet?
    @State private var didAutoOpenEditor = false

    init(api: TagNoteAPI, cache: LocalCache) {
        self.api = api
        self.cache = cache
        _notesViewModel = StateObject(wrappedValue: NotesViewModel(api: api, cache: cache))
        _tagsViewModel = StateObject(wrappedValue: TagsViewModel(api: api, cache: cache))
        _trashViewModel = StateObject(wrappedValue: TrashViewModel(api: api))
    }

    // Adapt by available width (ux_guidelines §9): a persistent sidebar + dense
    // feed when the screen is regular-width (iPad full screen, large split view),
    // the slide-over drawer when compact (phone, narrow split view).
    private var usesPersistentSidebar: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if usesPersistentSidebar {
                regularLayout
            } else {
                compactLayout
            }
        }
        .task {
            await notesViewModel.loadCached()
            await notesViewModel.refresh()
            if shouldAutoOpenEditor {
                didAutoOpenEditor = true
                activeEditorSheet = .create
            }
            if ProcessInfo.processInfo.environment["TAGNOTE_UI_OPEN_SIDEBAR"] == "1" {
                isSidebarOpen = true
            }
        }
        .sheet(item: $activeEditorSheet, onDismiss: { Task { await notesViewModel.refresh() } }) { sheet in
            switch sheet {
            case .create:
                EditorView(viewModel: EditorViewModel(note: nil, api: api))
                    .environmentObject(appState)
            }
        }
    }

    // Desktop-like split: fixed sidebar rail + the active surface fills the rest.
    private var regularLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                SidebarView(
                    selection: $selection,
                    isOpen: .constant(true),
                    isPersistent: true,
                    safeAreaTop: geometry.safeAreaInsets.top,
                    safeAreaBottom: geometry.safeAreaInsets.bottom,
                    notesViewModel: notesViewModel,
                    tagsViewModel: tagsViewModel,
                    createNote: { activeEditorSheet = .create }
                )
                .frame(width: 280)

                Rectangle()
                    .fill(appState.palette.border)
                    .frame(width: 1)
                    .ignoresSafeArea()

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(appState.palette.background.ignoresSafeArea())
    }

    // Phone: header + slide-over drawer.
    private var compactLayout: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(geometry.size.width * 0.72, 280)
            ZStack(alignment: .leading) {
                appState.palette.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    MobileHeader {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isSidebarOpen = true
                        }
                    }

                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isSidebarOpen {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isSidebarOpen = false
                            }
                        }
                }

                SidebarView(
                    selection: $selection,
                    isOpen: $isSidebarOpen,
                    isPersistent: false,
                    safeAreaTop: geometry.safeAreaInsets.top,
                    safeAreaBottom: geometry.safeAreaInsets.bottom,
                    notesViewModel: notesViewModel,
                    tagsViewModel: tagsViewModel,
                    createNote: {
                        activeEditorSheet = .create
                    }
                )
                .frame(width: sidebarWidth)
                .offset(x: isSidebarOpen ? 0 : -sidebarWidth)
                .animation(.easeInOut(duration: 0.22), value: isSidebarOpen)
                .shadow(color: .black.opacity(isSidebarOpen ? 0.28 : 0), radius: 18, x: 4, y: 0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .notes:
            NotesView(viewModel: notesViewModel)
        case .tags:
            TagsView(viewModel: tagsViewModel)
        case .trash:
            TrashView(viewModel: trashViewModel)
        case .settings:
            SettingsView()
        }
    }

    private var shouldAutoOpenEditor: Bool {
        guard !didAutoOpenEditor else { return false }
        return ProcessInfo.processInfo.environment["TAGNOTE_UI_CREATE_NOTE"] == "1" ||
            ProcessInfo.processInfo.arguments.contains("-ui-create-note")
    }
}

private enum AppEditorSheet: Identifiable {
    case create

    var id: String { "create" }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case notes
    case tags
    case trash
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .tags: return "Tags"
        case .trash: return "Trash"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .notes: return "doc.text"
        case .tags: return "tag"
        case .trash: return "trash"
        case .settings: return "gearshape"
        }
    }
}

private struct MobileHeader: View {
    @EnvironmentObject private var appState: AppState
    let openSidebar: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: openSidebar) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.palette.text)
            .accessibilityLabel("Open menu")
            .accessibilityIdentifier("sidebar-open-button")

            BrandMark(size: 32)

            Text("TagNote")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(appState.palette.text)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(appState.palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(appState.palette.border)
                .frame(height: 1)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: SessionStore
    @Binding var selection: AppSection
    @Binding var isOpen: Bool
    var isPersistent = false
    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    @ObservedObject var notesViewModel: NotesViewModel
    @ObservedObject var tagsViewModel: TagsViewModel
    let createNote: () -> Void
    @State private var tagSearch = ""
    @State private var tagFilterText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var tagFilterTask: Task<Void, Never>?

    private var unreviewedTagCount: Int {
        notesViewModel.availableTags.filter(\.isUnreviewed).count
    }

    private var visibleTags: [TagInfo] {
        let q = tagSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return notesViewModel.availableTags }
        return notesViewModel.availableTags.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        // The drawer fills the full height (card bleeds behind the status bar /
        // home indicator), but the ScrollView's FRAME is pinned to the safe area
        // by fixed spacers, so scrolled content is clipped at the status bar
        // instead of sliding under the clock. The insets are measured by the
        // parent layout's root GeometryReader and passed in.
        ZStack {
            appState.palette.card
            VStack(spacing: 0) {
                Color.clear.frame(height: safeAreaTop)
                ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        BrandMark(size: 32)
                        Text("TagNote")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(appState.palette.text)
                    }

                    HStack(spacing: 14) {
                        Text(shortUserLabel)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(appState.palette.secondaryText)
                        SidebarIconButton(systemName: "square.and.arrow.down", label: "Export") {}
                        SidebarIconButton(systemName: "square.and.arrow.up", label: "Import") {}
                        SidebarIconButton(systemName: "sun.max", label: "Theme") {
                            cycleTheme()
                        }
                        Button("Logout") {
                            Task { await session.logout() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(appState.palette.secondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().overlay(appState.palette.border)

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        selection = .notes
                        createNote()
                        close()
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: "plus")
                            Text("New note")
                        }
                    }
                    .sidebarNavStyle(active: false)
                    .accessibilityIdentifier("sidebar-new-note")

                    ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                        Button {
                            selection = section
                            close()
                        } label: {
                            HStack(spacing: 18) {
                                Image(systemName: section.icon)
                                Text(section.title)
                                if section == .tags, unreviewedTagCount > 0 {
                                    Spacer()
                                    Text("\(unreviewedTagCount)")
                                        .font(.system(size: 15, weight: .bold))
                                        .monospacedDigit()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .foregroundStyle(appState.palette.card)
                                        .background(appState.palette.warning)
                                        .clipShape(Capsule())
                                        .accessibilityLabel("\(unreviewedTagCount) unreviewed tags")
                                }
                            }
                        }
                        .sidebarNavStyle(active: selection == section)
                        .accessibilityIdentifier("sidebar-\(section.rawValue)-button")
                    }

                    Button {
                        selection = .settings
                        close()
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: AppSection.settings.icon)
                            Text(AppSection.settings.title)
                        }
                    }
                    .sidebarNavStyle(active: selection == .settings)
                    .accessibilityIdentifier("sidebar-settings-button")
                }
                .padding(18)

                SidebarDivider()

                VStack(alignment: .leading, spacing: 14) {
                    SidebarSectionTitle("Search & Filter")
                    SidebarSearchField(
                        placeholder: "Search content...",
                        text: $notesViewModel.query,
                        accessibilityID: "note-search-field"
                    )
                    .onChange(of: notesViewModel.query) { _, _ in
                        searchTask?.cancel()
                        searchTask = Task {
                            do {
                                try await Task.sleep(nanoseconds: 350_000_000)
                            } catch {
                                return
                            }
                            guard !Task.isCancelled else { return }
                            await notesViewModel.refresh()
                        }
                    }

                    SidebarSearchField(
                        placeholder: "Filter by tags...",
                        text: $tagFilterText,
                        accessibilityID: "tag-filter-summary"
                    )
                    .onSubmit {
                        applyTagFilterText()
                    }
                    .onChange(of: tagFilterText) { _, _ in
                        tagFilterTask?.cancel()
                        tagFilterTask = Task {
                            do {
                                try await Task.sleep(nanoseconds: 450_000_000)
                            } catch {
                                return
                            }
                            guard !Task.isCancelled else { return }
                            await applyTagFilterTextAsync()
                        }
                    }
                    .onChange(of: notesViewModel.selectedTags) { _, tags in
                        let current = tags.joined(separator: ", ")
                        if tagFilterText != current {
                            tagFilterText = current
                        }
                    }

                    Menu {
                        Picker("Sort", selection: $notesViewModel.sort) {
                            Text("Newest first").tag("newest")
                            Text("Recently updated").tag("updated")
                        }
                    } label: {
                        HStack {
                            Text(notesViewModel.sort == "updated" ? "Recently updated" : "Newest first")
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(appState.palette.secondaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(appState.palette.background)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border, lineWidth: 1))
                    }
                    .onChange(of: notesViewModel.sort) { _, _ in
                        Task { await notesViewModel.refresh() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                SidebarDivider()

                VStack(alignment: .leading, spacing: 14) {
                    SidebarSectionTitle("Tags")
                    SidebarSearchField(
                        placeholder: "Search tags...",
                        text: $tagSearch,
                        accessibilityID: "sidebar-tag-search-field"
                    )
                    FlexibleChipGrid(tags: visibleTags, selectedTags: notesViewModel.selectedTags) { tag in
                        Task {
                            await notesViewModel.toggleTagFilter(tag.name)
                            tagFilterText = notesViewModel.selectedTags.joined(separator: ", ")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
                }
                // Clip to the ScrollView's own frame so scrolled content is cut
                // off at the status bar / home indicator instead of drawing into
                // the safe-area spacers (the drawer ignores the safe area).
                .clipped()
                .defaultScrollAnchor(ProcessInfo.processInfo.environment["TAGNOTE_UI_SCROLL_BOTTOM"] == "1" ? .bottom : nil)
                Color.clear.frame(height: safeAreaBottom)
            }
        }
        .ignoresSafeArea()
        .task {
            await tagsViewModel.loadCached()
            await tagsViewModel.refresh()
            await notesViewModel.refreshTagFilters()
            tagFilterText = notesViewModel.selectedTags.joined(separator: ", ")
        }
    }

    private var shortUserLabel: String {
        guard let email = session.user?.email, !email.isEmpty else { return "You" }
        return "\(String(email.prefix(3)))..."
    }

    private func close() {
        guard !isPersistent else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            isOpen = false
        }
    }

    private func cycleTheme() {
        let all = Theme.allCases
        guard let index = all.firstIndex(where: { $0.rawValue == appState.settings.theme }) else {
            var settings = appState.settings
            settings.theme = Theme.everforestDark.rawValue
            Task { await appState.saveSettings(settings) }
            return
        }
        var settings = appState.settings
        settings.theme = all[(index + 1) % all.count].rawValue
        Task { await appState.saveSettings(settings) }
    }

    private func applyTagFilterText() {
        Task { await applyTagFilterTextAsync() }
    }

    private func applyTagFilterTextAsync() async {
        let tags = tagFilterText
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map(String.init)
        await notesViewModel.setTagFilters(tags)
    }
}

private struct SidebarIconButton: View {
    @EnvironmentObject private var appState: AppState
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(appState.palette.secondaryText)
        .accessibilityLabel(label)
    }
}

private struct SidebarSectionTitle: View {
    @EnvironmentObject private var appState: AppState
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(appState.palette.secondaryText)
    }
}

private struct SidebarSearchField: View {
    @EnvironmentObject private var appState: AppState
    let placeholder: String
    @Binding var text: String
    let accessibilityID: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 15, weight: .medium))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 10)
            .frame(height: 42)
            .foregroundStyle(appState.palette.text)
            .background(appState.palette.background)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border, lineWidth: 1))
            .accessibilityIdentifier(accessibilityID)
    }
}

private struct SidebarDivider: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Rectangle()
            .fill(appState.palette.border)
            .frame(height: 1)
    }
}

private struct FlexibleChipGrid: View {
    let tags: [TagInfo]
    let selectedTags: [String]
    let onTap: (TagInfo) -> Void

    var body: some View {
        FlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(tags) { tag in
                TagChip(tag.name, isActive: selectedTags.contains(tag.name), tagInfo: tag) {
                    onTap(tag)
                }
            }
        }
    }
}

private extension View {
    func sidebarNavStyle(active: Bool) -> some View {
        modifier(SidebarNavModifier(active: active))
    }
}

private struct SidebarNavModifier: ViewModifier {
    @EnvironmentObject private var appState: AppState
    let active: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 19, weight: active ? .bold : .semibold))
            .foregroundStyle(active ? appState.palette.text : appState.palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(active ? appState.palette.tagBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)
    }
}

