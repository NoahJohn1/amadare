import SwiftUI
import RecallCore

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    let session: ReviewSession

    var body: some View {
        VStack(spacing: 24) {
            Text("Session complete").font(.largeTitle.bold())
            HStack(spacing: 48) {
                stat("\(session.completedCount)", "Reviewed")
                stat("\(session.percentCorrect)%", "Correct")
            }
            HStack(alignment: .top, spacing: 24) {
                list("Correct", session.correctPrompts, Theme.correct)
                list("Missed", session.missedPrompts, Theme.wrong)
            }
            Button("Done") { model.backToDashboard() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 44, weight: .bold, design: .rounded))
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func list(_ title: String, _ prompts: [String], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(prompts.count))").font(.headline).foregroundStyle(color)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { Text($0.element).font(.title3) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 240, height: 220)
    }
}
