import SwiftUI
import AnkaniCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    let session: ReviewSession

    var body: some View {
        VStack(spacing: 28) {
            Text("Session complete").font(.largeTitle.bold())
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    stat("\(session.completedCount)", "Reviewed")
                    stat("\(session.percentCorrect)%", "Correct")
                }
            }
            HStack(alignment: .top, spacing: 16) {
                list("Correct", session.correctPrompts, Theme.correct)
                list("Missed", session.missedPrompts, Theme.wrong)
            }
            Button("Back to dashboard") { model.backToDashboard() }
                .buttonStyle(.glassProminent)
                .tint(Theme.violet)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
        .frame(width: 160, height: 110)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private func list(_ title: String, _ prompts: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) (\(prompts.count))").font(.headline).foregroundStyle(color)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { Text($0.element).font(.title3) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 260, height: 240)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}
