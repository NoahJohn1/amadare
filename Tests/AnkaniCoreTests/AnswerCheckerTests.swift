import Testing
@testable import AnkaniCore

@Test func exactIgnoresCasePunctuationAndWidth() {
    #expect(AnswerChecker.check("Diary!", against: "Diary, Journal", kind: .meaning) == .exact)
    #expect(AnswerChecker.check("  journal ", against: "Diary, Journal", kind: .meaning) == .exact)
    #expect(AnswerChecker.check("ＤＩＡＲＹ", against: "Diary, Journal", kind: .meaning) == .exact)
    #expect(AnswerChecker.check("diary journal", against: "Diary, Journal", kind: .meaning) == .exact)
}

@Test func splitsAndStripsParentheses() {
    #expect(AnswerChecker.acceptedAnswers(from: "run (verb); dash/sprint") ==
            ["run (verb); dash/sprint", "run ; dash/sprint", "run (verb)", "run", "dash", "sprint"])
    #expect(AnswerChecker.check("run", against: "run (verb)", kind: .plain) == .exact)
    #expect(AnswerChecker.check("to watch", against: "to see\nto watch", kind: .plain) == .exact)
}

@Test func nearMissWithinTolerance() {
    #expect(AnswerChecker.check("jornal", against: "Diary, Journal", kind: .meaning) == .nearMiss(expected: "Journal"))
    #expect(AnswerChecker.check("togther", against: "Together", kind: .meaning) == .nearMiss(expected: "Together"))
}

@Test func wrongOutsideTolerance() {
    #expect(AnswerChecker.check("gim", against: "gym", kind: .meaning) == .wrong)    // n = 3 → 0 typos
    #expect(AnswerChecker.check("yaer", against: "Year", kind: .meaning) == .wrong)  // distance 2 > 1
    #expect(AnswerChecker.check("evening", against: "this evening, tonight", kind: .meaning) == .wrong)
    #expect(AnswerChecker.check("", against: "gym", kind: .meaning) == .wrong)
}

@Test func readingsAreStrictAndFoldKatakana() {
    #expect(AnswerChecker.check("にっき", against: "にっき", kind: .reading) == .exact)
    #expect(AnswerChecker.check("ニッキ", against: "にっき", kind: .reading) == .exact)
    #expect(AnswerChecker.check("にき", against: "にっき", kind: .reading) == .wrong)
    #expect(AnswerChecker.check("こんばんわ", against: "こんばんは", kind: .reading) == .wrong)
}

@Test(arguments: zip([1, 3, 4, 5, 6, 7, 8, 14, 15, 21], [0, 0, 1, 1, 2, 2, 2, 3, 3, 4]))
func allowedDistance(length: Int, expected: Int) {
    #expect(AnswerChecker.allowedDistance(forLength: length) == expected)
}

@Test func levenshteinDistance() {
    #expect(AnswerChecker.levenshtein("kitten", "sitting") == 3)
    #expect(AnswerChecker.levenshtein("", "abc") == 3)
    #expect(AnswerChecker.levenshtein("日記", "日記") == 0)
}
