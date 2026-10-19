import SwiftUI
import AmadareCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    let session: ReviewSession

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Session complete").font(.largeTitle.bold())
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        stat("\(session.completedCount)", "Reviewed")
                        stat("\(session.percentCorrect)%", "Correct")
                    }
                }
                list("Missed", session.missedPrompts, Theme.wrongText)
                list("Correct", session.correctPrompts, Theme.correctText)
                Button("Back to dashboard") { model.backToDashboard() }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.mizu)
                    .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
        .frame(maxWidth: 160)
        .frame(height: 100)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private func list(_ title: String, _ prompts: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) (\(prompts.count))").font(.headline).foregroundStyle(color)
            ForEach(Array(prompts.enumerated()), id: \.offset) { Text($0.element).font(.title3) }
        }
        .frame(maxWidth: 480, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}
