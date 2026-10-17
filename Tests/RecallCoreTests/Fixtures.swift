@testable import RecallCore

func card(
    _ id: Int,
    model: String = "Basic",
    ord: Int = 0,
    fields: KeyValuePairs<String, String> = ["Front": "front", "Back": "back"],
    type: Int = 2,
    interval: Int = 10,
    due: Int = 0
) -> CardInfo {
    CardInfo(
        cardId: id, noteId: id, modelName: model, ord: ord, type: type, interval: interval, due: due,
        fieldNames: fields.map(\.key),
        fields: Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })
    )
}

func vocab(_ id: Int, ord: Int, word: String, meaning: String, reading: String,
           notes: String = "", interval: Int = 0) -> CardInfo {
    card(id, model: "Japanese Vocab", ord: ord,
         fields: ["Word": word, "Meaning": meaning, "Reading": reading, "Notes": notes],
         type: interval == 0 ? 0 : 2, interval: interval)
}

extension CardInfo {
    func with(interval: Int) -> CardInfo {
        CardInfo(cardId: cardId, noteId: noteId, modelName: modelName, ord: ord, type: 2,
                 interval: interval, due: due, fieldNames: fieldNames, fields: fields)
    }
}
