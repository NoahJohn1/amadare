import Testing
@testable import AmadareCore

private func seg(_ text: String, _ ruby: String? = nil) -> RubySegment { RubySegment(text: text, ruby: ruby) }

@Test func eachKanjiGetsItsOwnReading() {
    #expect(Furigana.segments(word: "日記", reading: "にっき") == [seg("日", "にっ"), seg("記", "き")])
    #expect(Furigana.segments(word: "未来", reading: "みらい") == [seg("未", "み"), seg("来", "らい")])
    #expect(Furigana.segments(word: "会社員", reading: "かいしゃいん") == [seg("会", "かい"), seg("社", "しゃ"), seg("員", "いん")])
}

@Test func compoundsAllowVoicingAndSmallTsu() {
    #expect(Furigana.segments(word: "手紙", reading: "てがみ") == [seg("手", "て"), seg("紙", "がみ")])
    #expect(Furigana.segments(word: "学校", reading: "がっこう") == [seg("学", "がっ"), seg("校", "こう")])
    #expect(Furigana.segments(word: "出発", reading: "しゅっぱつ") == [seg("出", "しゅっ"), seg("発", "ぱつ")])
    #expect(Furigana.segments(word: "時々", reading: "ときどき") == [seg("時", "とき"), seg("々", "どき")])
}

@Test func specialReadingsCoverTheWholeRun() {
    #expect(Furigana.segments(word: "今日", reading: "きょう") == [seg("今日", "きょう")])
    #expect(Furigana.segments(word: "大人しい", reading: "おとなしい") == [seg("大人", "おとな"), seg("しい")])
}

@Test func okuriganaGetsNoRuby() {
    #expect(Furigana.segments(word: "行きました", reading: "いきました") == [seg("行", "い"), seg("きました")])
    #expect(Furigana.segments(word: "一気飲みする", reading: "いっきのみする")
            == [seg("一", "いっ"), seg("気", "き"), seg("飲", "の"), seg("みする")])
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
    #expect(Furigana.segments(word: "日記", reading: "にっき, にき") == [seg("日", "にっ"), seg("記", "き")])
    #expect(Furigana.segments(word: "行きました", reading: "イキマシタ") == [seg("行", "い"), seg("きました")])
}
