import Foundation

public enum AnkiError: Error, Equatable, Sendable {
    /// Nothing answered on the AnkiConnect port: Anki is closed or the add-on is missing.
    case notRunning
    /// AnkiConnect answered with a non-null `error`.
    case api(String)
    case badResponse
}

/// The parts of AnkiConnect's `cardsInfo` that Amadare uses.
public struct CardInfo: Sendable, Equatable {
    public let cardId: Int
    public let noteId: Int
    public let modelName: String
    /// Index of the card's template within the note type.
    public let ord: Int
    /// 0 new, 1 learning, 2 review, 3 relearning.
    public let type: Int
    /// Days when positive; seconds of a learning step when negative.
    public let interval: Int
    /// For new cards, the new-card position.
    public let due: Int
    /// Field names in note-type order.
    public let fieldNames: [String]
    /// Raw field HTML by field name.
    public let fields: [String: String]

    public init(cardId: Int, noteId: Int, modelName: String, ord: Int, type: Int, interval: Int, due: Int,
                fieldNames: [String], fields: [String: String]) {
        self.cardId = cardId
        self.noteId = noteId
        self.modelName = modelName
        self.ord = ord
        self.type = type
        self.interval = interval
        self.due = due
        self.fieldNames = fieldNames
        self.fields = fields
    }
}

extension CardInfo: Decodable {
    private enum CodingKeys: String, CodingKey {
        case cardId, note, modelName, ord, type, interval, due, fields
    }

    private struct Field: Decodable {
        let value: String
        let order: Int
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([String: Field].self, forKey: .fields)
        self.init(
            cardId: try c.decode(Int.self, forKey: .cardId),
            noteId: try c.decode(Int.self, forKey: .note),
            modelName: try c.decode(String.self, forKey: .modelName),
            ord: try c.decode(Int.self, forKey: .ord),
            type: try c.decode(Int.self, forKey: .type),
            interval: try c.decode(Int.self, forKey: .interval),
            due: try c.decode(Int.self, forKey: .due),
            fieldNames: raw.sorted { $0.value.order < $1.value.order }.map(\.key),
            fields: raw.mapValues(\.value)
        )
    }
}

/// Everything Amadare needs from Anki. `LiveAnki` talks to AnkiConnect; tests use a fake.
public protocol AnkiService: Sendable {
    func deckNames() async throws -> [String]
    func findCards(_ query: String) async throws -> [Int]
    func cardsInfo(_ cardIds: [Int]) async throws -> [CardInfo]
    func newCardsPerDay(deck: String) async throws -> Int
    func answerCard(_ cardId: Int, ease: Int) async throws
    func updateNoteFields(_ noteId: Int, fields: [String: String]) async throws
}

struct AnkiEnvelope<T: Decodable>: Decodable {
    let result: T?
    let error: String?
}

/// For actions whose result Amadare doesn't need (often null).
struct IgnoredResult: Decodable {
    init(from decoder: Decoder) throws {}
}

public struct LiveAnki: AnkiService {
    public static let defaultURL = URL(string: "http://127.0.0.1:8765")!

    let url: URL
    let session: URLSession

    public init(url: URL = LiveAnki.defaultURL, session: URLSession = .shared) {
        self.url = url
        self.session = session
    }

    public func deckNames() async throws -> [String] {
        try await call("deckNames")
    }

    public func findCards(_ query: String) async throws -> [Int] {
        try await call("findCards", ["query": query])
    }

    public func cardsInfo(_ cardIds: [Int]) async throws -> [CardInfo] {
        if cardIds.isEmpty { return [] }
        return try await call("cardsInfo", ["cards": cardIds])
    }

    public func newCardsPerDay(deck: String) async throws -> Int {
        struct Config: Decodable {
            struct New: Decodable { let perDay: Int }
            let new: New
        }
        let config: Config = try await call("getDeckConfig", ["deck": deck])
        return config.new.perDay
    }

    public func answerCard(_ cardId: Int, ease: Int) async throws {
        do {
            try await sendAnswer(cardId, ease: ease)
        } catch AnkiError.api(let message) where message.contains("active GUI card") {
            // Anki's own review screen is showing this card, and AnkiConnect won't answer it
            // until Anki leaves that screen. Switch Anki to its deck list and try once more.
            try? await callIgnoringResult("guiDeckBrowser")
            try await sendAnswer(cardId, ease: ease)
        }
    }

    private func sendAnswer(_ cardId: Int, ease: Int) async throws {
        let accepted: [Bool] = try await call("answerCards", ["answers": [["cardId": cardId, "ease": ease]]])
        if accepted.first != true { throw AnkiError.api("Anki didn't accept the answer for card \(cardId)") }
    }

    public func updateNoteFields(_ noteId: Int, fields: [String: String]) async throws {
        try await callIgnoringResult("updateNoteFields", ["note": ["id": noteId, "fields": fields]])
    }

    /// Makes sure Anki has the `Japanese Vocab` note type: creates it if missing; otherwise adds the
    /// Mnemonic field and shows it on the card backs if an older version lacks them. Safe to call repeatedly.
    public func prepareNoteType() async throws {
        let model = JapaneseVocabNoteType.name
        let field = CardContent.mnemonicField
        let models: [String] = try await call("modelNames")
        guard models.contains(model) else {
            try await callIgnoringResult("createModel", [
                "modelName": model,
                "inOrderFields": JapaneseVocabNoteType.fields,
                "css": JapaneseVocabNoteType.css,
                "cardTemplates": JapaneseVocabNoteType.templates.map { ["Name": $0.name, "Front": $0.front, "Back": $0.back] },
            ])
            return
        }
        let fields: [String] = try await call("modelFieldNames", ["modelName": model])
        if !fields.contains(field) {
            try await callIgnoringResult("modelFieldAdd", ["modelName": model, "fieldName": field])
        }
        let templates: [String: [String: String]] = try await call("modelTemplates", ["modelName": model])
        var updates: [String: [String: String]] = [:]
        for (name, var sides) in templates {
            guard let back = sides["Back"], !back.contains("{{\(field)}}") else { continue }
            sides["Back"] = back + "{{#\(field)}}<div class=mnemonic>{{\(field)}}</div>{{/\(field)}}"
            updates[name] = sides
        }
        if !updates.isEmpty {
            try await callIgnoringResult("updateModelTemplates", ["model": ["name": model, "templates": updates]])
        }
    }

    /// For actions whose result is null or unused: only AnkiConnect's `error` matters.
    func callIgnoringResult(_ action: String, _ params: [String: Any] = [:]) async throws {
        let envelope: AnkiEnvelope<IgnoredResult>
        do {
            envelope = try JSONDecoder().decode(AnkiEnvelope<IgnoredResult>.self, from: try await send(action, params))
        } catch let error as AnkiError {
            throw error
        } catch {
            throw AnkiError.badResponse
        }
        if let error = envelope.error { throw AnkiError.api(error) }
    }

    func call<T: Decodable>(_ action: String, _ params: [String: Any] = [:]) async throws -> T {
        try Self.decodeResult(try await send(action, params))
    }

    private func send(_ action: String, _ params: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["action": action, "version": 6, "params": params])
        do {
            return try await session.data(for: request).0
        } catch is URLError {
            throw AnkiError.notRunning
        }
    }

    static func decodeResult<T: Decodable>(_ data: Data) throws -> T {
        let envelope: AnkiEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(AnkiEnvelope<T>.self, from: data)
        } catch {
            throw AnkiError.badResponse
        }
        if let error = envelope.error { throw AnkiError.api(error) }
        guard let result = envelope.result else { throw AnkiError.badResponse }
        return result
    }
}
