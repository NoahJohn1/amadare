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

    var body: some View {
        VStack(spacing: 24) {
            header
            Spacer(minLength: 0)
            if let card = session.current {
                promptCard(card)
                if card.kind != .plain { kindPill(card.kind) }
                answerField(card)
                feedback(card)
                    .frame(minHeight: 130, alignment: .top)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 28)
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { model.backToDashboard() } label: { Label("Dashboard", systemImage: "chevron.left") }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
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

    private func promptCard(_ card: ReviewCard) -> some View {
        Text(card.prompt)
            .font(Theme.mincho(104))
            .minimumScaleFactor(0.3)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .frame(maxWidth: 640, minHeight: 230)
            .glassEffect(.regular.tint(Theme.violet.opacity(0.5)), in: .rect(cornerRadius: 40))
    }

    private func kindPill(_ kind: QuestionKind) -> some View {
        let isReading = kind == .reading
        return Text(isReading ? "Reading" : "Meaning")
            .font(.headline)
            .foregroundStyle(isReading ? .white : .black)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(isReading ? .black.opacity(0.6) : .white.opacity(0.85)), in: .capsule)
    }

    private func answerField(_ card: ReviewCard) -> some View {
        TextField(placeholder(card.kind), text: $text)
            .textFieldStyle(.plain)
            .font(card.kind == .reading ? Theme.mincho(30) : .system(size: 28))
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

    @ViewBuilder
    private func feedback(_ card: ReviewCard) -> some View {
        VStack(spacing: 12) {
            if case .answered(let verdict) = session.phase {
                switch verdict {
                case .exact:
                    EmptyView()
                case .nearMiss(let expected):
                    Text("Close enough. The answer is “\(expected)”.").foregroundStyle(.secondary)
                case .wrong:
                    Text(card.answer)
                        .font(card.kind == .reading ? Theme.mincho(26) : .title2)
                        .multilineTextAlignment(.center)
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
        if case .answered = session.phase {
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
        case .answered:
            session.advance()
            if session.phase == .answering {
                submitted = ""
                text = ""
            }
            fieldFocused = true
        case .finished:
            break
        }
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
