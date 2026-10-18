# Recall — WaniKani-style reviews for Anki decks

**Date:** 2026-10-17
**Status:** Approved

## Goal

A native macOS app for reviewing Anki decks with a WaniKani-style interface: you see a card's front in a big colored band, type the answer, and get instant right/wrong feedback. Anki stays the single source of truth for cards and scheduling; Recall is a front end that reads cards from Anki and reports answers back.

## Decisions

| Question | Decision |
|---|---|
| How you answer | Always type the answer; the app checks it (WaniKani-style). No self-grading. |
| Scheduling | Anki's scheduler decides when cards are due. Recall shows WaniKani-style stages derived from Anki's intervals. |
| New cards | Reviews only — no separate Lessons. New cards appear in the review queue. |
| Talking to Anki | Through the AnkiConnect add-on (`http://127.0.0.1:8765`, API version 6). Anki must be running. |
| Platform | Native SwiftUI app, macOS 26+ (Liquid Glass), built with Swift Package Manager into `Recall.app`. |
| Look | Liquid Glass on a dark ink backdrop showing a huge blurred copy of the current word; prompt, answer box, pills and stage tiles are glass. Japanese text in the system font (Hiragino Sans). |

## Screens

### Dashboard

- **Deck picker** listing Anki's decks. The last chosen deck is remembered (UserDefaults).
- **Reviews count**: due cards + new cards still available today (see *Building the queue*).
- **Start Reviews** button (also Return). Disabled when the count is 0.
- **Stage bar**: counts of the deck's cards in each stage — Apprentice, Guru, Master, Enlightened, Burned — shown as WaniKani-style colored blocks. Suspended cards are excluded.
- **Skipped note**: if some due cards can't be type-checked (see *Card content*), a small line says how many were left out.
- **Anki not running**: instead of the above, a message "Anki isn't open" with an **Open Anki** button that launches Anki and retries the connection until it answers (up to ~20 s), plus a manual **Retry** button.

The dashboard refreshes when it appears and when the app becomes active.

### Review session

- **Header**: back-to-dashboard button, progress (`answered / total`), and percent correct this session.
- **Prompt band**: full-width purple band (the same for every card) with the card's front in large white type; long fronts shrink and wrap. Japanese Vocab cards get a strip under the band naming the question kind (see *Card content*). Light and dark mode supported.
- **Answer box**: one text field below the band, focused automatically. macOS input methods (e.g. Japanese IME) work as normal.
- **Return** with a non-empty answer checks it:
  - **Correct** → box turns green; if it was a near-miss, the box shakes and a "Close enough" note shows the expected answer.
  - **Wrong** → box turns red and the full back of the card is shown under the box.
  - The answer is locked; **Return** again advances to the next card. Empty answers are ignored (no penalty).
- **Stage badge**: after an answer, if the card's stage changed, a small badge shows it (e.g. "↑ Guru", "↓ Apprentice").
- **Missed cards** are re-queued 3–6 cards later in the same session (or at the end if fewer remain) until answered correctly.
- **Wrap up** button: stops pulling new cards from the queue; finishes only cards already seen-and-missed, then ends.
- **Esc** / back button returns to the dashboard. Answers already submitted are already saved in Anki, so no confirmation is needed.
- **Session summary** when the queue is empty: number reviewed, percent correct, and lists of correct/incorrect fronts. A **Done** button returns to the dashboard.

## How it maps onto Anki

### Building the queue

For the selected deck `D` (including subdecks, as Anki does):

1. **Due cards**: `findCards` with `deck:"D" is:due -is:suspended -is:buried` (includes learning cards that are due now).
2. **New cards**: new-cards-per-day limit from `getDeckConfig` (`new.perDay`) minus cards first studied today (`findCards` `deck:"D" introduced:1`), floored at 0. Take that many from `deck:"D" is:new -is:suspended -is:buried`, ordered by Anki's new-card position (`due` field from `cardsInfo`).
3. Fetch `cardsInfo` for all of them; drop cards that can't be type-checked.
4. Shuffle the combined list.

### Grading

- Correct (including near-miss) → `answerCards` with ease **3 (Good)**.
- Wrong → `answerCards` with ease **1 (Again)**.
- Every answer is sent immediately, including answers to re-asked missed cards. This matches what Anki itself would record if you studied in Anki (Again puts the card into relearning; the later correct answer advances it).
- If sending fails, the session pauses with an error banner and a **Retry** button; the answer is not lost.

### Stages

Derived from the card's current interval (from `cardsInfo`; negative values are learning steps in seconds and count as under a day):

| Stage | Interval |
|---|---|
| Apprentice | new, learning, or < 7 days |
| Guru | 7–29 days |
| Master | 30–89 days |
| Enlightened | 90–179 days |
| Burned | ≥ 180 days |

After each answer, Recall re-reads that card's `cardsInfo` to get the new interval and computes the new stage for the badge.

### Card content

- **Japanese Vocab notes** (note type with fields Word, Meaning, Reading, Notes and card templates *Meaning* and *Reading*): the prompt is Word, and the card's template decides the question kind (AnkiConnect reports the template's position as `ord`: 0 = Meaning, 1 = Reading):
  - **Meaning card** → answer is the Meaning field; light strip labeled "Meaning" under the prompt band.
  - **Reading card** → answer is the Reading field; dark strip labeled "Reading" under the prompt band; the answer box converts typed romaji to hiragana as you type (`nikki` → にっき, `nn` → ん, doubled consonant → っ). Text typed with a Japanese IME is left as is.
  - After answering, the Notes field (if any) is shown under the answer.
