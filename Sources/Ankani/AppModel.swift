import Observation
import AnkaniCore

@MainActor
@Observable
final class AppModel {
    enum Screen {
        case dashboard
        case review(ReviewSession)
    }

    var screen: Screen = .dashboard
    let anki = LiveAnki()
    private var preparedMnemonics = false

    /// Makes sure the Japanese Vocab note type has mnemonic fields. Runs once per launch.
    func prepareAnki() async {
        guard !preparedMnemonics else { return }
        do {
            try await anki.prepareMnemonicFields()
            preparedMnemonics = true
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
