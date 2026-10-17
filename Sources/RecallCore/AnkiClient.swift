import Foundation

public enum AnkiError: Error, Equatable, Sendable {
    /// Nothing answered on the AnkiConnect port: Anki is closed or the add-on is missing.
    case notRunning
    /// AnkiConnect answered with a non-null `error`.
    case api(String)
    case badResponse
}

/// The parts of AnkiConnect's `cardsInfo` that Recall uses.
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

/// Everything Recall needs from Anki. `LiveAnki` talks to AnkiConnect; tests use a fake.
public protocol AnkiService: Sendable {
    func deckNames() async throws -> [String]
    func findCards(_ query: String) async throws -> [Int]
    func cardsInfo(_ cardIds: [Int]) async throws -> [CardInfo]
    func newCardsPerDay(deck: String) async throws -> Int
    func answerCard(_ cardId: Int, ease: Int) async throws
}

struct AnkiEnvelope<T: Decodable>: Decodable {
    let result: T?
    let error: String?
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
        let accepted: [Bool] = try await call("answerCards", ["answers": [["cardId": cardId, "ease": ease]]])
        if accepted.first != true { throw AnkiError.api("Anki didn't accept the answer for card \(cardId)") }
    }

    func call<T: Decodable>(_ action: String, _ params: [String: Any] = [:]) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["action": action, "version": 6, "params": params])
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch is URLError {
            throw AnkiError.notRunning
        }
        return try Self.decodeResult(data)
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
