/// The `Japanese Vocab` note type Amadare and its Quick Actions use: one note per word, asked two ways.
/// Amadare creates it in Anki on launch if it's missing. Template order matters: ord 0 is Meaning, ord 1 Reading.
public enum JapaneseVocabNoteType {
    public static let name = CardContent.japaneseVocabModel

    /// `Furigana` isn't shown on the cards; the Add to Anki Quick Action fills it in Anki's
    /// `漢[かん]字[じ]` format for anyone who wants `{{furigana:Furigana}}` in their own templates.
    public static let fields = ["Word", "Meaning", "Reading", CardContent.mnemonicField, "Notes", "Furigana"]

    public static let templates: [(name: String, front: String, back: String)] = [
        ("Meaning",
         "<div class=meaning><div class=kind>Meaning</div><div class=word>{{Word}}</div></div>",
         "<div class=meaning>{{FrontSide}}<hr id=answer><div class=ans>{{Meaning}}</div>" + extras + "</div>"),
        ("Reading",
         "{{#Reading}}<div class=reading><div class=kind>Reading</div><div class=word>{{Word}}</div></div>{{/Reading}}",
         "<div class=reading>{{FrontSide}}<hr id=answer><div class=ans>{{Reading}}</div>" + extras + "</div>"),
    ]

    private static let extras = "{{#Mnemonic}}<div class=mnemonic>{{Mnemonic}}</div>{{/Mnemonic}}"
        + "{{#Notes}}<div class=notes>{{Notes}}</div>{{/Notes}}"

    public static let css = """
        .card { font-family: -apple-system, "Hiragino Sans", sans-serif; text-align: center; font-size: 22px; }
        .kind { font-size: 14px; text-transform: uppercase; letter-spacing: 2px; padding: 6px; border-radius: 6px; }
        .meaning .kind { background: #e8e8e8; color: #333; }
        .reading .kind { background: #333; color: #fff; }
        .word { font-size: 64px; margin: 20px 0; }
        .ans { font-size: 30px; }
        .notes { font-size: 16px; color: #888; margin-top: 12px; }
        .mnemonic { font-size: 17px; margin: 14px auto 0; max-width: 32em; padding: 8px 12px; border-radius: 8px; background: rgba(128,128,128,.12); }
        """
}
