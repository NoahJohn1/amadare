import SwiftUI
import AmadareCore

struct DashboardView: View {
    enum LoadState: Equatable {
        case loading, ready, notConfigured
        case failed(String)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedDeck") private var selectedDeck = ""
    @State private var decks: [String] = []
    @State private var snapshot: DeckSnapshot?
    @State private var state: LoadState = .loading
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(selectedDeck)|\(model.serverAddress)|\(model.apiKey)") { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .notConfigured:
            message(title: "Connect to Anki",
                    body: "Amadare reviews the cards in your Anki collection. Enter where Anki is running to get started.",
                    retry: false)
        case .failed(let text):
            message(title: "Can't load your decks", body: text, retry: true)
        case .ready:
            readyView
        }
    }

    private var readyView: some View {
        let count = snapshot?.cards.count ?? 0
        return VStack(spacing: 28) {
            Wordmark()

            Menu {
                ForEach(decks, id: \.self) { deck in
                    Button(deck) { selectedDeck = deck }
                }
            } label: {
                Label(selectedDeck, systemImage: "rectangle.stack")
                    .lineLimit(1)
            }
            .buttonStyle(.glass)

            Button {
                if let snapshot { model.startReviews(snapshot.cards) }
            } label: {
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(count == 1 ? "Start review" : "Start reviews").font(.title3)
                }
                .frame(width: 220, height: 160)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: 40))
            .tint(Theme.mizu)
            .disabled(count == 0)

            if count == 0 {
                Text("You're caught up. Cards come back here when Anki schedules them.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let snapshot {
                StageBar(counts: snapshot.stageCounts)
                if snapshot.skipped > 0 {
                    Text("\(snapshot.skipped) due card\(snapshot.skipped == 1 ? "" : "s") can't be typed (empty or image-only) and \(snapshot.skipped == 1 ? "was" : "were") left out.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func message(title: String, body: String, retry: Bool) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.title2.bold())
            Text(body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Settings") { showingSettings = true }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.mizu)
                if retry {
                    Button("Try again") { Task { await load() } }
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(28)
        .glassEffect(in: .rect(cornerRadius: 28))
        .padding(.horizontal, 16)
    }

    private func load() async {
        guard let anki = model.anki else {
            state = .notConfigured
            return
        }
        do {
            decks = try await anki.deckNames().sorted()
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
            snapshot = try await QueueBuilder(anki: anki).snapshot(deck: selectedDeck)
            state = .ready
        } catch is CancellationError {
            // A newer load replaced this one.
        } catch {
            state = .failed(AnkiProblem(error, server: model.serverName).message)
        }
    }
}
