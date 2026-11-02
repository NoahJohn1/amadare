import Foundation

/// Where AnkiConnect is and how to authenticate. Remote when `connection.json` names a server;
/// otherwise the local Anki at the default address.
public struct AnkiConnection: Equatable, Sendable {
    public let url: URL
    public let apiKey: String?
    public let isRemote: Bool

    /// The machine's short name, for messages: "nimbasa" for `https://nimbasa.example.ts.net`.
    public var hostName: String {
        url.host()?.split(separator: ".").first.map(String.init) ?? url.absoluteString
    }

    public static func local(apiKey: String?) -> AnkiConnection {
        AnkiConnection(url: LiveAnki.defaultURL, apiKey: apiKey, isRemote: false)
    }

    /// Parses `connection.json`. Nil when it's malformed or names no server, which means local Anki.
    public static func remote(fromJSON data: Data) -> AnkiConnection? {
        struct File: Decodable {
            let url: String
            let apiKey: String?
        }
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              let url = LiveAnki.serverURL(from: file.url)
        else { return nil }
        return AnkiConnection(url: url, apiKey: file.apiKey, isRemote: true)
    }
}