- **Any other note type**: **prompt** = the note's first field; **answer** = the note's second field (field order from the note type), with no strip. For Basic notes that's Front / Back.
- Field HTML is converted to plain text: `<br>` and block tags become line breaks, other tags are removed, HTML entities are decoded. Images and sound tags are dropped.
- A card is **skipped** (not type-checkable) if, after conversion, its prompt or answer is empty, or the note type has fewer than two fields.

## Answer checking

1. **Normalize** both the typed answer and each accepted answer: Unicode NFKC (folds full-width characters), lowercase, remove punctuation and symbols, collapse whitespace, trim.
2. **Accepted answers** from the back:
   - the whole back;
   - each part when split on commas, semicolons, slashes, or line breaks;
   - each of the above with parenthesized text removed (so "run (verb)" accepts "run").
   Empty results are discarded.
3. **Exact match** with any accepted answer → correct.
4. **Near-miss**: otherwise, compute Levenshtein distance to each accepted answer. Allowed distance depends on the accepted answer's length *n* (after normalization):
   - n ≤ 3 → 0
   - n ≤ 5 → 1
   - n ≤ 7 → 2
   - n > 7 → 2 + ⌊(n − 7) / 7⌋
   Within the allowed distance of any accepted answer → correct (near-miss).
5. Otherwise → wrong.

Result type: `.exact`, `.nearMiss(expected: String)`, or `.wrong`.

**Reading cards** are checked strictly, like WaniKani readings: both sides are normalized as above and katakana is folded to hiragana, then splitting (step 2) applies, but there is **no near-miss tolerance** — any difference is wrong. On Return, a trailing `n` or `nn` becomes ん; if Latin letters still remain after that, the box shakes and the answer is not submitted, so you can fix it.

## Architecture

Swift package with a library target for everything testable and a thin app target:

```
Recall/
  Package.swift
  Sources/
    RecallCore/
      AnkiClient.swift        // AnkiConnect HTTP: deckNames, findCards, cardsInfo,
                              // getDeckConfig, answerCards. Protocol AnkiService + live impl.
      CardContent.swift       // HTML → plain text, prompt/answer extraction, skip rule
      AnswerChecker.swift     // normalization, accepted answers, Levenshtein, verdict
      RomajiConverter.swift   // live romaji → hiragana for Reading cards
      Stage.swift             // interval → Stage
      QueueBuilder.swift      // builds the session queue from AnkiService
      ReviewSession.swift     // @Observable state machine: current card, submit, advance,
                              // re-queue, wrap up, stats; talks to AnkiService
    Recall/
      RecallApp.swift
      DashboardView.swift
      ReviewView.swift
      SummaryView.swift
      AnkiLauncher.swift      // open Anki via NSWorkspace, poll until connected
      Theme.swift             // WaniKani-style colors, stage bar, shake effect
  Tests/
    RecallCoreTests/          // AnswerChecker, RomajiConverter, CardContent, Stage, QueueBuilder,
                              // ReviewSession (with a fake AnkiService)
  scripts/
    build-app.sh              // release build → ~/Applications/Recall.app (Info.plist, icon)
```

- `AnkiService` is a protocol so `QueueBuilder` and `ReviewSession` are tested against an in-memory fake, without Anki running.
- AnkiConnect errors (`"error"` non-null) and connection failures surface as typed `AnkiError` values (`.notRunning`, `.api(String)`).
- `build-app.sh` builds outside `~/Documents` (its file provider adds attributes `codesign` rejects) and installs `~/Applications/Recall.app`.

## Testing

- **Unit tests** (`swift test`): answer checking (exact, punctuation/case, splitting, parentheses, near-miss thresholds, Japanese/full-width, strict readings with katakana folding), romaji conversion (っ, ん, small kana like `kya`), Japanese Vocab vs. other note types, HTML conversion, stage boundaries, queue building (new-card limit, skipping), session behavior (re-queue spacing, wrap up, stats, failed-send retry).
- **Manual check** against the real Anki: dashboard counts match Anki's deck overview, a short session updates the cards in Anki (visible in Anki's Browse window), and the not-running screen appears when Anki is closed.

## Added 2026-10-18

- **Wrong answers wait to be sent.** After a wrong answer, two buttons appear: **Retry** (⌘R) puts the card back in the queue without telling Anki, and **Mark correct** (⌘Return) counts it as right and sends Good. Return moves on and sends Again. Correct answers are still sent right away.
- **Furigana.** After answering, the Japanese Vocab word shows its reading in small type above the kanji, lined up so okurigana isn't covered (行(い)きました). On Meaning cards a **Show/Hide furigana** button (⌘F, remembered) shows it before answering too. Reading cards never show it before answering.
- **Mnemonics.** After answering, **Add/Edit mnemonic** (⌘E) edits the note's `Mnemonic` field (one per word, shared by its Meaning and Reading cards, and the same field the Add to Anki popup uses). Recall adds the field to Japanese Vocab at launch if missing; other note types get mnemonics only if they have a `Mnemonic` field.
- **Copyable question.** The prompt text is selectable, and right-click offers Copy.
- **Frosted window.** The window background is a heavy blur of whatever is behind it, tinted with ink.

The "I was actually right" override listed below is now built (Mark correct).

## Out of scope

Lessons, audio, editing cards, statistics beyond the stage bar and session summary, an "I was actually right" override (may be added later if near-miss checking misjudges too often), syncing (Anki handles that), multiple decks per session.
