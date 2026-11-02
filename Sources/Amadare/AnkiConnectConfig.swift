import AmadareCore
import Foundation

/// Reads where AnkiConnect is: the server in `connection.json`, else this Mac. Once `scripts/share-anki.sh`
/// shares this Mac's Anki with the iPhone, AnkiConnect asks every request for its API key, Amadare's own included.
enum AnkiConnectConfig {
    static let addonDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Anki2/addons21/2055492159")
    static let connectionFile = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Amadare/connection.json")

    /// The server named in `connection.json` (see `scripts/use-anki-server.sh`), else this Mac's Anki.
    static func connection() -> AnkiConnection {
        if let data = try? Data(contentsOf: connectionFile), let remote = AnkiConnection.remote(fromJSON: data) {
            return remote
        }
        return .local(apiKey: localAPIKey())
    }

    /// The `apiKey` set in Anki's add-on config (kept in meta.json), or nil when there isn't one.
    static func localAPIKey() -> String? {
        guard let data = try? Data(contentsOf: addonDirectory.appending(path: "meta.json")),
              let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let config = meta["config"] as? [String: Any],
              let key = config["apiKey"] as? String, !key.isEmpty
        else { return nil }
        return key
    }
}
