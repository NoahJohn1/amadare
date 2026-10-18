import Foundation

public enum Verdict: Sendable, Equatable {
    case exact
    /// Correct with a small typo; `expected` is the accepted answer it was close to.
    case nearMiss(expected: String)
    case wrong
    /// Checked as wrong, then the user said it was right.
    case markedCorrect

    public var isCorrect: Bool { self != .wrong }
}

public enum AnswerChecker {
    public static func check(_ typed: String, against back: String, kind: QuestionKind) -> Verdict {
        let isReading = kind == .reading
        let given = normalize(typed, foldKatakana: isReading)
        guard !given.isEmpty else { return .wrong }
        let candidates = acceptedAnswers(from: back)
            .map { (raw: $0, normalized: normalize($0, foldKatakana: isReading)) }
            .filter { !$0.normalized.isEmpty }
        if candidates.contains(where: { $0.normalized == given }) { return .exact }
        if isReading { return .wrong }
        for candidate in candidates
        where levenshtein(given, candidate.normalized) <= allowedDistance(forLength: candidate.normalized.count) {
            return .nearMiss(expected: candidate.raw)
        }
        return .wrong
    }

    /// NFKC, lowercase, no punctuation or symbols, single spaces. Readings also fold katakana to hiragana.
    public static func normalize(_ s: String, foldKatakana: Bool = false) -> String {
        var out = String.UnicodeScalarView()
        for scalar in s.precomposedStringWithCompatibilityMapping.lowercased().unicodeScalars {
            if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                continue
            }
            if foldKatakana, (0x30A1...0x30F6).contains(scalar.value), let hiragana = Unicode.Scalar(scalar.value - 0x60) {
                out.append(hiragana)
            } else {
                out.append(scalar)
            }
        }
        return String(out).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The whole back, each part split on , ; / and line breaks, and each of those without (parentheses).
    public static func acceptedAnswers(from back: String) -> [String] {
        let parts = [back] + back.split(whereSeparator: { ",;/\n".contains($0) }).map(String.init)
        var result: [String] = []
        for part in parts {
            for variant in [part, part.replacing(/\([^)]*\)|（[^）]*）/, with: "")] {
                let trimmed = variant.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !result.contains(trimmed) { result.append(trimmed) }
            }
        }
        return result
    }

    public static func allowedDistance(forLength n: Int) -> Int {
        switch n {
        case ...3: 0
        case ...5: 1
        case ...7: 2
        default: 2 + (n - 7) / 7
        }
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1,
                                 previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
