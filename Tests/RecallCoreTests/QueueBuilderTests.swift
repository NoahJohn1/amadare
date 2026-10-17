import Testing
@testable import RecallCore

private let d = #"deck:"Inbox""#

private func inbox(perDay: Int, introducedToday: Int) -> FakeAnki {
    FakeAnki(cards: [
        card(1, interval: 3), card(2, interval: 40),                                   // due reviews
        card(3, fields: ["Front": "x", "Back": "<img src=a.png>"], interval: 2),       // due, untypeable
        card(10, type: 0, interval: 0, due: 2), card(11, type: 0, interval: 0, due: 1),
        card(12, type: 0, interval: 0, due: 3),                                        // new
        card(20, interval: 200),                                                       // not due
    ], queries: [
        "\(d) -is:suspended": [1, 2, 3, 10, 11, 12, 20],
        "\(d) is:due -is:suspended -is:buried": [1, 2, 3],
        "\(d) introduced:1": Array(100..<(100 + introducedToday)),
        "\(d) is:new -is:suspended -is:buried": [10, 11, 12],
    ], perDay: perDay)
}

@Test func dueCardsThenNewCardsUpToTodaysLimit() async throws {
    let snapshot = try await QueueBuilder(anki: inbox(perDay: 3, introducedToday: 1)).snapshot(deck: "Inbox")
    #expect(snapshot.cards.map(\.id) == [1, 2, 11, 10])   // new cards in Anki's position order
    #expect(snapshot.skipped == 1)
}

@Test func noNewCardsOnceLimitIsReached() async throws {
    let snapshot = try await QueueBuilder(anki: inbox(perDay: 2, introducedToday: 5)).snapshot(deck: "Inbox")
    #expect(snapshot.cards.map(\.id) == [1, 2])
}

@Test func stageCountsCoverEveryUnsuspendedCard() async throws {
    let snapshot = try await QueueBuilder(anki: inbox(perDay: 3, introducedToday: 0)).snapshot(deck: "Inbox")
    #expect(snapshot.stageCounts == [.apprentice: 5, .master: 1, .burned: 1])
}

@Test func deckNamesAreQuoted() async throws {
    let anki = FakeAnki(cards: [card(1)], queries: [
        #"deck:"My \"Deck\"" -is:suspended"#: [1],
        #"deck:"My \"Deck\"" is:due -is:suspended -is:buried"#: [1],
    ])
    let snapshot = try await QueueBuilder(anki: anki).snapshot(deck: #"My "Deck""#)
    #expect(snapshot.cards.map(\.id) == [1])
}
