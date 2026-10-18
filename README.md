# Amadare

WaniKani-style reviews for your Anki decks, as a native Mac app.

Amadare is a front end for [Anki](https://apps.ankiweb.net). It reads your cards through the
[AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on, has you **type** every answer the way
WaniKani does, and sends each result back to Anki. Anki's scheduler stays in charge, so your
decks stay in sync with Anki everywhere else you use it.

**Amadare** (雨垂れ) is rain dripping from the eaves, from the proverb 雨垂れ石を穿つ, "dripping rain wears
through stone":

> *Storms pass, but a steady drip cuts through stone.*

Consistency trumps intensity. The mark is 雫, a single drop.

## What it does

- **Typed answers, checked for you.** Meanings forgive case, punctuation and small typos. Readings are strict.
- **Meaning and Reading cards.** For `Japanese Vocab` notes (Word, Meaning, Reading, Notes), each word is asked
  both ways, and what you type on Reading cards turns into hiragana as you go (`nikki` → にっき).
- **WaniKani stages.** Apprentice, Guru, Master, Enlightened and Burned, worked out from Anki's intervals.
- **Second chances.** After a wrong answer, **Retry** puts the card back without telling Anki, and **Mark correct**
  counts it as right.
- **Furigana and mnemonics.** After answering, the reading appears above the kanji, and you can write a mnemonic
  that's saved to the note in Anki.
- **A rainy window.** Liquid Glass panels over frosted glass beaded with water, with light rain falling behind
  and a dim, brush-style copy of the word you're studying.

## Requirements

- macOS 26 or later, with Xcode 26+ to build
- Anki with the AnkiConnect add-on (code `2055492159`), running while you review

## Build and install

```bash
scripts/build-app.sh
```

This builds a release copy and installs `~/Applications/Amadare.app`. Builds live in `~/Library/Caches/Amadare`,
because codesign rejects the attributes iCloud Drive adds to files inside `~/Documents`.

Run the tests with:

```bash
swift test --scratch-path ~/Library/Caches/Amadare/build
```

## Quick Actions

`QuickActions/` holds three macOS Quick Actions for adding and looking up cards from any app. They talk to
AnkiConnect too, so Anki needs to be open.

| Quick Action | Shortcut | What it does |
|---|---|---|
| Add to Anki | ⌃⌘A, or right-click → Services | Adds the selected word as a `Japanese Vocab` note in `Inbox`, with fields to fill in first. Furigana is generated from Word and Reading. |
| Look Up in Anki | ⌃⌘L, or right-click → Services | Searches your cards for the selected text: a list of matches, details, and editing. |
| Search Anki | ⌥⌘L | The same lookup with an empty search box, which lists every note. |

Install or update them with:

```bash
scripts/install-quick-actions.sh
```

This copies the scripts to `~/Library/Application Support/AnkiQuickAdd`, the workflows to `~/Library/Services`,
and sets the shortcuts. Edit the files in `QuickActions/`, then run it again.

- `add-to-anki.js`, `lookup-in-anki.js`: JavaScript for Automation (JXA) scripts that open the native windows.
- `lookup.html`: the lookup window's interface, shown in a web view.
- `furigana.js`: turns a word and its reading into Anki furigana (`食[た]べ 物[もの]`); used by both.
- `workflows/`: the Automator Quick Actions, each a "Run Shell Script" step that runs one of the scripts.

## Testing with your own deck

`scripts/reset-test-deck.sh [deck]` makes every card in a deck (default `Inbox`) due today, so you can review the
same cards again.
