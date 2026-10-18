import Foundation

/// A run of a word, with the reading to show above it when it's kanji.
public struct RubySegment: Sendable, Equatable {
    public let text: String
    public let ruby: String?

    public init(text: String, ruby: String? = nil) {
        self.text = text
        self.ruby = ruby
    }
}

public enum Furigana {
    /// Splits `word` into kanji and kana runs and lines the reading up with the kanji runs,
    /// so okurigana isn't covered: 行きました + いきました → 行(い) きました.
    /// If the kana in the word doesn't appear in the reading, the whole word gets the whole reading.
    public static func segments(word: String, reading: String) -> [RubySegment] {
        let reading = toHiragana(firstReading(reading))
        guard !reading.isEmpty, word.contains(where: isKanji) else { return [RubySegment(text: word)] }

        var runs: [(text: String, isKanji: Bool)] = []
        for character in word {
            let kanji = isKanji(character)
            if let last = runs.last, last.isKanji == kanji {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append((String(character), kanji))
            }
        }

        let pattern = "^" + runs.map { $0.isKanji ? "(.+?)" : NSRegularExpression.escapedPattern(for: toHiragana($0.text)) }
            .joined() + "$"
        let target = reading as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reading, range: NSRange(location: 0, length: target.length)) else {
            return [RubySegment(text: word, ruby: reading)]
        }
        var group = 0
        return runs.map { run in
            guard run.isKanji else { return RubySegment(text: run.text) }
            group += 1
            return RubySegment(text: run.text, ruby: target.substring(with: match.range(at: group)))
        }
    }

    static func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) || $0.value == 0x3005
        }
    }

    private static func firstReading(_ reading: String) -> String {
        reading.split(whereSeparator: { ",、;/\n".contains($0) }).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    private static func toHiragana(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map {
            (0x30A1...0x30F6).contains($0.value) ? Unicode.Scalar($0.value - 0x60)! : $0
        }))
    }
}
