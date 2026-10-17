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
                .frame(minWidth: 680, minHeight: 520)
                .onAppear { NSApplication.shared.activate() }
        }
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.screen {
        case .dashboard:
            DashboardView()
        case .review:
            // Replaced by ReviewView / SummaryView in Task 9.
            Button("Back") { model.backToDashboard() }
        }
    }
}
