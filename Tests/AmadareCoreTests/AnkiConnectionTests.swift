import Foundation
import Testing
@testable import AmadareCore

@Test func readsARemoteConnection() throws {
    let json = #"{"url":"https://nimbasa.example.ts.net","apiKey":"secret"}"#
    let connection = try #require(AnkiConnection.remote(fromJSON: Data(json.utf8)))
    #expect(connection.url == URL(string: "https://nimbasa.example.ts.net"))
    #expect(connection.apiKey == "secret")
    #expect(connection.isRemote)
    #expect(connection.hostName == "nimbasa")
}

@Test func aMalformedConnectionFileIsIgnored() {
    #expect(AnkiConnection.remote(fromJSON: Data("not json".utf8)) == nil)
    #expect(AnkiConnection.remote(fromJSON: Data(#"{"apiKey":"secret"}"#.utf8)) == nil)
    #expect(AnkiConnection.remote(fromJSON: Data(#"{"url":""}"#.utf8)) == nil)
}

@Test func aConnectionWithoutAKeyStillWorks() throws {
    let connection = try #require(AnkiConnection.remote(fromJSON: Data(#"{"url":"https://a.ts.net"}"#.utf8)))
    #expect(connection.apiKey == nil)
}

@Test func localConnectionUsesTheDefaultURL() {
    let connection = AnkiConnection.local(apiKey: "k")
    #expect(connection.url == LiveAnki.defaultURL)
    #expect(connection.apiKey == "k")
    #expect(!connection.isRemote)
}
