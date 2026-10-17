/// WaniKani-style SRS stage derived from Anki's review interval.
public enum Stage: Int, CaseIterable, Comparable, Sendable {
    case apprentice, guru, master, enlightened, burned

    /// `interval` is AnkiConnect's `cardsInfo` interval: days when positive,
    /// seconds of a learning step when negative, 0 for new cards.
    public init(interval: Int) {
        switch interval {
        case ..<7: self = .apprentice
        case 7..<30: self = .guru
        case 30..<90: self = .master
        case 90..<180: self = .enlightened
        default: self = .burned
        }
    }

    public var name: String {
        switch self {
        case .apprentice: "Apprentice"
        case .guru: "Guru"
        case .master: "Master"
        case .enlightened: "Enlightened"
        case .burned: "Burned"
        }
    }

    public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
}
