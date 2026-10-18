import Testing
@testable import RecallCore

private func seg(_ text: String, _ ruby: String? = nil) -> RubySegment { RubySegment(text: text, ruby: ruby) }

@Test func rubyCoversAWholeKanjiWord() {
    #expect(Furigana.segments(word: "日記", reading: "にっき") == [seg("日記", "にっき")])
}

@Test func okuriganaGetsNoRuby() {
    #expect(Furigana.segments(word: "行きました", reading: "いきました") == [seg("行", "い"), seg("きました")])
    #expect(Furigana.segments(word: "一気飲みする", reading: "いっきのみする") == [seg("一気飲", "いっきの"), seg("みする")])
    #expect(Furigana.segments(word: "お茶", reading: "おちゃ") == [seg("お"), seg("茶", "ちゃ")])
}

@Test func noRubyWithoutKanjiOrReading() {
    #expect(Furigana.segments(word: "アメフト", reading: "あめふと") == [seg("アメフト")])
    #expect(Furigana.segments(word: "日記", reading: "") == [seg("日記")])
}

@Test func mismatchedReadingCoversWholeWord() {
    #expect(Furigana.segments(word: "見る", reading: "みた") == [seg("見る", "みた")])   // reading lacks る
}

@Test func usesFirstReadingAndFoldsKatakana() {
    #expect(Furigana.segments(word: "日記", reading: "にっき, にき") == [seg("日記", "にっき")])
    #expect(Furigana.segments(word: "行きました", reading: "イキマシタ") == [seg("行", "い"), seg("きました")])
}
