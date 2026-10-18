import Testing
@testable import AnkaniCore

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
        id: 1, prompt: "日記", answer: "Diary, Journal", notes: "noun", kind: .meaning, stage: .apprentice,
        noteId: 1, reading: "にっき", mnemonic: "", mnemonicField: "Mnemonic"))
}

@Test func vocabReadingCard() {
    let info = vocab(2, ord: 1, word: "日記", meaning: "Diary, Journal", reading: "にっき", interval: 45)
    #expect(CardContent.reviewCard(from: info) == ReviewCard(
        id: 2, prompt: "日記", answer: "にっき", notes: "", kind: .reading, stage: .master,
        noteId: 2, reading: "にっき", mnemonic: "", mnemonicField: "Mnemonic"))
}

@Test func basicCardUsesFirstTwoFields() {
    let info = card(3, fields: ["Front": "ジム", "Back": "gym"])
    #expect(CardContent.reviewCard(from: info) == ReviewCard(
        id: 3, prompt: "ジム", answer: "gym", notes: "", kind: .plain, stage: .guru, noteId: 3))
}

@Test func untypeableCardsAreSkipped() {
    #expect(CardContent.reviewCard(from: card(4, fields: ["Front": "<img src=a.png>", "Back": "cat"])) == nil)
    #expect(CardContent.reviewCard(from: card(5, fields: ["Front": "cat", "Back": "[sound:cat.mp3]"])) == nil)
    #expect(CardContent.reviewCard(from: card(6, model: "Solo", fields: ["Text": "only one field"])) == nil)
    #expect(CardContent.reviewCard(from: vocab(7, ord: 1, word: "ジム", meaning: "gym", reading: "")) == nil)
}

@Test func mnemonicFieldsAreRead() {
    // One mnemonic per word, shared by its Meaning and Reading cards.
    for ord in [0, 1] {
        let vocabCard = card(8, model: "Japanese Vocab", ord: ord, fields: [
            "Word": "日記", "Meaning": "Diary", "Reading": "にっき", "Mnemonic": "<b>nick</b>'s key", "Notes": "",
        ])
        #expect(CardContent.reviewCard(from: vocabCard)?.mnemonic == "nick's key")
        #expect(CardContent.reviewCard(from: vocabCard)?.mnemonicField == "Mnemonic")
    }
    let basic = card(9, fields: ["Front": "cat", "Back": "neko", "Mnemonic": "nyan"])
    #expect(CardContent.reviewCard(from: basic)?.mnemonicField == "Mnemonic")
    #expect(CardContent.reviewCard(from: basic)?.mnemonic == "nyan")
    #expect(CardContent.reviewCard(from: card(10))?.mnemonicField == nil)
}

@Test func plainTextBecomesFieldHTML() {
    #expect(CardContent.html(fromPlainText: "a & b <c>\nd") == "a &amp; b &lt;c&gt;<br>d")
}
