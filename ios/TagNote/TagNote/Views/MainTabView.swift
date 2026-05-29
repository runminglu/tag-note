import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TabView {
            NotesView(viewModel: NotesViewModel(api: session.api, cache: session.cache))
                .tabItem { Label("Notes", systemImage: "doc.text") }

            TagsView(viewModel: TagsViewModel(api: session.api, cache: session.cache))
                .tabItem { Label("Tags", systemImage: "tag") }

            TrashView(viewModel: TrashViewModel(api: session.api))
                .tabItem { Label("Trash", systemImage: "trash") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .background(appState.palette.background)
    }
}
