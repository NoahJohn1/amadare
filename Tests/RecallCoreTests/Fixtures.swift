@testable import RecallCore

func card(
    _ id: Int,
    model: String = "Basic",
    ord: Int = 0,
    fields: KeyValuePairs<String, String> = ["Front": "front", "Back": "back"],
    type: Int = 2,
    interval: Int = 10,
    due: Int = 0
) -> CardInfo {
    CardInfo(
        cardId: id, noteId: id, modelName: model, ord: ord, type: type, interval: interval, due: due,
        fieldNames: fields.map(\.key),
        fields: Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })
    )
}

func vocab(_ id: Int, ord: Int, word: String, meaning: String, reading: String,
           notes: String = "", interval: Int = 0) -> CardInfo {
    card(id, model: "Japanese Vocab", ord: ord,
         fields: ["Word": word, "Meaning": meaning, "Reading": reading, "Notes": notes],
         type: interval == 0 ? 0 : 2, interval: interval)
}

extension CardInfo {
    func with(interval: Int) -> CardInfo {
        CardInfo(cardId: cardId, noteId: noteId, modelName: modelName, ord: ord, type: 2,
                 interval: interval, due: due, fieldNames: fieldNames, fields: fields)
    }
}

/// In-memory Anki. `queries` maps exact findCards query strings to card ids.
actor FakeAnki: AnkiService {
    struct Answer: Equatable, Sendable {
        let cardId: Int
        let ease: Int
    }

    private var cards: [Int: CardInfo]
    private let queries: [String: [Int]]
    private let perDay: Int
    private var failAnswers = false
    private var intervalAfterAnswer: [Int: Int] = [:]
    private(set) var answers: [Answer] = []

    init(cards: [CardInfo], queries: [String: [Int]] = [:], perDay: Int = 20) {
        self.cards = Dictionary(uniqueKeysWithValues: cards.map { ($0.cardId, $0) })
        self.queries = queries
        self.perDay = perDay
    }

    func setFailAnswers(_ fail: Bool) { failAnswers = fail }
    func setIntervalAfterAnswer(_ cardId: Int, _ interval: Int) { intervalAfterAnswer[cardId] = interval }

    func deckNames() async throws -> [String] { ["Default", "Inbox"] }
    func findCards(_ query: String) async throws -> [Int] { queries[query] ?? [] }
    func cardsInfo(_ cardIds: [Int]) async throws -> [CardInfo] { cardIds.compactMap { cards[$0] } }
    func newCardsPerDay(deck: String) async throws -> Int { perDay }

    func answerCard(_ cardId: Int, ease: Int) async throws {
        if failAnswers { throw AnkiError.notRunning }
        answers.append(Answer(cardId: cardId, ease: ease))
        if let interval = intervalAfterAnswer[cardId], let info = cards[cardId] {
            cards[cardId] = info.with(interval: interval)
        }
    }
}
