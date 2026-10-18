import AppKit
import AmadareCore

@MainActor
enum AnkiLauncher {
    static let bundleID = "net.ankiweb.anki"

    /// Opens Anki in the background and waits for AnkiConnect to answer. False after ~20 s.
    static func openAndWait(anki: any AnkiService) async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        for _ in 0..<20 {
            if (try? await anki.deckNames()) != nil { return true }
            try? await Task.sleep(for: .seconds(1))
        }
        return false
    }
}
