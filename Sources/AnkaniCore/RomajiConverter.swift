/// Converts romaji to hiragana as the user types, like WaniKani's reading box.
/// Anything that isn't romaji (kana from a Japanese IME, spaces) passes through unchanged,
/// so the whole field can be re-converted after every keystroke.
public enum RomajiConverter {
    /// - Parameter final: true when submitting: a trailing `n` becomes ん.
    ///   While typing, a trailing `n` stays Latin because it may still become な, に, にゃ….
    public static func convert(_ input: String, final: Bool = false) -> String {
        let chars = Array(input.lowercased())
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if c == "n" {
                guard let next else {
                    out += final ? "ん" : "n"
                    i += 1
                    continue
                }
                if next == "'" {
                    out += "ん"
                    i += 2
                    continue
                }
                if next == "n" {
                    // "nn" → ん right away, like a Japanese IME; "nnni" → んに.
                    out += "ん"
                    i += 2
                    continue
                }
                if !isVowel(next) && next != "y" {
                    out += "ん"
                    i += 1
                    continue
                }
            }
            if let (kana, length) = longestMatch(chars, from: i) {
                out += kana
                i += length
                continue
            }
            if isLatin(c), !isVowel(c), next == c {
                out += "っ"
                i += 1
                continue
            }
            out.append(c)
            i += 1
        }
        return out
    }

    public static func containsLatin(_ s: String) -> Bool {
        s.contains(where: isLatin)
    }

    private static func isVowel(_ c: Character) -> Bool { "aeiou".contains(c) }
    private static func isLatin(_ c: Character) -> Bool { c.isASCII && c.isLetter }

    private static func longestMatch(_ chars: [Character], from i: Int) -> (String, Int)? {
        for length in stride(from: min(4, chars.count - i), through: 1, by: -1) {
            if let kana = table[String(chars[i..<i + length])] { return (kana, length) }
        }
        return nil
    }

    private static let table: [String: String] = {
        let vowels = ["a", "i", "u", "e", "o"]
        var t: [String: String] = ["-": "ー", "ya": "や", "yu": "ゆ", "yo": "よ", "wa": "わ", "wo": "を"]
        for (v, k) in zip(vowels, "あいうえお") { t[v] = String(k) }
        let rows: [(String, String)] = [
            ("k", "かきくけこ"), ("s", "さしすせそ"), ("t", "たちつてと"), ("n", "なにぬねの"), ("h", "はひふへほ"),
            ("m", "まみむめも"), ("r", "らりるれろ"), ("g", "がぎぐげご"), ("z", "ざじずぜぞ"), ("d", "だぢづでど"),
            ("b", "ばびぶべぼ"), ("p", "ぱぴぷぺぽ"),
        ]
        for (consonant, kana) in rows {
            for (v, k) in zip(vowels, kana) { t[consonant + v] = String(k) }
        }
        for (romaji, kana) in [("shi", "し"), ("chi", "ち"), ("tsu", "つ"), ("fu", "ふ"), ("ji", "じ")] {
            t[romaji] = kana
        }
        let palatal: [(String, String)] = [
            ("ky", "き"), ("gy", "ぎ"), ("sh", "し"), ("sy", "し"), ("j", "じ"), ("jy", "じ"), ("zy", "じ"),
            ("ch", "ち"), ("cy", "ち"), ("ty", "ち"), ("dy", "ぢ"), ("ny", "に"), ("hy", "ひ"), ("by", "び"),
            ("py", "ぴ"), ("my", "み"), ("ry", "り"),
        ]
        for (prefix, base) in palatal {
            t[prefix + "a"] = base + "ゃ"
            t[prefix + "u"] = base + "ゅ"
            t[prefix + "o"] = base + "ょ"
        }
        t["she"] = "しぇ"; t["je"] = "じぇ"; t["che"] = "ちぇ"
        t["fa"] = "ふぁ"; t["fi"] = "ふぃ"; t["fe"] = "ふぇ"; t["fo"] = "ふぉ"
        for (v, k) in zip(vowels, "ぁぃぅぇぉ") {
            t["x" + v] = String(k)
            t["l" + v] = String(k)
        }
        for prefix in ["x", "l"] {
            t[prefix + "ya"] = "ゃ"; t[prefix + "yu"] = "ゅ"; t[prefix + "yo"] = "ょ"
            t[prefix + "tsu"] = "っ"; t[prefix + "tu"] = "っ"
        }
        return t
    }()
}
