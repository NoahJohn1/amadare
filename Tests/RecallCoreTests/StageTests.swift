import Testing
@testable import RecallCore

@Test(arguments: zip(
    [-600, 0, 6, 7, 29, 30, 89, 90, 179, 180, 900],
    [Stage.apprentice, .apprentice, .apprentice, .guru, .guru, .master, .master,
     .enlightened, .enlightened, .burned, .burned]
))
func stageFromInterval(interval: Int, expected: Stage) {
    #expect(Stage(interval: interval) == expected)
}

@Test func stagesAreOrderedAndNamed() {
    #expect(Stage.apprentice < .guru && Stage.enlightened < .burned)
    #expect(Stage.allCases.map(\.name) == ["Apprentice", "Guru", "Master", "Enlightened", "Burned"])
}
