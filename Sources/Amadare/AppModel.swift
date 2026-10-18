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
    let anki = LiveAnki()
    private var preparedNoteType = false

    /// Makes sure Anki has the Japanese Vocab note type, with its Mnemonic field. Runs once per launch.
    func prepareAnki() async {
        guard !preparedNoteType else { return }
        do {
            try await anki.prepareNoteType()
            preparedNoteType = true
        } catch {
            // Anki may not be running yet; the dashboard tries again on its next load.
        }
    }

    func startReviews(_ cards: [ReviewCard]) {
        screen = .review(ReviewSession(cards: cards.shuffled(), anki: anki))
    }

    func backToDashboard() {
        screen = .dashboard
    }
}
