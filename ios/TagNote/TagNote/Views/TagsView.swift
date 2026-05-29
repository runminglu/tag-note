import SwiftUI

struct TagsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: TagsViewModel
    @State private var renameTarget: TagInfo?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(TagsViewModel.Filter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(appState.palette.background)

                ForEach(viewModel.visibleTags) { tag in
                    TagManagementRow(tag: tag) { importance, urgency in
                        Task { await viewModel.updatePriority(tag, importance: importance, urgency: urgency) }
                    } approve: {
                        Task { await viewModel.approve(tag) }
                    } rename: {
                        renameTarget = tag
                        renameText = tag.name
                    } delete: {
                        Task { await viewModel.delete(tag) }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(appState.palette.background)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(appState.palette.background)
            .navigationTitle("Tags")
            .searchable(text: $viewModel.query, prompt: "Search tags")
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await viewModel.approveAll() }
                    } label: {
                        Label("Approve all", systemImage: "checkmark.seal")
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .task {
                await viewModel.loadCached()
                await viewModel.refresh()
            }
            .alert("Rename tag", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
                TextField("Tag name", text: $renameText)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Rename") {
                    if let renameTarget {
                        Task { await viewModel.rename(renameTarget, to: renameText) }
                    }
                    renameTarget = nil
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

struct TagManagementRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var isExpanded = false
    @State private var importance: Double
    @State private var urgency: Double

    let tag: TagInfo
    let priorityChanged: (Int, Int) -> Void
    let approve: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    init(tag: TagInfo, priorityChanged: @escaping (Int, Int) -> Void, approve: @escaping () -> Void, rename: @escaping () -> Void, delete: @escaping () -> Void) {
        self.tag = tag
        self.priorityChanged = priorityChanged
        self.approve = approve
        self.rename = rename
        self.delete = delete
        self._importance = State(initialValue: Double(tag.importance))
        self._urgency = State(initialValue: Double(tag.urgency))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tag.name)
                            .font(.headline)
                            .foregroundStyle(appState.palette.text)
                        Text("\(tag.noteCount) notes · \(tag.status)")
                            .font(.caption)
                            .foregroundStyle(appState.palette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(appState.palette.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading) {
                    labeledSlider("Importance", value: $importance)
                    labeledSlider("Urgency", value: $urgency)
                    HStack {
                        if tag.isUnreviewed {
                            Button("Approve", action: approve)
                                .buttonStyle(.bordered)
                        }
                        Button("Rename", action: rename)
                            .buttonStyle(.bordered)
                        Button("Delete", role: .destructive, action: delete)
                            .buttonStyle(.bordered)
                        Spacer()
                    }
                }
                .onChange(of: importance) { _, _ in schedulePrioritySave() }
                .onChange(of: urgency) { _, _ in schedulePrioritySave() }
            }
        }
        .padding(14)
        .background(appState.palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border))
    }

    private var priorityColor: Color {
        if importance >= 70 && urgency >= 70 { return appState.palette.destructive }
        if importance >= 70 || urgency >= 70 { return .orange }
        return appState.palette.accent
    }

    private func labeledSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .foregroundStyle(appState.palette.secondaryText)
            }
            .font(.caption)
            Slider(value: value, in: 0...100, step: 1)
        }
    }

    private func schedulePrioritySave() {
        priorityChanged(Int(importance), Int(urgency))
    }
}
