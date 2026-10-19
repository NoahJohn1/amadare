import SwiftUI
import AmadareCore

@main
struct AmadareApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            // The Mac window frosts the desktop behind it; on the iPhone, a night sky stands in for it.
            LinearGradient(colors: [Theme.ai.opacity(0.45), Theme.ink], startPoint: .top, endPoint: .bottom)
                .background(Theme.ink)
                .ignoresSafeArea()
            KanjiBackdrop(glyph: backdropGlyph)
            RainGlass()
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

    /// The current card's word during reviews; elsewhere the brand mark, 雫 (a drop).
    private var backdropGlyph: String {
        if case .review(let session) = model.screen, let card = session.current {
            return String(card.prompt.prefix(2))
        }
        return Theme.brandGlyph
    }
}
