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
