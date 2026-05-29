import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var settings = TagNoteSettings.fallback

    let session = SessionStore()

    var palette: TagNotePalette {
        TagNotePalette.palette(for: settings.theme)
    }

    func loadCachedSettings() async {
        if let cached = await session.cache.settings() {
            settings = cached
        }
    }

    func refreshSettings() async {
        do {
            let remote = try await session.api.getSettings()
            settings = remote
            await session.cache.saveSettings(remote)
        } catch {
            if let cached = await session.cache.settings() {
                settings = cached
            }
        }
    }

    func saveSettings(_ newSettings: TagNoteSettings) async {
        settings = newSettings
        await session.cache.saveSettings(newSettings)
        do {
            let saved = try await session.api.saveSettings(newSettings)
            settings = saved
            await session.cache.saveSettings(saved)
        } catch {
            // Keep local UI responsive; SettingsView displays the optimistic value.
        }
    }
}
