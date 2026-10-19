import Foundation
import Observation
import AmadareCore

@MainActor
@Observable
final class AppModel {
    enum Screen {
        case dashboard
        case review(ReviewSession)
    }

    var screen: Screen = .dashboard

    /// Where AnkiConnect is: the Mac for now (`scripts/share-anki.sh`), a home server later.
    var serverAddress: String = UserDefaults.standard.string(forKey: "serverAddress") ?? "" {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "serverAddress")
            preparedNoteType = false
        }
    }

    var apiKey: String = Keychain.read(AppModel.apiKeyAccount) ?? "" {
        didSet {
            Keychain.write(apiKey, account: Self.apiKeyAccount)
            preparedNoteType = false
        }
    }

    private static let apiKeyAccount = "AnkiConnect API key"
    private var preparedNoteType = false

    /// Nil until a server address is set.
    var anki: LiveAnki? {
        LiveAnki.serverURL(from: serverAddress).map { LiveAnki(url: $0, apiKey: apiKey) }
    }

    /// The server's host name, for messages.
    var serverName: String {
        LiveAnki.serverURL(from: serverAddress)?.host() ?? serverAddress
    }

    /// Makes sure Anki has the Japanese Vocab note type, with its Mnemonic field. Runs once per server.
    func prepareAnki() async {
        guard !preparedNoteType, let anki else { return }
        do {
            try await anki.prepareNoteType()
            preparedNoteType = true
        } catch {
            // Anki may not be reachable yet; the dashboard tries again on its next load.
        }
    }

    func startReviews(_ cards: [ReviewCard]) {
        guard let anki else { return }
        screen = .review(ReviewSession(cards: cards.shuffled(), anki: anki))
    }

    func backToDashboard() {
        screen = .dashboard
    }
}
