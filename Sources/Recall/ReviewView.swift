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
        VStack(spacing: 0) {
            header
            if let card = session.current {
                PromptBand(card: card)
                answerArea(card)
            }
            Spacer(minLength: 0)
        }
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button { model.backToDashboard() } label: { Label("Dashboard", systemImage: "chevron.left") }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Label("\(session.percentCorrect)%", systemImage: "hand.thumbsup")
            Label("\(session.completedCount) / \(session.total)", systemImage: "checkmark.circle")
            Button(session.isWrappingUp ? "Wrapping up…" : "Wrap up") { session.wrapUp() }
                .disabled(session.isWrappingUp)
        }
        .padding(12)
    }

    private func answerArea(_ card: ReviewCard) -> some View {
        VStack(spacing: 14) {
            TextField(card.kind == .reading ? "答え" : "Your Response", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 28))
                .multilineTextAlignment(.center)
                .foregroundStyle(fieldTextColor)
                .padding(.vertical, 14)
                .background(fieldColor)
                .focused($fieldFocused)
                .modifier(Shake(animatableData: shakes))
                .onSubmit { onReturn(card) }
                .onChange(of: text) { _, newValue in onEdit(newValue, card) }

            feedback(card)
                .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private func feedback(_ card: ReviewCard) -> some View {
        if case .answered(let verdict) = session.phase {
            VStack(spacing: 10) {
                switch verdict {
                case .exact:
                    EmptyView()
                case .nearMiss(let expected):
                    Text("Close enough. Expected “\(expected)”").foregroundStyle(.secondary)
                case .wrong:
                    Text("Answer").font(.caption).foregroundStyle(.secondary)
                    Text(card.answer).font(.title2).multilineTextAlignment(.center)
                }
                if !card.notes.isEmpty {
                    Text(card.notes).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if let change = session.stageChange {
                    Text("\(change.to > change.from ? "↑" : "↓") \(change.to.name)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(change.to.color, in: Capsule())
                }
            }
        }
        if let error = session.sendError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(error)
                Button("Retry") { Task { await session.retrySend() } }
            }
            .padding(10)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var fieldColor: Color {
        guard case .answered(let verdict) = session.phase else { return Color(nsColor: .textBackgroundColor) }
        return verdict.isCorrect ? Theme.correct : Theme.wrong
    }

    private var fieldTextColor: Color {
        if case .answered = session.phase { return .white }
        return .primary
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
    }

    private func shake() {
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
    }
}

struct PromptBand: View {
    let card: ReviewCard

    var body: some View {
        VStack(spacing: 0) {
            Text(card.prompt)
                .font(.system(size: 72))
                .minimumScaleFactor(0.3)
                .lineLimit(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Theme.promptBand)
            if card.kind != .plain {
                let isReading = card.kind == .reading
                Text(isReading ? "Reading" : "Meaning")
                    .font(.headline)
                    .foregroundStyle(isReading ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isReading ? Theme.readingStrip : Theme.meaningStrip)
            }
        }
    }
}
