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
    /// Each kanji run is then split so every kanji gets its own reading (未来 → 未(み) 来(らい)) using
    /// `KanjiReadings`; runs that can't be split exactly (今日, 大人) keep one reading.
    /// If the kana in the word doesn't appear in the reading, the whole word gets the whole reading.
    /// QuickActions/furigana.js does the same for the Anki Quick Actions; keep the two in step.
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
        return runs.flatMap { run -> [RubySegment] in
            guard run.isKanji else { return [RubySegment(text: run.text)] }
            group += 1
            let ruby = target.substring(with: match.range(at: group))
            return split(run: run.text, reading: ruby) ?? [RubySegment(text: run.text, ruby: ruby)]
        }
    }

    /// One segment per kanji, or nil if the run's reading can't be split exactly into readings of its kanji.
    static func split(run: String, reading: String) -> [RubySegment]? {
        let kanji = Array(run)
        guard kanji.count > 1 else { return nil }
        let reading = Array(reading)
        var pieces = [String](repeating: "", count: kanji.count)

        func walk(_ i: Int, _ at: Int) -> Bool {
            if i == kanji.count { return at == reading.count }
            let lookup = kanji[i] == "々" && i > 0 ? kanji[i - 1] : kanji[i]
            for base in KanjiReadings.table[lookup] ?? [] {
                for form in forms(of: base, first: i == 0, last: i == kanji.count - 1) {
                    let form = Array(form)
                    guard at + form.count <= reading.count, Array(reading[at..<at + form.count]) == form else { continue }
                    pieces[i] = String(form)
                    if walk(i + 1, at + form.count) { return true }
                }
            }
            return false
        }
        guard walk(0, 0) else { return nil }
        return zip(kanji, pieces).map { RubySegment(text: String($0), ruby: $1) }
    }

    private static let voiced: [Character: String] = [
        "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご", "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
        "た": "だ", "ち": "ぢじ", "つ": "づず", "て": "で", "と": "ど", "は": "ばぱ", "ひ": "びぴ", "ふ": "ぶぷ", "へ": "べぺ", "ほ": "ぼぽ",
    ]

    /// The ways a kanji's reading can be written inside a compound: as is, voiced when it isn't first
    /// (時々 → ときどき), or ending in っ before another kanji (学校 → がっこう).
    private static func forms(of reading: String, first: Bool, last: Bool) -> [String] {
        var forms = [reading]
        if !first, let head = reading.first {
            forms += (voiced[head] ?? "").map { String($0) + reading.dropFirst() }
        }
        if !last {
            forms += forms.filter { $0.count > 1 && "つくちき".contains($0.last!) }.map { $0.dropLast() + "っ" }
        }
        return forms
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
