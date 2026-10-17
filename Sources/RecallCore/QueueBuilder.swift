/// What the dashboard shows for a deck, and the cards a session would review.
public struct DeckSnapshot: Sendable, Equatable {
    /// Due cards, then today's new cards in Anki's new-card order. Not shuffled.
    public let cards: [ReviewCard]
    /// Due or new-today cards left out because they can't be type-checked.
    public let skipped: Int
    /// Every unsuspended card in the deck, by stage.
    public let stageCounts: [Stage: Int]

    public init(cards: [ReviewCard], skipped: Int, stageCounts: [Stage: Int]) {
        self.cards = cards
        self.skipped = skipped
        self.stageCounts = stageCounts
    }
}

public struct QueueBuilder: Sendable {
    let anki: any AnkiService

    public init(anki: any AnkiService) {
        self.anki = anki
    }

    public func snapshot(deck: String) async throws -> DeckSnapshot {
        let d = "deck:\"\(deck.replacingOccurrences(of: "\"", with: "\\\""))\""

        let infos = try await anki.cardsInfo(try await anki.findCards("\(d) -is:suspended"))
        let byId = Dictionary(infos.map { ($0.cardId, $0) }, uniquingKeysWith: { first, _ in first })

        let due = try await anki.findCards("\(d) is:due -is:suspended -is:buried").compactMap { byId[$0] }
        let perDay = try await anki.newCardsPerDay(deck: deck)
        let introducedToday = try await anki.findCards("\(d) introduced:1").count
        let newToday = try await anki.findCards("\(d) is:new -is:suspended -is:buried")
            .compactMap { byId[$0] }
            .sorted { $0.due < $1.due }
            .prefix(max(0, perDay - introducedToday))

        let selected = due + newToday
        let cards = selected.compactMap(CardContent.reviewCard(from:))
        var stageCounts: [Stage: Int] = [:]
        for info in infos { stageCounts[Stage(interval: info.interval), default: 0] += 1 }
        return DeckSnapshot(cards: cards, skipped: selected.count - cards.count, stageCounts: stageCounts)
    }
}
