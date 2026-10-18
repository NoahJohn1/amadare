import AppKit
import SwiftUI
import RecallCore

struct DashboardView: View {
    enum LoadState: Equatable {
        case loading, ready, notRunning
        case failed(String)
    }

    @Environment(AppModel.self) private var model
    @AppStorage("selectedDeck") private var selectedDeck = ""
    @State private var decks: [String] = []
    @State private var snapshot: DeckSnapshot?
    @State private var state: LoadState = .loading
    @State private var isLaunching = false

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .notRunning:
                notRunningView
            case .failed(let message):
                VStack(spacing: 16) {
                    Text(message)
                    Button("Try again") { Task { await load() } }
                        .buttonStyle(.glass)
                }
                .padding(32)
                .glassEffect(in: .rect(cornerRadius: 28))
            case .ready:
                readyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: selectedDeck) { await load() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await load() }
        }
    }

    private var readyView: some View {
        let count = snapshot?.cards.count ?? 0
        return VStack(spacing: 32) {
            Menu {
                ForEach(decks, id: \.self) { deck in
                    Button(deck) { selectedDeck = deck }
                }
            } label: {
                Label(selectedDeck, systemImage: "rectangle.stack")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()

            Button {
                if let snapshot { model.startReviews(snapshot.cards) }
            } label: {
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(count == 1 ? "Start review" : "Start reviews").font(.title3)
                }
                .frame(width: 240, height: 170)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: 40))
            .tint(Theme.violet)
            .keyboardShortcut(.defaultAction)
            .disabled(count == 0)

            if count == 0 {
                Text("You're caught up. Cards come back here when Anki schedules them.")
                    .foregroundStyle(.secondary)
            }

            if let snapshot {
                StageBar(counts: snapshot.stageCounts)
                if snapshot.skipped > 0 {
                    Text("\(snapshot.skipped) due card\(snapshot.skipped == 1 ? "" : "s") can't be typed (empty or image-only) and \(snapshot.skipped == 1 ? "was" : "were") left out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(40)
    }

    private var notRunningView: some View {
        VStack(spacing: 16) {
            Text("Anki isn't open").font(.title2.bold())
            Text("Recall reads your cards through AnkiConnect, so Anki needs to be running.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button(isLaunching ? "Opening Anki…" : "Open Anki") {
                    Task {
                        isLaunching = true
                        _ = await AnkiLauncher.openAndWait(anki: model.anki)
                        isLaunching = false
                        await load()
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.violet)
                .disabled(isLaunching)
                Button("Try again") { Task { await load() } }
                    .buttonStyle(.glass)
                    .disabled(isLaunching)
            }
        }
        .padding(36)
        .frame(maxWidth: 440)
        .glassEffect(in: .rect(cornerRadius: 28))
    }

    private func load() async {
        do {
            decks = try await model.anki.deckNames().sorted()
            guard !decks.isEmpty else {
                state = .failed("Anki has no decks yet. Add a deck in Anki, then try again.")
                return
            }
            if !decks.contains(selectedDeck) {
                // Changing the deck restarts this task via .task(id:).
                selectedDeck = decks.first { $0 != "Default" } ?? decks[0]
                return
            }
            await model.prepareAnki()
            snapshot = try await QueueBuilder(anki: model.anki).snapshot(deck: selectedDeck)
            state = .ready
        } catch AnkiError.notRunning {
            state = .notRunning
        } catch {
            state = .failed("Couldn't load your decks: \(error.localizedDescription)")
        }
    }
}
