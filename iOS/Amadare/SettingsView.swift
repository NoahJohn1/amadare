import SwiftUI
import AmadareCore

/// Where Anki is. Edits take effect when the sheet closes.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var apiKey = ""
    @State private var test: TestState = .idle

    enum TestState: Equatable {
        case idle, testing
        case passed(String)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.20 or my-mac.local", text: $address)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anki server")
                } footer: {
                    Text("Run scripts/share-anki.sh on your Mac. It shares Anki on your network and prints the address and API key to enter here. Anki has to stay open on the Mac while you review.")
                }

                Section {
                    Button(test == .testing ? "Testing…" : "Test connection") {
                        Task { await runTest() }
                    }
                    .disabled(LiveAnki.serverURL(from: address) == nil || test == .testing)
                    switch test {
                    case .idle, .testing:
                        EmptyView()
                    case .passed(let message):
                        Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.correctText)
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                address = model.serverAddress
                apiKey = model.apiKey
            }
            .onChange(of: address) { test = .idle }
            .onChange(of: apiKey) { test = .idle }
        }
    }

    private func save() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAddress != model.serverAddress { model.serverAddress = trimmedAddress }
        if trimmedKey != model.apiKey { model.apiKey = trimmedKey }
    }

    private func runTest() async {
        guard let url = LiveAnki.serverURL(from: address) else { return }
        let tested = (address, apiKey)
        test = .testing
        let anki = LiveAnki(url: url, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        let result: TestState
        do {
            let decks = try await anki.deckNames()
            result = .passed("Connected. Anki has \(decks.count) deck\(decks.count == 1 ? "" : "s").")
        } catch {
            result = .failed(AnkiProblem(error, server: url.host() ?? address).message)
        }
        // Ignore the answer if the fields changed while it was on its way.
        if tested == (address, apiKey) { test = result }
    }
}

/// What went wrong talking to Anki, in words for the person holding the phone.
struct AnkiProblem {
    let message: String
    let isUnreachable: Bool

    init(_ error: Error, server: String) {
        switch error {
        case AnkiError.notRunning:
            message = "Couldn't reach Anki at \(server). Make sure Anki is open there and your iPhone is on the same network (or Tailscale)."
            isUnreachable = true
        case AnkiError.api(let text) where text.localizedCaseInsensitiveContains("api key"):
            message = "Anki turned down the API key. Check it in Settings against what scripts/share-anki.sh printed."
            isUnreachable = false
        case AnkiError.api(let text):
            message = "Anki said: \(text)"
            isUnreachable = false
        default:
            message = "Something at \(server) answered, but not like AnkiConnect. Check the address."
            isUnreachable = false
        }
    }
}
