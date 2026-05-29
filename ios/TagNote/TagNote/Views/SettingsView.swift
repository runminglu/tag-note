import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let user = session.user {
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Name", value: user.displayName.isEmpty ? "TagNote user" : user.displayName)
                    }
                    Button(role: .destructive) {
                        Task { await session.logout() }
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("Server") {
                    LabeledContent("URL", value: session.serverURL?.absoluteString ?? "")
                    Button(role: .destructive) {
                        session.resetServer()
                    } label: {
                        Label("Change server", systemImage: "server.rack")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: themeBinding) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    Picker("Preview mode", selection: previewModeBinding) {
                        Text("Plain").tag("plain")
                        Text("Rendered").tag("rendered")
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(appState.palette.background)
        }
    }

    private var themeBinding: Binding<String> {
        Binding {
            appState.settings.theme
        } set: { value in
            var settings = appState.settings
            settings.theme = value
            Task { await appState.saveSettings(settings) }
        }
    }

    private var previewModeBinding: Binding<String> {
        Binding {
            appState.settings.previewMode
        } set: { value in
            var settings = appState.settings
            settings.previewMode = value
            Task { await appState.saveSettings(settings) }
        }
    }
}
