# Amadare

WaniKani-style reviews for your Anki decks, as a native Mac app.

> *Storms pass, but a steady drip cuts through stone.*

Amadare is a front end for [Anki](https://apps.ankiweb.net). It reads your cards through the
[AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on, has you **type** every answer the way
WaniKani does, and sends each result back to Anki. Anki's scheduler stays in charge, so your
decks stay in sync with Anki everywhere else you use it.

## Why "Amadare"

雨垂れ (*amadare*) is the rain that drips from the eaves of a roof. A Japanese proverb,
雨垂れ石を穿つ (*amadare ishi o ugatsu*), says that it wears a hole through stone.

No single drop does anything to the stone. A downpour doesn't either: it runs off and is gone by
morning. But the drip comes back to the same spot every time it rains, and one day there's a hollow in
the stone that wasn't there before.

Learning a language works the same way. A marathon weekend of flashcards feels productive and has
faded by Thursday. Ten minutes a day, every day, is what actually carves the words in. Amadare is built
around that: the reviews waiting for you are the ones Anki scheduled for today, and getting through
them is the whole job.

So on the days you miss more than you get right, or only have time for a handful of cards, that still
counts. Do today's reviews, and come back tomorrow. The drip doesn't need to be strong. It only needs
to keep falling.

**Consistency trumps intensity.**

The app's mark, 雫 (*shizuku*), is a single drop.

## What it does

- **Typed answers, checked for you.** Meanings forgive case, punctuation and small typos. Readings are strict.
- **Meaning and Reading cards.** For `Japanese Vocab` notes, each word is asked both ways, and what you type on
  Reading cards turns into hiragana as you go (`nikki` → にっき).
- **WaniKani stages.** Apprentice, Guru, Master, Enlightened and Burned, worked out from Anki's intervals.
- **Second chances.** After a wrong answer, **Retry** puts the card back without telling Anki, and **Mark correct**
  counts it as right.
- **Furigana and mnemonics.** After answering, the reading appears above the kanji, and you can write a mnemonic
  that's saved to the note in Anki.
- **A rainy window.** Liquid Glass panels over frosted glass beaded with water, with light rain and slow storm
  clouds behind, and a dim, brush-style copy of the word you're studying. In full screen, your wallpaper shows
  through, blurred.

## Getting started

You need macOS 26 or later and Xcode 26 or later.

1. **Get the code.**

   ```bash
   git clone https://github.com/NoahJohn1/amadare.git
   cd amadare
   ```

2. **Install Anki and AnkiConnect.** Download Anki from [apps.ankiweb.net](https://apps.ankiweb.net)
   (or `brew install --cask anki`) and open it once. Then choose **Tools → Add-ons → Get Add-ons…**, enter
   `2055492159`, and restart Anki.

3. **Build and install Amadare.**

   ```bash
   scripts/build-app.sh
   ```

   This installs `~/Applications/Amadare.app`. If the build complains about Xcode, open Xcode once to finish
   its setup.

4. **Optionally, install the Quick Actions** for adding cards from any app (see [Quick Actions](#quick-actions)):

   ```bash
   scripts/install-quick-actions.sh
   ```

5. **Open Anki, then Amadare.** Anki has to be running whenever you review, since Amadare talks to it through
   AnkiConnect. If it isn't, Amadare offers to open it.

   On first launch, Amadare adds the `Japanese Vocab` note type to Anki if it isn't there yet.

### Adding cards

The easiest way is the **Add to Anki** Quick Action: select a word anywhere, press ⌃⌘A, and fill in its meaning
and reading. You can also add notes in Anki itself: choose the **Japanese Vocab** note type and fill in:

| Field | What goes in it |
|---|---|
| Word | The word as written, e.g. 日記 |
| Meaning | One or more meanings, separated by commas: `diary, journal` |
| Reading | The reading in hiragana: にっき. Leave it empty for words written only in kana. |
| Mnemonic | Optional memory aid. You can also add it later while reviewing. |
| Notes | Optional extra notes, shown after you answer |
| Furigana | Leave empty; the Add to Anki Quick Action fills it in |

Each note becomes two cards, a Meaning card and a Reading card. Other note types work too: Amadare asks the first
field and checks your answer against the second.

## Using Amadare

**The dashboard** shows the deck you're studying (switch it with the menu at the top), how many reviews are
waiting, and how many of the deck's cards are at each stage. The count is the cards Anki has due today plus
today's new cards, up to the deck's daily limit for new cards. Press **Return** or click the count to start.

**A review** shows the word, labeled **Meaning** or **Reading**. Type your answer and press Return:

- **Green** means correct. If you were close but made a small typo, the box shakes and shows the exact answer.
- **Red** means wrong, and the correct answer appears underneath. A missed card comes back a few cards later.

Press Return again to move on. Your answer is saved to Anki as you go, and Anki decides when you'll see the card
next. **Wrap up** finishes the cards you've already started and ends the session; a summary shows what you got
right and what you missed.

| Key | When | What it does |
|---|---|---|
| Return | Typing an answer | Check it |
| Return | After answering | Go to the next card |
| ⌘R | After a wrong answer | **Retry**: put the card back in the queue without telling Anki you missed it |
| ⌘Return | After a wrong answer | **Mark correct**: count your answer as right |
| ⌘F | Meaning card, before answering | Show or hide furigana above the kanji for this card |
| ⌘E | After answering | Add or edit the card's mnemonic (⌘S saves, Esc cancels) |
| Esc | During a review | Back to the dashboard (answers you've given are already saved) |

A few more things:

- On Reading cards, type in romaji and it becomes hiragana as you type. `nn` gives ん, so ん followed by な, に,
  ぬ, ね or の takes three n's (`konnnichiha` → こんにちは). A Japanese keyboard works too.
- Right-click the word to copy it.
- If the "couldn't save" banner appears, open Anki and click **Retry**. Nothing is lost.
- With **Reduce Motion** on (System Settings → Accessibility → Display), the rain and clouds hold still.

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
- `furigana.js`: turns a word and its reading into Anki furigana with each reading over its own kanji
  (`未[み]来[らい]`, `食[た]べ 物[もの]`); used by both.
- `kanji-readings.txt`: the readings of the ~3,000 jōyō and jinmeiyō kanji that `furigana.js` (and the app's
  `KanjiReadings.swift`) split compounds with. Regenerate both with `scripts/make-kanji-readings.py kanjidic2.xml.gz`.
- `workflows/`: the Automator Quick Actions, each a "Run Shell Script" step that runs one of the scripts.

## Development

Run the tests with:

```bash
swift test --scratch-path ~/Library/Caches/Amadare/build
```

Builds live in `~/Library/Caches/Amadare` rather than the repo, because codesign rejects the attributes iCloud
Drive adds to files inside `~/Documents`.

`scripts/reset-test-deck.sh [deck]` makes every card in a deck (default `Inbox`) due today, so you can review the
same cards again while testing.

## Credits

Kanji readings for furigana (`QuickActions/kanji-readings.txt`, `Sources/AmadareCore/KanjiReadings.swift`) come
from [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) by the Electronic Dictionary Research and
Development Group, used under [CC BY-SA 4.0](https://www.edrdg.org/edrdg/licence.html); those files are under the
same licence.
