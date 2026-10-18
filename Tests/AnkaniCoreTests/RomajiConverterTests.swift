import Testing
@testable import AnkaniCore

@Test(arguments: zip(
    ["nikki", "konnnichiha", "kyou", "onnna", "hon'ya", "ikimashita", "matte", "ii", "nyuu", "ra-me",
     "chotto", "fa", "みる", "NIKKI", "xtsu"],
    ["にっき", "こんにちは", "きょう", "おんな", "ほんや", "いきました", "まって", "いい", "にゅう", "らーめ",
     "ちょっと", "ふぁ", "みる", "にっき", "っ"]
))
func convertsWhileTyping(romaji: String, kana: String) {
    #expect(RomajiConverter.convert(romaji) == kana)
}

@Test func pendingLettersStayLatinWhileTyping() {
    #expect(RomajiConverter.convert("n") == "n")
    #expect(RomajiConverter.convert("nen") == "ねn")
    #expect(RomajiConverter.convert("nenn") == "ねん")      // nn → ん right away, like a Japanese IME
    #expect(RomajiConverter.convert("nn") == "ん")
    #expect(RomajiConverter.convert("nnn") == "んn")
    #expect(RomajiConverter.convert("nnni") == "んに")
    #expect(RomajiConverter.convert("ky") == "ky")
    #expect(RomajiConverter.convert("sh") == "sh")
    #expect(RomajiConverter.convert("kanj") == "かんj")
}

@Test func finalConvertsTrailingN() {
    #expect(RomajiConverter.convert("nen", final: true) == "ねん")
    #expect(RomajiConverter.convert("nenn", final: true) == "ねん")
    #expect(RomajiConverter.convert("shashin", final: true) == "しゃしん")
    #expect(RomajiConverter.convert("kanji", final: true) == "かんじ")
    #expect(RomajiConverter.convert("ra-men", final: true) == "らーめん")
}

@Test func outputIsStable() {
    for input in ["nikki", "ねn", "こんにちは", "kyou"] {
        let once = RomajiConverter.convert(input)
        #expect(RomajiConverter.convert(once) == once)
    }
}

@Test func detectsLatin() {
    #expect(RomajiConverter.containsLatin("ねn"))
    #expect(!RomajiConverter.containsLatin("ねん"))
    #expect(!RomajiConverter.containsLatin("らーめん"))
}
