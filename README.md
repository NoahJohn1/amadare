# Ankani

WaniKani-style reviews for your Anki decks, as a native Mac app.

Ankani is a front end for [Anki](https://apps.ankiweb.net). It reads your cards through the
[AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on, has you **type** every answer the way
WaniKani does, and sends each result back to Anki. Anki's scheduler stays in charge, so your
decks stay in sync with Anki everywhere else you use it.

The name is Anki + WaniKani. *Kani* is 蟹, "crab", which is the app's mark.

## What it does

- **Typed answers, checked for you.** Meanings forgive case, punctuation and small typos. Readings are strict.
- **Meaning and Reading cards.** For `Japanese Vocab` notes (Word, Meaning, Reading, Notes), each word is asked
  both ways, and what you type on Reading cards turns into hiragana as you go (`nikki` → にっき).
- **WaniKani stages.** Apprentice, Guru, Master, Enlightened and Burned, worked out from Anki's intervals.
- **Second chances.** After a wrong answer, **Retry** puts the card back without telling Anki, and **Mark correct**
  counts it as right.
- **Furigana and mnemonics.** After answering, the reading appears above the kanji, and you can write a mnemonic
  that's saved to the note in Anki.
- **Liquid Glass.** Glass panels over a frosted window and a huge, blurred copy of the word you're studying.

## Requirements

- macOS 26 or later, with Xcode 26+ to build
- Anki with the AnkiConnect add-on (code `2055492159`), running while you review

## Build and install

```bash
scripts/build-app.sh
```

This builds a release copy and installs `~/Applications/Ankani.app`. Builds live in `~/Library/Caches/Ankani`,
because codesign rejects the attributes iCloud Drive adds to files inside `~/Documents`.

Run the tests with:

```bash
swift test --scratch-path ~/Library/Caches/Ankani/build
```

## Testing with your own deck

`scripts/reset-test-deck.sh [deck]` makes every card in a deck (default `Inbox`) due today, so you can review the
same cards again.
