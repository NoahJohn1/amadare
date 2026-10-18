import AppKit
import SwiftUI
import RecallCore

@main
struct RecallApp: App {
    @State private var model = AppModel()

    init() {
        // Gives `swift run` a normal window and Dock icon outside an .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Recall") {
            RootView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 600)
                .preferredColorScheme(.dark)
                // The window itself is frosted: a heavy blur of whatever is behind it.
                .containerBackground(.ultraThickMaterial, for: .window)
                .onAppear { NSApplication.shared.activate() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            KanjiBackdrop(glyph: backdropGlyph)
            switch model.screen {
            case .dashboard:
                DashboardView()
            case .review(let session):
                if session.phase == .finished {
                    SummaryView(session: session)
                } else {
                    ReviewView(session: session)
                }
            }
        }
    }

    /// The current card's word during reviews; 記 ("record") everywhere else.
    private var backdropGlyph: String {
        if case .review(let session) = model.screen, let card = session.current {
            return String(card.prompt.prefix(2))
        }
        return "記"
    }
}
