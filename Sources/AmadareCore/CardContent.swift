import Foundation

public enum QuestionKind: Sendable, Equatable {
    case meaning, reading, plain
}

/// A card ready to review: plain-text prompt and answer plus what kind of question it is.
public struct ReviewCard: Sendable, Equatable, Identifiable {
    public let id: Int
    public let prompt: String
    public let answer: String
    public let notes: String
    public let kind: QuestionKind
    public let stage: Stage
    public let noteId: Int
    /// The word's reading (Japanese Vocab notes only), used for furigana.
    public let reading: String
    public let mnemonic: String
    /// The note field this card's mnemonic is saved to, or nil if its note type has none.
    public let mnemonicField: String?

    public init(id: Int, prompt: String, answer: String, notes: String, kind: QuestionKind, stage: Stage,
                noteId: Int = 0, reading: String = "", mnemonic: String = "", mnemonicField: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.notes = notes
        self.kind = kind
        self.stage = stage
        self.noteId = noteId
        self.reading = reading
        self.mnemonic = mnemonic
        self.mnemonicField = mnemonicField
    }
}

public enum CardContent {
    public static let japaneseVocabModel = "Japanese Vocab"
    /// One mnemonic per note, shared by its cards. Any note type with this field gets mnemonics.
    public static let mnemonicField = "Mnemonic"

    /// Builds the reviewable form of a card, or nil if it can't be type-checked.
    public static func reviewCard(from info: CardInfo) -> ReviewCard? {
        let prompt: String
        let answer: String
        let notes: String
        let kind: QuestionKind
        let reading: String
        if info.modelName == japaneseVocabModel {
            // Template order in the note type: 0 = Meaning, 1 = Reading.
            kind = info.ord == 1 ? .reading : .meaning
            prompt = text(info, "Word")
            answer = text(info, kind == .reading ? "Reading" : "Meaning")
            notes = text(info, "Notes")
            reading = text(info, "Reading")
        } else {
            guard info.fieldNames.count >= 2 else { return nil }
            kind = .plain
            prompt = text(info, info.fieldNames[0])
            answer = text(info, info.fieldNames[1])
            notes = ""
            reading = ""
        }
        // Japanese Vocab always gets one (Amadare adds the field at launch); other types only if they have it.
        let mnemonicField = info.modelName == japaneseVocabModel || info.fieldNames.contains(Self.mnemonicField)
            ? Self.mnemonicField : nil
        guard !prompt.isEmpty, !answer.isEmpty else { return nil }
        return ReviewCard(id: info.cardId, prompt: prompt, answer: answer, notes: notes, kind: kind,
                          stage: Stage(interval: info.interval), noteId: info.noteId, reading: reading,
                          mnemonic: mnemonicField.map { text(info, $0) } ?? "", mnemonicField: mnemonicField)
    }

    private static func text(_ info: CardInfo, _ field: String) -> String {
        plainText(fromHTML: info.fields[field] ?? "")
    }

    /// Anki field HTML → plain text: line breaks kept, tags, images and sounds dropped, entities decoded.
    public static func plainText(fromHTML html: String) -> String {
        var s = html
        s.replace(/\[sound:[^\]]*\]/, with: "")
        s.replace(/<br\s*\/?>/.ignoresCase(), with: "\n")
        s.replace(/<\/(div|p|li|h[1-6])>/.ignoresCase(), with: "\n")
        s.replace(/<[^>]*>/, with: "")
        s = decodeEntities(s)
        return s.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Plain text → field HTML: special characters escaped, line breaks as <br>.
    public static func html(fromPlainText text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    static func decodeEntities(_ s: String) -> String {
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
        return s.replacing(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
            let body = String(match.1)
            if body.hasPrefix("#x"), let v = UInt32(body.dropFirst(2), radix: 16), let u = Unicode.Scalar(v) {
                return String(Character(u))
            }
            if body.hasPrefix("#"), let v = UInt32(body.dropFirst()), let u = Unicode.Scalar(v) {
                return String(Character(u))
            }
            return named[body] ?? String(match.0)
        }
    }
}
