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

    public init(id: Int, prompt: String, answer: String, notes: String, kind: QuestionKind, stage: Stage) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.notes = notes
        self.kind = kind
        self.stage = stage
    }
}

public enum CardContent {
    public static let japaneseVocabModel = "Japanese Vocab"

    /// Builds the reviewable form of a card, or nil if it can't be type-checked.
    public static func reviewCard(from info: CardInfo) -> ReviewCard? {
        let prompt: String
        let answer: String
        let notes: String
        let kind: QuestionKind
        if info.modelName == japaneseVocabModel {
            // Template order in the note type: 0 = Meaning, 1 = Reading.
            kind = info.ord == 1 ? .reading : .meaning
            prompt = text(info, "Word")
            answer = text(info, kind == .reading ? "Reading" : "Meaning")
            notes = text(info, "Notes")
        } else {
            guard info.fieldNames.count >= 2 else { return nil }
            kind = .plain
            prompt = text(info, info.fieldNames[0])
            answer = text(info, info.fieldNames[1])
            notes = ""
        }
        guard !prompt.isEmpty, !answer.isEmpty else { return nil }
        return ReviewCard(id: info.cardId, prompt: prompt, answer: answer, notes: notes, kind: kind,
                          stage: Stage(interval: info.interval))
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
