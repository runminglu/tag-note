import SwiftUI

struct TrashView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: TrashViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("Trash is empty", systemImage: "trash", description: Text("Deleted notes appear here."))
                        .listRowBackground(appState.palette.background)
                }

                ForEach(viewModel.notes) { note in
                    NoteCard(note: note) { _ in }
                        .opacity(0.78)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.restore(note) }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(appState.palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.purge(note) }
                            } label: {
                                Label("Delete forever", systemImage: "xmark.bin")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(appState.palette.background)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(appState.palette.background)
            .navigationTitle("Trash")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
            .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
