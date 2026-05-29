import PhotosUI
import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: EditorViewModel
    @State private var tagDraft = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showDiscardPrompt = false
    @State private var showDeletePrompt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tagEditor
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(appState.palette.background)

                Picker("Editor Mode", selection: $viewModel.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if viewModel.previewMode == .write {
                    TextEditor(text: $viewModel.content)
                        .font(.body.monospaced())
                        .foregroundStyle(appState.palette.text)
                        .scrollContentBackground(.hidden)
                        .background(appState.palette.card)
                        .onChange(of: viewModel.content) { _, _ in viewModel.scheduleAutosave() }
                        .accessibilityIdentifier("note-content-editor")
                } else {
                    ScrollView {
                        markdownPreview
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(appState.palette.card)
                }
            }
            .background(appState.palette.background.ignoresSafeArea())
            .navigationTitle(viewModel.isNewNote ? "New note" : "Edit note")
            .accessibilityIdentifier("editor-screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button("Close") {
                        close()
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(viewModel.isNewNote ? "New note" : "Edit note")
                            .font(.headline)
                        if !viewModel.saveStatus.label.isEmpty {
                            Text(viewModel.saveStatus.label)
                                .font(.caption2)
                                .foregroundStyle(statusColor)
                        }
                    }
                }
                ToolbarItem {
                    Menu {
                        Button {
                            Task { await viewModel.saveNow() }
                        } label: {
                            Label("Save now", systemImage: "checkmark")
                        }
                        Button {
                            Task { await viewModel.togglePin() }
                        } label: {
                            Label(viewModel.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Insert image", systemImage: "photo")
                        }
                        if !viewModel.isNewNote {
                            Button(role: .destructive) {
                                showDeletePrompt = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                formattingBar
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(item) }
            }
            .alert("Discard unsaved changes?", isPresented: $showDiscardPrompt) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard", role: .destructive) { dismiss() }
            } message: {
                Text("Your latest edits have not been saved.")
            }
            .alert("Delete note?", isPresented: $showDeletePrompt) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.delete()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                            Button {
                                viewModel.removeTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appState.palette.tagBackground)
                        .clipShape(Capsule())
                    }
                }
            }

            HStack {
                TextField("Add tag", text: $tagDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(commitTagDraft)
                    .onChange(of: tagDraft) { _, value in
                        Task { await viewModel.autocomplete(value) }
                    }
                    .accessibilityIdentifier("tag-input-field")
                Button {
                    commitTagDraft()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("add-tag-button")
            }
            .padding(10)
            .background(appState.palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border))

            if !viewModel.suggestions.isEmpty && !tagDraft.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                            TagChip(suggestion) {
                                viewModel.addTag(suggestion)
                                tagDraft = ""
                            }
                        }
                    }
                }
            }
        }
    }

    private var formattingBar: some View {
        HStack {
            formatButton("B", systemImage: "bold") { wrapSelection(prefix: "**", suffix: "**") }
            formatButton("I", systemImage: "italic") { wrapSelection(prefix: "*", suffix: "*") }
            formatButton("H", systemImage: "textformat.size") { insert(prefix: "## ") }
            formatButton("List", systemImage: "list.bullet") { insert(prefix: "- ") }
            formatButton("Quote", systemImage: "quote.opening") { insert(prefix: "> ") }
            Spacer()
            Button {
                Task { await viewModel.saveNow() }
            } label: {
                Image(systemName: "checkmark.circle")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var markdownPreview: some View {
        MarkdownPreviewView(document: .parse(viewModel.content))
            .environmentObject(appState)
    }

    private var statusColor: Color {
        switch viewModel.saveStatus {
        case .failed, .invalid:
            return appState.palette.destructive
        case .saved:
            return appState.palette.accent
        default:
            return appState.palette.secondaryText
        }
    }

    private func formatButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel(title)
    }

    private func commitTagDraft() {
        viewModel.addTag(tagDraft)
        tagDraft = ""
    }

    private func insert(prefix: String) {
        viewModel.content += viewModel.content.hasSuffix("\n") || viewModel.content.isEmpty ? prefix : "\n\(prefix)"
        viewModel.scheduleAutosave()
    }

    private func wrapSelection(prefix: String, suffix: String) {
        viewModel.content += "\(prefix)\(suffix)"
        viewModel.scheduleAutosave()
    }

    private func close() {
        if viewModel.canCloseCleanly {
            dismiss()
        } else {
            showDiscardPrompt = true
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        await viewModel.uploadImage(data: data, mimeType: "image/jpeg")
        selectedPhoto = nil
    }
}

private struct MarkdownPreviewView: View {
    @EnvironmentObject private var appState: AppState
    let document: MarkdownDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .foregroundStyle(appState.palette.text)
        .textSelection(.enabled)
    }

    private func blockView(_ block: MarkdownBlock) -> AnyView {
        switch block {
        case let .heading(level, text):
            return AnyView(inlineText(text)
                .font(headingFont(level))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading))
        case let .paragraph(text):
            return AnyView(inlineText(text)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading))
        case let .unorderedList(items):
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.semibold))
                        inlineText(item.inlineText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }
            })
        case let .orderedList(start, items):
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(start + index).")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 24, alignment: .trailing)
                        inlineText(item.inlineText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }
            })
        case let .quote(blocks):
            return AnyView(HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(appState.palette.border)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, nested in
                        blockView(nested)
                    }
                }
                .font(.body.italic())
                .foregroundStyle(appState.palette.secondaryText)
            })
        case let .code(text):
            return AnyView(ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(appState.palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(appState.palette.border)))
        case .horizontalRule:
            return AnyView(Rectangle()
                .fill(appState.palette.border)
                .frame(height: 1)
                .padding(.vertical, 4))
        }
    }

    private func inlineText(_ markdown: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return Text(attributed)
        }
        return Text(markdown)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:
            return .title2
        case 2:
            return .title3
        default:
            return .headline
        }
    }
}
