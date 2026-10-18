import Foundation
import Testing
@testable import RecallCore

@Test func decodesCardsInfoWithFieldOrder() throws {
    let json = #"""
    {"result":[{"cardId":5,"note":9,"modelName":"Japanese Vocab","ord":1,"type":0,"interval":0,"due":3,
      "queue":0,"fieldOrder":0,"fields":{"Reading":{"value":"にっき","order":2},"Word":{"value":"日記","order":0},
      "Meaning":{"value":"Diary","order":1},"Notes":{"value":"","order":3}}}],"error":null}
    """#
    let cards: [CardInfo] = try LiveAnki.decodeResult(Data(json.utf8))
    #expect(cards == [CardInfo(
        cardId: 5, noteId: 9, modelName: "Japanese Vocab", ord: 1, type: 0, interval: 0, due: 3,
        fieldNames: ["Word", "Meaning", "Reading", "Notes"],
        fields: ["Word": "日記", "Meaning": "Diary", "Reading": "にっき", "Notes": ""]
    )])
}

@Test func apiErrorSurfaces() {
    #expect(throws: AnkiError.api("deck was not found")) {
        let _: [Int] = try LiveAnki.decodeResult(Data(#"{"result":null,"error":"deck was not found"}"#.utf8))
    }
}

@Test func garbageIsBadResponse() {
    #expect(throws: AnkiError.badResponse) {
        let _: [Int] = try LiveAnki.decodeResult(Data("not json".utf8))
    }
}

@Test func connectionRefusedIsNotRunning() async {
    // Port 9 (discard) has no listener, so the connection is refused immediately.
    let anki = LiveAnki(url: URL(string: "http://127.0.0.1:9")!)
    await #expect(throws: AnkiError.notRunning) { _ = try await anki.deckNames() }
}

/// Serves queued AnkiConnect responses and records which actions were requested.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String] = []
    nonisolated(unsafe) static var actions: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let action = json["action"] as? String {
            Self.actions.append(action)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responses.removeFirst().utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// These share StubURLProtocol's static queue, so they must not run in parallel.
@Suite(.serialized)
struct StubbedAnkiTests {
    @Test func answerLeavesAnkisReviewerAndRetries() async throws {
        StubURLProtocol.actions = []
        StubURLProtocol.responses = [
            #"{"result":null,"error":"Use reviewer.answer for the active GUI card."}"#,
            #"{"result":null,"error":null}"#,
            #"{"result":[true],"error":null}"#,
        ]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        try await LiveAnki(session: URLSession(configuration: configuration)).answerCard(1, ease: 3)
        #expect(StubURLProtocol.actions == ["answerCards", "guiDeckBrowser", "answerCards"])
    }

    @Test func updateNoteFieldsAcceptsANullResult() async throws {
        StubURLProtocol.actions = []
        StubURLProtocol.responses = [#"{"result":null,"error":null}"#]
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        try await LiveAnki(session: URLSession(configuration: configuration))
            .updateNoteFields(9, fields: ["Meaning Mnemonic": "sun + words"])
        #expect(StubURLProtocol.actions == ["updateNoteFields"])
    }
}
