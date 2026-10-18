import AppKit
import SwiftUI
import RecallCore

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    let session: ReviewSession

    @State private var text = ""
    /// The answer as submitted; the field is held at this value until the next card.
    @State private var submitted = ""
    @State private var shakes: CGFloat = 0
    @FocusState private var fieldFocused: Bool
    @AppStorage("showMeaningFurigana") private var showMeaningFurigana = false

    @State private var editingMnemonic = false
    @State private var mnemonicDraft = ""
    @State private var mnemonicError: String?
    @FocusState private var mnemonicFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer(minLength: 0)
            if let card = session.current {
                PromptView(card: card, showsFurigana: showsFurigana(card))
                if card.kind != .plain { kindRow(card) }
                answerField(card)
                feedback(card)
                    .frame(minHeight: 150, alignment: .top)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
        .onAppear { fieldFocused = true }
        .onChange(of: session.current?.id) {
            editingMnemonic = false
            mnemonicError = nil
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { model.backToDashboard() } label: { Label("Dashboard", systemImage: "chevron.left") }
                .buttonStyle(.glass)
                .keyboardShortcut(editingMnemonic ? nil : .cancelAction)
            Spacer()
            HStack(spacing: 16) {
                Label("\(session.percentCorrect)%", systemImage: "hand.thumbsup.fill")
                Label("\(session.completedCount) of \(session.total)", systemImage: "square.stack.fill")
            }
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
            Button(session.isWrappingUp ? "Wrapping up" : "Wrap up") { session.wrapUp() }
                .buttonStyle(.glass)
                .disabled(session.isWrappingUp)
        }
        .padding(.top, 36)   // clear the window's traffic lights
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
                .keyboardShortcut("f")
                .help("Show or hide the reading above the kanji (⌘F)")
            }
        }
    }

    private func answerField(_ card: ReviewCard) -> some View {
        TextField(placeholder(card.kind), text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 28))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .focused($fieldFocused)
            .onSubmit { onReturn(card) }
            .onChange(of: text) { _, newValue in onEdit(newValue, card) }
            .padding(.vertical, 16)
            .padding(.horizontal, 28)
            .frame(maxWidth: 560)
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
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error)
                    Button("Retry") { Task { await session.retrySend() } }
                        .buttonStyle(.glass)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
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
            .keyboardShortcut("r")
            .help("Put this card back in the queue without telling Anki you missed it (⌘R)")
            Button("Mark correct", systemImage: "checkmark") {
                Task { await session.markCorrect() }
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Count your answer as right (⌘Return)")
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
                    .frame(maxWidth: 520, minHeight: 70, maxHeight: 110)
                    .padding(12)
                    .glassEffect(in: .rect(cornerRadius: 18))
                    .onKeyPress(.escape) {
                        stopEditingMnemonic()
                        return .handled
                    }
                HStack(spacing: 10) {
                    Button("Cancel") { stopEditingMnemonic() }
                        .buttonStyle(.glass)
                    Button("Save mnemonic") { save(mnemonicDraft, for: card) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.violet)
                        .keyboardShortcut("s")
                }
                if let mnemonicError {
                    Text(mnemonicError).font(.callout).foregroundStyle(.orange)
                }
            } else {
                if !mnemonic.isEmpty {
                    Text(mnemonic)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                        .textSelection(.enabled)
                }
                Button(mnemonic.isEmpty ? "Add mnemonic" : "Edit mnemonic", systemImage: "lightbulb") {
                    mnemonicDraft = mnemonic
                    mnemonicError = nil
                    editingMnemonic = true
                    mnemonicFocused = true
                }
                .buttonStyle(.glass)
                .keyboardShortcut("e")
                .help("Write a memory aid for this card, saved to the note in Anki (⌘E)")
            }
        }
    }

    private func save(_ text: String, for card: ReviewCard) {
        Task {
            do {
                try await session.saveMnemonic(text.trimmingCharacters(in: .whitespacesAndNewlines), for: card)
                stopEditingMnemonic()
            } catch {
                mnemonicError = "Couldn't save the mnemonic to Anki. Make sure Anki is open, then save again."
            }
        }
    }

    private func stopEditingMnemonic() {
        editingMnemonic = false
        fieldFocused = true
        placeCaretAtEnd()
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

    private func onEdit(_ newValue: String, _ card: ReviewCard) {
        if isAnswered {
            if newValue != submitted { text = submitted }
            return
        }
        if card.kind == .reading {
            let converted = RomajiConverter.convert(newValue)
            if converted != newValue { text = converted }
        }
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
                    placeCaretAtEnd()
                    return
                }
            }
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            submitted = answer
            Task {
                await session.submit(answer)
                if case .answered(.nearMiss) = session.phase { shake() }
            }
            placeCaretAtEnd()
        case .answered:
            Task {
                await session.advance()
                if session.phase == .answering { resetField() } else { placeCaretAtEnd() }
            }
        case .finished:
            break
        }
    }

    private func resetField() {
        submitted = ""
        text = ""
        fieldFocused = true
        placeCaretAtEnd()
    }

    /// Return makes AppKit end editing and re-select the field's whole text.
    /// Once that has happened, put the caret back after the text instead.
    private func placeCaretAtEnd() {
        DispatchQueue.main.async {
            guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
    }

    private func shake() {
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
    }
}

/// The question in a violet glass slab. Japanese Vocab words get furigana over their kanji
/// (space for it is always reserved, so revealing it doesn't move the word). Selectable for copying.
struct PromptView: View {
    let card: ReviewCard
    let showsFurigana: Bool

    static func hasFurigana(_ card: ReviewCard) -> Bool {
        card.kind != .plain && Furigana.segments(word: card.prompt, reading: card.reading).contains { $0.ruby != nil }
    }

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .frame(maxWidth: 640, minHeight: 210)
            .glassEffect(.regular.tint(Theme.violet.opacity(0.5)), in: .rect(cornerRadius: 40))
            .contextMenu {
                Button("Copy “\(card.prompt)”") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(card.prompt, forType: .string)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if Self.hasFurigana(card) {
            let size = min(104, max(44, 600 / CGFloat(max(card.prompt.count, 1))))
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
            .textSelection(.enabled)
            .animation(.easeOut(duration: 0.2), value: showsFurigana)
        } else {
            Text(card.prompt)
                .font(.system(size: 104))
                .minimumScaleFactor(0.3)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
    }
}
