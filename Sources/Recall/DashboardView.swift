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
                VStack(spacing: 12) {
                    Text(message)
                    Button("Retry") { Task { await load() } }
                }
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
        return VStack(spacing: 28) {
            Picker("Deck", selection: $selectedDeck) {
                ForEach(decks, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 320)

            VStack(spacing: 4) {
                Text("\(count)").font(.system(size: 72, weight: .bold, design: .rounded))
                Text(count == 1 ? "Review" : "Reviews").font(.title3).foregroundStyle(.secondary)
            }

            Button("Start Reviews") {
                if let snapshot { model.startReviews(snapshot.cards) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(count == 0)

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
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
            Text("Anki isn't open").font(.title2.bold())
            Text("Recall reads your cards from Anki through the AnkiConnect add-on.")
                .foregroundStyle(.secondary)
            HStack {
                Button(isLaunching ? "Opening Anki…" : "Open Anki") {
                    Task {
                        isLaunching = true
                        _ = await AnkiLauncher.openAndWait(anki: model.anki)
                        isLaunching = false
                        await load()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLaunching)
                Button("Retry") { Task { await load() } }
                    .disabled(isLaunching)
            }
        }
    }

    private func load() async {
        do {
            decks = try await model.anki.deckNames().sorted()
            guard !decks.isEmpty else {
                state = .failed("Anki has no decks yet.")
                return
            }
            if !decks.contains(selectedDeck) {
                // Changing the deck restarts this task via .task(id:).
                selectedDeck = decks.first { $0 != "Default" } ?? decks[0]
                return
            }
            snapshot = try await QueueBuilder(anki: model.anki).snapshot(deck: selectedDeck)
            state = .ready
        } catch AnkiError.notRunning {
            state = .notRunning
        } catch {
            state = .failed("Couldn't load your decks: \(error.localizedDescription)")
        }
    }
}
