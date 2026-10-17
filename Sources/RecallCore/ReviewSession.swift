import Foundation
import Observation

public struct StageChange: Sendable, Equatable {
    public let from: Stage
    public let to: Stage

    public init(from: Stage, to: Stage) {
        self.from = from
        self.to = to
    }
}

/// One review session: the queue, the current card's state, and answers sent to Anki.
@MainActor
@Observable
public final class ReviewSession {
    public enum Phase: Equatable {
        case answering
        case answered(Verdict)
        case finished
    }

    /// Remaining cards; the first one is on screen.
    public private(set) var queue: [ReviewCard]
    public private(set) var phase: Phase
    public private(set) var stageChange: StageChange?
    public private(set) var sendError: String?
    public private(set) var isWrappingUp = false
    public private(set) var completedCount = 0
    public private(set) var correctAnswers = 0
    public private(set) var wrongAnswers = 0
    public private(set) var correctPrompts: [String] = []
    public private(set) var missedPrompts: [String] = []

    private let anki: any AnkiService
    private let requeueOffset: () -> Int
    @ObservationIgnored private var missedIds: Set<Int> = []
    @ObservationIgnored private var stages: [Int: Stage]
    @ObservationIgnored private var pendingSend: (cardId: Int, ease: Int)?

    public init(cards: [ReviewCard], anki: any AnkiService,
                requeueOffset: @escaping () -> Int = { Int.random(in: 3...6) }) {
        self.queue = cards
        self.phase = cards.isEmpty ? .finished : .answering
        self.anki = anki
        self.requeueOffset = requeueOffset
        self.stages = Dictionary(cards.map { ($0.id, $0.stage) }, uniquingKeysWith: { first, _ in first })
    }

    public var current: ReviewCard? { queue.first }

    /// Cards finished plus distinct cards still queued.
    public var total: Int { completedCount + Set(queue.map(\.id)).count }

    public var percentCorrect: Int {
        let answered = correctAnswers + wrongAnswers
        return answered == 0 ? 100 : Int((Double(correctAnswers) / Double(answered) * 100).rounded())
    }

    /// Checks the answer, shows the verdict, and sends it to Anki. Empty answers are ignored.
    public func submit(_ typed: String) async {
        guard phase == .answering, let card = current,
              !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let verdict = AnswerChecker.check(typed, against: card.answer, kind: card.kind)
        phase = .answered(verdict)
        if verdict.isCorrect {
            correctAnswers += 1
        } else {
            wrongAnswers += 1
            if missedIds.insert(card.id).inserted { missedPrompts.append(card.prompt) }
        }
        pendingSend = (card.id, verdict.isCorrect ? 3 : 1)
        await send()
    }

    public func retrySend() async {
        await send()
    }

    /// Moves to the next card. Does nothing until the current answer has reached Anki.
    public func advance() {
        guard case .answered(let verdict) = phase, sendError == nil, pendingSend == nil, !queue.isEmpty else { return }
        let card = queue.removeFirst()
        if verdict.isCorrect {
            completedCount += 1
            if !missedIds.contains(card.id) { correctPrompts.append(card.prompt) }
        } else {
            queue.insert(card, at: min(requeueOffset(), queue.count))
        }
        if isWrappingUp { queue.removeAll { !missedIds.contains($0.id) } }
        stageChange = nil
        phase = queue.isEmpty ? .finished : .answering
    }

    /// Stops pulling new cards: keeps the card on screen and cards already missed.
    public func wrapUp() {
        isWrappingUp = true
        guard let first = queue.first else { return }
        queue = [first] + queue.dropFirst().filter { missedIds.contains($0.id) }
    }

    private func send() async {
        guard let pending = pendingSend else { return }
        do {
            try await anki.answerCard(pending.cardId, ease: pending.ease)
            pendingSend = nil
            sendError = nil
        } catch {
            sendError = Self.message(for: error)
            return
        }
        // Only for the badge; failing to read the new interval shouldn't interrupt the session.
        guard let info = try? await anki.cardsInfo([pending.cardId]).first else { return }
        let newStage = Stage(interval: info.interval)
        if let oldStage = stages[pending.cardId], oldStage != newStage,
           current?.id == pending.cardId, case .answered = phase {
            stageChange = StageChange(from: oldStage, to: newStage)
        }
        stages[pending.cardId] = newStage
    }

    static func message(for error: Error) -> String {
        switch error as? AnkiError {
        case .notRunning?: "Couldn't reach Anki to save this answer. Make sure Anki is open."
        case .api(let message)?: "Anki couldn't save this answer: \(message)"
        default: "Couldn't save this answer to Anki."
        }
    }
}
