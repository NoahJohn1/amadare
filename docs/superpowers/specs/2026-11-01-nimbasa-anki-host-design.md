# Hosting Anki on Nimbasa

Move Anki and AnkiConnect from the Mac to Nimbasa, the always-on Windows PC at home, so reviews, lookups and new cards no longer depend on the Mac being awake with Anki open.

**Date:** 2026-11-01
**Status:** Draft, awaiting review

## Goal

- The iPhone app works any time, from anywhere, with the Mac asleep.
- On the Mac, Amadare, Add to Anki (⌃⌘A), Look Up in Anki (⌃⌘L) and Search Anki (⌥⌘L) keep working the same way, against the collection on Nimbasa.
- Lookup stays fast, and still works when Nimbasa can't be reached.
- Muse can read the live Anki data through a read-only API, with a guide in the vault explaining how to use it.
- Nobody else who uses this public repo has to change anything: without a server configured, the Mac app and Quick Actions keep using a local Anki.

## Decisions

| Question | Decision |
|---|---|
| Where the collection lives | Only on Nimbasa. The Mac's Anki is retired after the move. Nothing has to be kept in sync, and every device sees the same reviews. |
| How devices reach Anki | Tailscale Serve: `https://nimbasa.<tailnet>.ts.net` forwards to AnkiConnect, which stays bound to `127.0.0.1` on Nimbasa. |
| Authentication | Tailnet membership plus a new AnkiConnect API key. The old key was sent over plain HTTP on the LAN, so it isn't reused. |
| How Anki stays running | A scheduled task starts it at logon in the desktop session and restarts it if it has exited. |
| Mac connection settings | One file, `~/Library/Application Support/Amadare/connection.json`, read by the app and the Quick Actions. If it's missing, they use local Anki as they do today. |
| Lookup | Searches a local snapshot of the notes and refreshes it in the background each time it opens. See [The lookup cache](#the-lookup-cache). |
| Add to Anki when Nimbasa is unreachable | The editor reopens with what you typed so you can retry. There's no offline queue. |
| Reviews when Nimbasa is unreachable | Not supported. Scheduling belongs to Anki. |
| Off-machine backup | Daily AnkiWeb sync from Nimbasa, since this becomes the only copy. AnkiWeb isn't set up today. |
| Muse's access | Read-only, through the existing allowlist proxy, documented in a vault guide. |

## Current state

Checked on 2026-11-01 unless noted.

- The Mac's AnkiConnect is bound to `0.0.0.0` with an API key, set by `scripts/share-anki.sh`.
- The collection is small: 24 notes, 42 cards, 151 reviews, about 1.2 KB of field text and no media files (read from the file on disk).
- The Mac profile has no AnkiWeb login, so that file is the only copy.
- `LiveAnki` already takes any URL and API key. `LiveAnki.serverURL(from:)` already accepts a full `https://….ts.net` address, so the iPhone app needs no code change.
- These parts assume a local Anki:
  - `Sources/Amadare/AppModel.swift` uses the default `127.0.0.1` URL.
  - `AnkiConnectConfig` reads the key from the local add-on folder.
  - The dashboard's "Open Anki" button launches a local app.
  - `add-to-anki.js`, `lookup-in-anki.js` and `lookup.html` hardcode `127.0.0.1:8765` and read the key from the local add-on folder.
  - "Open in Anki" (`guiBrowse`) would open the browser on whichever machine runs Anki.
- Tailscale's HTTPS certificates aren't enabled for this tailnet yet.
- The iPhone last appeared on the tailnet 183 days ago, so Tailscale on it needs checking first.
- `scripts/build-app.sh` only allows local-network HTTP (`NSAllowsLocalNetworking`), and the Quick Actions' web view runs inside `osascript`, whose settings we don't control. HTTPS avoids both limits.

## Architecture

```
iPhone Amadare ─┐
Mac Amadare ────┤  HTTPS over Tailscale
Add to Anki ────┼───────────────► Tailscale Serve (:443)
Lookup popup ───┘                     │
      │                               ▼
      ▼                     AnkiConnect (127.0.0.1:8765)
notes-cache.json                      │
(Mac, lookup only)            Anki desktop, signed-in session
                                      │
Muse ─► read-only proxy (:18765) ─────┘
```

### Why Tailscale Serve

| | Tailscale Serve (chosen) | Bind AnkiConnect to the Tailscale IP |
|---|---|---|
| Mac app and lookup web view | HTTPS, so no transport-security exceptions | Plain HTTP, so `build-app.sh` needs changing and the web view is an unknown |
| Windows Firewall | No new rule | New inbound rule |
| Startup order | Anki can start before Tailscale | Anki fails to bind if Tailscale isn't up yet |
| Reuses connections | Should, between the client and Serve | No: AnkiConnect replies `Connection: close`, so every call opens a new connection |
| Setup cost | HTTPS must be enabled once in the Tailscale admin console, which puts the machine's name in public certificate logs | None |

If Serve fails the checks in phase 1, fall back to binding the Tailscale IP, and add an HTTP exception to `build-app.sh`.

## Nimbasa

Everything runs as Noah's Windows account, as the vault's setup guide specifies.

1. **Install Anki.** Use the same version as the Mac, so the collection format matches. Noah does the first launch and enters add-on code `2055492159`, since both need the desktop. Turn off the update prompts so no dialog blocks an unattended restart.
2. **Configure AnkiConnect** while Anki is closed, as `share-anki.sh` does: `webBindAddress` stays `127.0.0.1`, and `apiKey` is newly generated. `webCorsOriginList` keeps its default `http://localhost`, which is the origin the lookup popup sends.
3. **Keep Anki running.** Anki needs a desktop session, so it can't be a Windows service or be started from SSH. A scheduled task runs at logon, "only when the user is logged on", and repeats every 5 minutes, starting Anki if the process is gone.
4. **Survive restarts.** Anki only comes back once someone logs in. Noah decides whether to turn on auto-login, then lock the screen at logon. Recommended: yes, because otherwise a Windows Update restart takes Anki down until someone signs in. The BIOS AC Recovery setting, listed as not done in the vault, also needs checking.
5. **Expose it.** After HTTPS is enabled: `tailscale serve --bg --https=443 http://127.0.0.1:8765`. Confirm it survives a reboot.
6. **Back up.** Noah signs in to AnkiWeb on Nimbasa. A daily scheduled task calls AnkiConnect's `sync`. Anki's own automatic backups stay on as well.

## Mac

### Connection settings

`connection.json`, created with mode `600`:

```json
{ "url": "https://nimbasa.<tailnet>.ts.net", "apiKey": "…" }
```

- `scripts/use-anki-server.sh <url>` prompts for the key without echoing it, writes the file and re-runs the Quick Actions installer. `--off` deletes the file, returning to local Anki.
- The key goes in a file rather than the Keychain because Quick Actions run inside whichever app is frontmost, and Keychain access would prompt per app. It's as exposed as it is today in the add-on's `meta.json`.
- The key never goes in this repo or the Hivemind vault. Noah copies it from Nimbasa into the prompt by hand, so it doesn't pass through a Claude session.

### Amadare

- `AnkiConnectConfig` gains `connection()`, returning the URL, the key and whether it's remote. `AppModel` passes these to `LiveAnki`.
- In remote mode, the dashboard's not-running screen says "Can't reach Anki on *host*" with only **Try again**. **Open Anki** stays for local mode.
- Nothing else changes. `prepareNoteType`, reviews and mnemonics all go through `LiveAnki`. A failed answer already shows the banner and Retry.

### Add to Anki (⌃⌘A)

The shortcut and window don't change, and the editor opens instantly because it touches no network until you press Add.

- A new `connection.js`, shared the way `furigana.js` is, supplies the URL and key to both Quick Action scripts. `install-quick-actions.sh` copies it.
- `createDeck` and `addNote` go in one `multi` request. `curl` makes a new connection for each process, so one call saves a full TLS handshake. The script must check each action's result inside the reply, because `multi` reports errors per action. Timeouts: `--connect-timeout 3 --max-time 8`.
- Today a failure shows a dialog and discards the note. This matters more once Anki is across a network, so on failure the editor reopens with every field filled in and the error shown, offering **Try Again** and **Cancel**. Cancel is the only way to lose the text.
- A duplicate is still reported by Anki, using the same retry path, so you can edit the word or cancel.

### Look Up and Search (⌃⌘L, ⌥⌘L)

The shortcuts and window don't change. The behaviour:

| Action | Source | With Nimbasa unreachable |
|---|---|---|
| Open, type, move through results | Local snapshot | Works |
| Word, meaning, reading, mnemonic, notes, tags | Local snapshot | Works |
| Deck and schedule lines ("reviewed every 12 days") | Live `cardsInfo`, loaded after the fields, as today | Hidden, as already handled |
| Images | Live `retrieveMediaFile`, as today | Not shown |
| Edit and save (⌘E, ⌘S) | Live `updateNoteFields` | "Couldn't reach Anki — not saved", with the text kept in the editor |
| Open in Anki (⌘O, double-click, button) | Removed in remote mode, since it would open on Nimbasa's screen | — |

## The lookup cache

### Is it worth it?

Measured from the Mac to Nimbasa over a direct Tailscale path on 2026-11-01: **25–41 ms typical round trip, 106 ms worst** across 20 pings. Anki itself isn't on Nimbasa yet, so the numbers below are estimates, and phase 2 replaces them with real ones.

A search takes two calls (`findNotes`, then `notesInfo`), after a 120 ms typing pause:

| Setup | Keystroke to results (estimate) |
|---|---|
| Today, local Anki | about 120 ms plus Anki's time |
| Nimbasa, live search over Serve | about 190–280 ms, more if Tailscale is relayed |
| Local snapshot | Under 10 ms; the typing pause can go |

An extra 100–150 ms is noticeable while typing but tolerable. Latency alone is only a modest argument for a cache. The stronger reasons are the bad cases: Tailscale reconnecting after the Mac wakes, Nimbasa restarting, or being offline. Live search would show an error or hang there, and the popup is used mid-reading, when waiting is most disruptive. The cache is also cheap, because this collection is tiny and only one place adds cards.

**Decision:** build it, as its own phase, after live lookup works. Skip it only if phase 2 shows a p95 under 100 ms for a full search both at home and away **and** Noah doesn't want offline lookup.

### Design

A single file, `~/Library/Application Support/AnkiQuickAdd/notes-cache.json`, mode `600`, holding `{ "savedAt": …, "notes": [ …raw notesInfo objects… ] }`. It stores card text only, and is written atomically.

1. **Open.** `lookup-in-anki.js` reads the file and injects it into the page, as it already does for the initial query and the furigana data.
2. **Search.** With a snapshot present, `search()` filters it in the page instead of calling `findNotes`/`notesInfo`. It matches a case-insensitive substring across each note's plain-text fields and keeps the existing ranking (exact, then prefix, then other). Because the entries are raw `notesInfo` objects, `render`, `showDetail` and the editor don't change. With no snapshot yet (first run), it searches live, as it does today.
3. **Refresh.** On every open, the page makes one `notesInfo { query: "deck:*" }` call in the background. On success it replaces the snapshot, re-runs the current search and posts the new notes to the script, which saves the file. A full reload needs no change tracking and handles deletions on its own. A later version could use `notesModTime` for deltas if the collection grows into the thousands, which isn't needed now.
4. **Staying steady.** A refresh keeps the selection by note ID and never re-renders while the editor is open.
5. **Edits.** After a successful save, the page updates that note in the snapshot and posts it back.
6. **Stale or offline.** If the refresh fails, the footer reads "Offline · cards from *date*". A note deleted elsewhere can appear until the next successful refresh; editing it shows Anki's error.

Consequences:

- A card you just added may be missing for the instant before the refresh finishes, then appears. Add to Anki doesn't write to the cache.
- Search is now our own substring match instead of Anki's search. For plain words the results should match. Anki's search syntax isn't supported in the box today anyway, because the query is quoted.
- Local mode uses the cache too, so there's only one search path to maintain.
- There's no background agent: a snapshot only needs to be current when the popup opens.

Timeouts: all page calls to Anki get an `AbortController` limit (8 s; `fetch` has none by default), so a hung server can't leave the status stuck.

## iPhone

No code changes.

1. Confirm the Tailscale app is signed in and connected. Turn on its VPN On Demand setting, since the `ts.net` address only resolves with Tailscale on, including at home.
2. In Amadare's Settings, enter the HTTPS address and the new key, then **Test connection**.

The re-sign agent on the Mac is independent of this and doesn't change. The iPhone needs the Mac only for re-signing every 5–7 days, not for reviews.

## Muse's access

Muse can read the live Anki data through an API, and has a guide explaining how. This follows the existing rule in the vault's `System/Setup/Muse-Setup.md`: Muse uses read actions through the proxy, never AnkiConnect directly, and a write would need a separate route that Noah approves.

### The read-only proxy

The vault's `anki-readonly-proxy.py` still applies, listening on port 18765 and talking to `127.0.0.1:8765` on Nimbasa.

- **API key gap.** AnkiConnect now requires a key, and the proxy forwards requests unchanged, so every call from Muse would fail. The proxy must add the key itself from an environment variable set on Nimbasa. Muse never holds it.
- **Staying up.** Bind it to the Tailscale IP as designed, and restart it from a scheduled task so that startup order doesn't matter.
- **Reachability.** Muse is a tagged tailnet device that connects through its own tunnel proxy, so confirm the tailnet's access rules let it reach `nimbasa:18765`. Muse has no route to the Serve address and doesn't need one.
- **What it reads.** The existing allowlist covers decks, deck stats, cards, notes and reviews. `cardsModTime`, `notesModTime` and media aren't included, and nothing here needs them.

### The info doc

`Nimbasa-Claude/Japanese/Anki-API-Guide.md` in the vault, linked from `Projects/Japanese-Learning`, so every agent finds it from the page they already read first. Nimbasa-Claude writes it after testing the proxy, so its examples are real, and owns it from then on. It's written for an agent that has never seen this setup, and covers:

1. **What's there.** Anki runs on Nimbasa, and this is Noah's live collection: the decks, the `Japanese Vocab` fields and what the `quick-add` tag means.
2. **How to connect.** The address and port, the route from Muse through its tunnel proxy, the JSON request format with `"version": 6`, and the note that callers don't send a key.
3. **What it can do.** Every allowlisted action, with a one-line purpose.
4. **Copy-paste examples for common questions.** Each with a tested request and a shortened response:
   - Which decks exist, and how many cards are in each?
   - How many reviews are due today?
   - Is this word already a card, and what are its fields?
   - When and how was this card last reviewed?
5. **How to read the answers.** What card `type`, `queue`, `interval` and `due` mean, and how Amadare's stages (Apprentice to Burned) follow from the interval.
6. **Failures.** 403 means the action isn't allowed, and is the proxy working as intended, so don't try to get around it. 502 means Anki isn't running, so report it to Noah.
7. **Rules.** Read only. Note the date when writing counts into the vault, since they go stale. Never put the API key in the vault.

The guide holds no secrets and no writes. `Muse-Setup.md` lives in `System/`, so Nimbasa-Claude also adds a link to the guide there, and Noah tells Muse in chat that Anki is ready. Muse's existing read test (`deckNames`, `getDeckStats`, and an `addNote` that must return 403) is the acceptance check.

## Moving the collection

Done once, with Anki closed on both machines.

1. On the Mac, record the note, card and review counts. Archive `Anki2/User 1` to a dated `.tar.gz` outside the Anki folder.
2. Copy `collection.anki2` and `collection.media` over the new profile on Nimbasa.
3. Start Anki on Nimbasa and compare the counts through AnkiConnect. Check that a card's interval matches too.
4. Run `scripts/share-anki.sh --off` on the Mac and stop opening Anki there. Remove the app once a week of use has gone by.

**Rollback:** run `use-anki-server.sh --off`, then copy the collection back from Nimbasa, so reviews done since the move aren't lost. Only restore the archive if Nimbasa's copy is gone.

## Error handling

| Situation | What you see |
|---|---|
| Mac offline, Tailscale off or Nimbasa down | Lookup works from the snapshot with the offline footer. Add to Anki keeps your text and offers retry. Amadare shows "Can't reach Anki on *host*" with Try again. |
| Anki not running on Nimbasa | Serve returns a bad-gateway error. It should read the same as above: `LiveAnki` must treat a non-JSON reply from a remote server as unreachable rather than `.badResponse`. |
| Wrong API key | AnkiConnect's error message, shown as is. |
| Answer fails mid-review | The existing banner and Retry; nothing is lost. |
| Nimbasa restarts | Anki returns at logon (with auto-login, unattended). Serve returns by itself. |

## Testing

- **Unit tests** (`Tests/AmadareCoreTests`): reading `connection.json` with the file missing, malformed and complete; a non-JSON reply from a remote server treated as unreachable.
- **Latency script** `scripts/measure-anki-latency.sh <url>`: runs a full search 20 times with `curl` and prints median and p95. Run at home and away from home, and record the numbers in this spec.
- **Acceptance checks**, by hand:
  - iPhone on cellular with the Mac asleep: complete a review, and the answer shows on the Mac.
  - ⌃⌘A from Safari adds a note; with Tailscale off, the fields survive and Try Again works once it's back on.
  - ⌃⌘L on a selected word shows results instantly; with Tailscale off, it still finds the word and shows the offline footer.
  - ⌘E edit saves, and the new text is there on reopening with Tailscale off.
  - Reboot Nimbasa: everything answers again with nobody touching it.
  - Without `connection.json`, local Anki works as it does today.
  - Muse runs its read test through the proxy: `deckNames` and `getDeckStats` succeed, and `addNote` returns 403. Then, from the guide alone, Muse reports how many reviews are due, and the number matches Amadare.

## Phases and where each runs

Install work runs in a Nimbasa-Claude session, since it needs that machine's desktop and account. Everything in this repo runs on the Mac, where the apps can be built and tried. A Nimbasa session can be opened from the Mac's Claude app over SSH or started through a vault handoff.

| # | Phase | Where | Done when |
|---|---|---|---|
| 1 | Install Anki, AnkiConnect, startup task, backup and Serve, on an empty profile | Nimbasa, with Noah for first launch, HTTPS, AnkiWeb and auto-login | `version` answers over HTTPS from the Mac after a reboot |
| 2 | Move the collection, then measure latency | Mac and Nimbasa | Counts match; median and p95 recorded; the cache decision is confirmed |
| 3 | Point the iPhone at Nimbasa | Noah, on the iPhone | Review works on cellular with the Mac asleep |
| 4 | Mac connection settings, Amadare and Add to Anki changes, live lookup against the new URL | Mac | Their acceptance checks pass |
| 5 | Lookup cache | Mac | Lookup acceptance checks pass |
| 6 | Read-only proxy with the key added | Nimbasa | Muse's read test passes |
| 7 | Anki API guide for Muse, linked from the project page and `Muse-Setup.md` | Nimbasa | Muse answers "how many reviews are due?" using only the guide |
| 8 | README and vault updates | Mac | README describes server mode; the Japanese-Learning project page is current |

Once the collection moves, the Mac's shortcuts only work after phase 4, so do phases 2–4 in one sitting.

## Out of scope

- Offline reviews, or an offline queue for new cards.
- Caching images or schedule data.
- Using Nimbasa from outside the tailnet.
- Replacing Anki desktop with a headless server. AnkiConnect is a desktop add-on, so that would be a different project.
