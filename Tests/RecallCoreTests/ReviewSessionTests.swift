import Testing
@testable import RecallCore

@MainActor
struct ReviewSessionTests {
    @Test func correctAnswerSendsGoodAndFinishes() async {
        let anki = FakeAnki(cards: [])
        let session = ReviewSession(cards: [rc(1, "日記", "diary")], anki: anki)
        await session.submit("Diary")
        #expect(session.phase == .answered(.exact))
        #expect(await anki.answers == [.init(cardId: 1, ease: 3)])
        session.advance()
        #expect(session.phase == .finished)
        #expect(session.completedCount == 1)
        #expect(session.correctPrompts == ["日記"])
        #expect(session.percentCorrect == 100)
    }

    @Test func nearMissCountsAsCorrect() async {
        let session = ReviewSession(cards: [rc(1, "一緒", "Together")], anki: FakeAnki(cards: []))
        await session.submit("togther")
        #expect(session.phase == .answered(.nearMiss(expected: "Together")))
    }

    @Test func wrongAnswerSendsAgainAndRequeuesAtOffset() async {
        let anki = FakeAnki(cards: [])
        let session = ReviewSession(cards: (1...6).map { rc($0, "p\($0)", "a\($0)") }, anki: anki,
                                    requeueOffset: { 3 })
        await session.submit("nope")
        #expect(session.phase == .answered(.wrong))
        #expect(session.missedPrompts == ["p1"])
        session.advance()
        #expect(session.queue.map(\.id) == [2, 3, 4, 1, 5, 6])
        #expect(session.total == 6)
        #expect(await anki.answers == [.init(cardId: 1, ease: 1)])
    }

    @Test func missedCardGoesToEndWhenFewRemainAndStaysMissed() async {
        let anki = FakeAnki(cards: [])
        let session = ReviewSession(cards: [rc(1, "p1", "a1"), rc(2, "p2", "a2")], anki: anki,
                                    requeueOffset: { 3 })
        await session.submit("nope"); session.advance()
        #expect(session.queue.map(\.id) == [2, 1])
        await session.submit("a2"); session.advance()
        await session.submit("a1"); session.advance()
        #expect(session.phase == .finished)
        #expect(session.correctPrompts == ["p2"])
        #expect(session.missedPrompts == ["p1"])
        #expect(session.percentCorrect == 67)
        #expect(await anki.answers == [.init(cardId: 1, ease: 1), .init(cardId: 2, ease: 3), .init(cardId: 1, ease: 3)])
    }

    @Test func emptyAnswerIsIgnored() async {
        let anki = FakeAnki(cards: [])
        let session = ReviewSession(cards: [rc(1, "p1", "a1")], anki: anki)
        await session.submit("   ")
        #expect(session.phase == .answering)
        #expect(await anki.answers.isEmpty)
    }

    @Test func wrapUpKeepsCurrentAndMissedCardsOnly() async {
        let session = ReviewSession(cards: (1...5).map { rc($0, "p\($0)", "a\($0)") }, anki: FakeAnki(cards: []),
                                    requeueOffset: { 3 })
        await session.submit("nope"); session.advance()       // queue: 2 3 4 1 5
        session.wrapUp()
        #expect(session.queue.map(\.id) == [2, 1])
        await session.submit("a2"); session.advance()
        await session.submit("a1"); session.advance()
        #expect(session.phase == .finished)
        #expect(session.completedCount == 2)
    }

    @Test func failedSendBlocksAdvanceUntilRetry() async {
        let anki = FakeAnki(cards: [])
        await anki.setFailAnswers(true)
        let session = ReviewSession(cards: [rc(1, "p1", "a1")], anki: anki)
        await session.submit("a1")
        #expect(session.sendError != nil)
        session.advance()
        #expect(session.phase == .answered(.exact))
        await anki.setFailAnswers(false)
        await session.retrySend()
        #expect(session.sendError == nil)
        #expect(await anki.answers == [.init(cardId: 1, ease: 3)])
        session.advance()
        #expect(session.phase == .finished)
    }

    @Test func stageChangeIsReportedThenCleared() async {
        let anki = FakeAnki(cards: [card(1, interval: 3)])
        await anki.setIntervalAfterAnswer(1, 10)
        let session = ReviewSession(cards: [rc(1, "p1", "a1", stage: .apprentice), rc(2, "p2", "a2")], anki: anki)
        await session.submit("a1")
        #expect(session.stageChange == StageChange(from: .apprentice, to: .guru))
        session.advance()
        #expect(session.stageChange == nil)
    }

    @Test func emptySessionStartsFinished() {
        #expect(ReviewSession(cards: [], anki: FakeAnki(cards: [])).phase == .finished)
    }
}
