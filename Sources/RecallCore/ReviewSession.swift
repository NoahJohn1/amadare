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
    /// Saved mnemonics, keyed by note id and field, newer than the cards' own copies.
    public private(set) var savedMnemonics: [String: String] = [:]

    @ObservationIgnored private var missedIds: Set<Int> = []
    /// Cards put back into the queue (missed or retried); wrap up keeps them.
    @ObservationIgnored private var requeuedIds: Set<Int> = []
    /// Whether the current wrong answer is the card's first miss this session (so it can be undone).
    @ObservationIgnored private var firstMissPending = false
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

    /// Checks the answer and shows the verdict. Correct answers go to Anki right away; wrong ones
    /// wait until the user moves on, so Retry or Mark correct can still change them. Empty answers are ignored.
    public func submit(_ typed: String) async {
        guard phase == .answering, let card = current,
              !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let verdict = AnswerChecker.check(typed, against: card.answer, kind: card.kind)
        phase = .answered(verdict)
        if verdict.isCorrect {
            correctAnswers += 1
            pendingSend = (card.id, 3)
            await send()
        } else {
            wrongAnswers += 1
            firstMissPending = missedIds.insert(card.id).inserted
            if firstMissPending { missedPrompts.append(card.prompt) }
            pendingSend = (card.id, 1)
        }
    }

    public func retrySend() async {
        await send()
    }

    /// Wrong answer only: puts the card back in the queue without telling Anki, as if it hadn't been answered.
    public func retry() {
        guard phase == .answered(.wrong), !queue.isEmpty else { return }
        undoWrongAnswer()
        pendingSend = nil
        let card = queue.removeFirst()
        queue.insert(card, at: min(requeueOffset(), queue.count))
        requeuedIds.insert(card.id)
        stageChange = nil
        phase = .answering
    }

    /// Wrong answer only: the user says it was right. Sent to Anki as Good.
    public func markCorrect() async {
        guard phase == .answered(.wrong), let card = current else { return }
        undoWrongAnswer()
        correctAnswers += 1
        phase = .answered(.markedCorrect)
        pendingSend = (card.id, 3)
        await send()
    }

    /// Moves to the next card, first sending the answer to Anki if it hasn't gone yet.
    /// Stays on the card if sending fails.
    public func advance() async {
        guard case .answered(let verdict) = phase, !queue.isEmpty else { return }
        if pendingSend != nil {
            await send()
            guard pendingSend == nil else { return }
        }
        let card = queue.removeFirst()
        if verdict.isCorrect {
            completedCount += 1
            if !missedIds.contains(card.id) { correctPrompts.append(card.prompt) }
        } else {
            queue.insert(card, at: min(requeueOffset(), queue.count))
            requeuedIds.insert(card.id)
        }
        if isWrappingUp { queue.removeAll { !requeuedIds.contains($0.id) } }
        stageChange = nil
        phase = queue.isEmpty ? .finished : .answering
    }

    /// Stops pulling new cards: keeps the card on screen and cards already put back in the queue.
    public func wrapUp() {
        isWrappingUp = true
        guard let first = queue.first else { return }
        queue = [first] + queue.dropFirst().filter { requeuedIds.contains($0.id) }
    }

    public func mnemonic(for card: ReviewCard) -> String {
        guard let field = card.mnemonicField else { return "" }
        return savedMnemonics[Self.mnemonicKey(card.noteId, field)] ?? card.mnemonic
    }

    /// Saves the card's mnemonic to its note in Anki.
    public func saveMnemonic(_ text: String, for card: ReviewCard) async throws {
        guard let field = card.mnemonicField else { return }
        try await anki.updateNoteFields(card.noteId, fields: [field: CardContent.html(fromPlainText: text)])
        savedMnemonics[Self.mnemonicKey(card.noteId, field)] = text
    }

    private static func mnemonicKey(_ noteId: Int, _ field: String) -> String { "\(noteId)|\(field)" }

    private func undoWrongAnswer() {
        guard let card = current else { return }
        wrongAnswers -= 1
        if firstMissPending {
            missedIds.remove(card.id)
            if missedPrompts.last == card.prompt { missedPrompts.removeLast() }
            firstMissPending = false
        }
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
