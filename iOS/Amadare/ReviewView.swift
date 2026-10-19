import SwiftUI
import UIKit
import AmadareCore

/// The iPhone review screen: the Mac's, with buttons where the Mac has keyboard shortcuts.
/// Return on the keyboard still checks the answer, then moves to the next card, and the keyboard
/// stays up throughout.
struct ReviewView: View {
    @Environment(AppModel.self) private var model
    let session: ReviewSession

    @State private var text = ""
    @State private var shakes: CGFloat = 0
    /// Furigana before answering, on Meaning cards only. Starts hidden on every card.
    @State private var showMeaningFurigana = false

    @State private var editingMnemonic = false
    @State private var mnemonicDraft = ""
    @State private var mnemonicError: String?
    @FocusState private var mnemonicFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            header
            ScrollView {
                if let card = session.current {
                    VStack(spacing: 16) {
                        PromptView(card: card, showsFurigana: showsFurigana(card))
                        if card.kind != .plain { kindRow(card) }
                        answerField(card)
                        feedback(card)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.never)
        }
        .onChange(of: session.current?.id) {
            showMeaningFurigana = false
            editingMnemonic = false
            mnemonicError = nil
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button("Dashboard", systemImage: "chevron.left") { model.backToDashboard() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Label("\(session.percentCorrect)%", systemImage: "hand.thumbsup.fill")
                Label("\(session.completedCount)/\(session.total)", systemImage: "square.stack.fill")
            }
            .font(.footnote.monospacedDigit())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
            Spacer(minLength: 0)
            Button(session.isWrappingUp ? "Wrapping up" : "Wrap up") { session.wrapUp() }
                .buttonStyle(.glass)
                .disabled(session.isWrappingUp)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Question

    private var isAnswered: Bool {
        if case .answered = session.phase { return true }
        return false
    }

    /// Furigana appears once the card is answered, or on Meaning cards when the toggle is on.
    /// Never before answering a Reading card, where it would give the answer away.
    private func showsFurigana(_ card: ReviewCard) -> Bool {
        isAnswered || (card.kind == .meaning && showMeaningFurigana)
    }

    private func kindRow(_ card: ReviewCard) -> some View {
        let isReading = card.kind == .reading
        return HStack(spacing: 10) {
            Text(isReading ? "Reading" : "Meaning")
                .font(.headline)
                .foregroundStyle(isReading ? .white : .black)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .glassEffect(.regular.tint(isReading ? .black.opacity(0.6) : .white.opacity(0.85)), in: .capsule)
            if card.kind == .meaning, PromptView.hasFurigana(card), !isAnswered {
                Button(showMeaningFurigana ? "Hide furigana" : "Show furigana",
                       systemImage: showMeaningFurigana ? "eye.slash" : "eye") {
                    showMeaningFurigana.toggle()
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func answerField(_ card: ReviewCard) -> some View {
        AnswerTextField(
            text: $text,
            placeholder: placeholder(card.kind),
            transform: card.kind == .reading ? { RomajiConverter.convert($0) } : { $0 },
            isLocked: isAnswered,
            wantsFocus: !editingMnemonic,
            returnKey: isAnswered ? .next : .done,
            onReturn: { onReturn(card) })
            .frame(height: 34)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .glassEffect(fieldGlass, in: .capsule)
            .modifier(Shake(animatableData: shakes))
    }

    // MARK: After answering

    @ViewBuilder
    private func feedback(_ card: ReviewCard) -> some View {
        VStack(spacing: 12) {
            if case .answered(let verdict) = session.phase {
                switch verdict {
                case .exact:
                    EmptyView()
                case .nearMiss(let expected):
                    Text("Close enough. The answer is “\(expected)”.").foregroundStyle(.secondary)
                case .markedCorrect:
                    Text("Marked correct. The answer is “\(card.answer)”.").foregroundStyle(.secondary)
                case .wrong:
                    Text(card.answer).font(.title2).multilineTextAlignment(.center)
                    wrongAnswerButtons
                }
                Button("Next", systemImage: "arrow.right") { onReturn(card) }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.mizu)
                    .controlSize(.large)
                if !card.notes.isEmpty {
                    Text(card.notes).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if let change = session.stageChange {
                    Text("\(change.to > change.from ? "Up to" : "Down to") \(change.to.name)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(change.to.color.opacity(0.8)), in: .capsule)
                }
                if card.mnemonicField != nil { mnemonicSection(card) }
            }
            if let error = session.sendError {
                VStack(spacing: 10) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await session.retrySend() } }
                        .buttonStyle(.glass)
                }
                .padding(16)
                .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .rect(cornerRadius: 18))
            }
        }
    }

    private var wrongAnswerButtons: some View {
        HStack(spacing: 10) {
            Button("Retry", systemImage: "arrow.uturn.backward") {
                session.retry()
                resetField()
            }
            .buttonStyle(.glass)
            Button("Mark correct", systemImage: "checkmark") {
                Task { await session.markCorrect() }
            }
            .buttonStyle(.glass)
        }
    }

    @ViewBuilder
    private func mnemonicSection(_ card: ReviewCard) -> some View {
        let mnemonic = session.mnemonic(for: card)
        VStack(spacing: 10) {
            if editingMnemonic {
                TextEditor(text: $mnemonicDraft)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($mnemonicFocused)
                    .frame(minHeight: 70, maxHeight: 110)
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 18))
                HStack(spacing: 10) {
                    Button("Cancel") { stopEditingMnemonic() }
                        .buttonStyle(.glass)
                    Button("Save mnemonic") { save(mnemonicDraft, for: card) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.mizu)
                }
                if let mnemonicError {
                    Text(mnemonicError).font(.callout).foregroundStyle(.orange)
                }
            } else {
                if !mnemonic.isEmpty {
                    Text(mnemonic)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
                Button(mnemonic.isEmpty ? "Add mnemonic" : "Edit mnemonic", systemImage: "lightbulb") {
                    mnemonicDraft = mnemonic
                    mnemonicError = nil
                    editingMnemonic = true
                    mnemonicFocused = true
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func save(_ text: String, for card: ReviewCard) {
        Task {
            do {
                try await session.saveMnemonic(text.trimmingCharacters(in: .whitespacesAndNewlines), for: card)
                stopEditingMnemonic()
            } catch {
                mnemonicError = "Couldn't save the mnemonic to Anki. Make sure Anki is reachable, then save again."
            }
        }
    }

    private func stopEditingMnemonic() {
        editingMnemonic = false
    }

    // MARK: Answer field behavior

    private func placeholder(_ kind: QuestionKind) -> String {
        switch kind {
        case .reading: "Reading in hiragana"
        case .meaning: "Meaning"
        case .plain: "Answer"
        }
    }

    private var fieldGlass: Glass {
        guard case .answered(let verdict) = session.phase else { return .regular.interactive() }
        return .regular.tint((verdict.isCorrect ? Theme.correct : Theme.wrong).opacity(0.85))
    }

    private func onReturn(_ card: ReviewCard) {
        switch session.phase {
        case .answering:
            var answer = text
            if card.kind == .reading {
                answer = RomajiConverter.convert(text, final: true)
                text = answer
                if RomajiConverter.containsLatin(answer) {
                    shake()
                    return
                }
            }
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            Task {
                await session.submit(answer)
                if case .answered(.nearMiss) = session.phase { shake() }
            }
        case .answered:
            Task {
                await session.advance()
                if session.phase == .answering { resetField() }
            }
        case .finished:
            break
        }
    }

    private func resetField() {
        text = ""
    }

    private func shake() {
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
    }
}

/// The question in an indigo glass slab. Japanese Vocab words get furigana over their kanji
/// (space for it is always reserved, so revealing it doesn't move the word).
struct PromptView: View {
    let card: ReviewCard
    let showsFurigana: Bool

    static func hasFurigana(_ card: ReviewCard) -> Bool {
        card.kind != .plain && Furigana.segments(word: card.prompt, reading: card.reading).contains { $0.ruby != nil }
    }

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 170)
            .glassEffect(.regular.tint(Theme.ai.opacity(0.55)), in: .rect(cornerRadius: 36))
            .contextMenu {
                Button("Copy “\(card.prompt)”", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = card.prompt
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if Self.hasFurigana(card) {
            let size = min(80, max(36, 300 / CGFloat(max(card.prompt.count, 1))))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(Furigana.segments(word: card.prompt, reading: card.reading).enumerated()), id: \.offset) { _, segment in
                    VStack(spacing: 2) {
                        Text(segment.ruby ?? " ")
                            .font(.system(size: size * 0.3))
                            .opacity(showsFurigana && segment.ruby != nil ? 1 : 0)
                            .fixedSize()
                        Text(segment.text).font(.system(size: size))
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: showsFurigana)
        } else {
            Text(card.prompt)
                .font(.system(size: 80))
                .minimumScaleFactor(0.3)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
    }
}
