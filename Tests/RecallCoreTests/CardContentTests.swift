import Testing
@testable import RecallCore

@Test(arguments: zip(
    ["Diary<br>Journal", "<div>to see</div><div>to watch</div>", "<b>run</b> &amp; jump&nbsp;!",
     "cat <img src=\"a.jpg\">[sound:a.mp3]", "&#26085;&#x8A18;", "  <BR/>gym  "],
    ["Diary\nJournal", "to see\nto watch", "run & jump !", "cat", "日記", "gym"]
))
func htmlToPlainText(html: String, expected: String) {
    #expect(CardContent.plainText(fromHTML: html) == expected)
}

@Test func vocabMeaningCard() {
    let info = vocab(1, ord: 0, word: "日記", meaning: "Diary, Journal", reading: "にっき", notes: "<i>noun</i>")
    #expect(CardContent.reviewCard(from: info) == ReviewCard(
        id: 1, prompt: "日記", answer: "Diary, Journal", notes: "noun", kind: .meaning, stage: .apprentice))
}

@Test func vocabReadingCard() {
    let info = vocab(2, ord: 1, word: "日記", meaning: "Diary, Journal", reading: "にっき", interval: 45)
    #expect(CardContent.reviewCard(from: info) == ReviewCard(
        id: 2, prompt: "日記", answer: "にっき", notes: "", kind: .reading, stage: .master))
}

@Test func basicCardUsesFirstTwoFields() {
    let info = card(3, fields: ["Front": "ジム", "Back": "gym"])
    #expect(CardContent.reviewCard(from: info) == ReviewCard(
        id: 3, prompt: "ジム", answer: "gym", notes: "", kind: .plain, stage: .guru))
}

@Test func untypeableCardsAreSkipped() {
    #expect(CardContent.reviewCard(from: card(4, fields: ["Front": "<img src=a.png>", "Back": "cat"])) == nil)
    #expect(CardContent.reviewCard(from: card(5, fields: ["Front": "cat", "Back": "[sound:cat.mp3]"])) == nil)
    #expect(CardContent.reviewCard(from: card(6, model: "Solo", fields: ["Text": "only one field"])) == nil)
    #expect(CardContent.reviewCard(from: vocab(7, ord: 1, word: "ジム", meaning: "gym", reading: "")) == nil)
}
