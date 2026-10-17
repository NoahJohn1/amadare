import Observation
import RecallCore

@MainActor
@Observable
final class AppModel {
    enum Screen {
        case dashboard
        case review(ReviewSession)
    }

    var screen: Screen = .dashboard
    let anki: any AnkiService = LiveAnki()

    func startReviews(_ cards: [ReviewCard]) {
        screen = .review(ReviewSession(cards: cards.shuffled(), anki: anki))
    }

    func backToDashboard() {
        screen = .dashboard
    }
}
