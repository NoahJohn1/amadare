# Hosting Anki on Nimbasa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Tasks marked **Nimbasa** must run in a Nimbasa-Claude session, and steps marked **Noah** are done by Noah by hand.

**Goal:** Move Anki and AnkiConnect to Nimbasa, so the iPhone, Mac app, Mac shortcuts and Muse all use one always-on collection.

**Architecture:** Anki desktop runs in Noah's Windows session with AnkiConnect on `127.0.0.1:8765`. Tailscale Serve exposes it over HTTPS to the tailnet. The Mac reads a `connection.json` file (absent means local Anki, as today). Lookup searches a local snapshot and refreshes it in the background. Muse reads through the existing allowlist proxy, documented in a vault guide.

**Tech Stack:** Swift 6 with Swift Testing, JXA and WKWebView (Quick Actions), zsh, PowerShell, Python standard library (proxy), Node's built-in test runner (for one pure JS file), Tailscale Serve, AnkiConnect API v6.

**Spec:** `docs/superpowers/specs/2026-11-01-nimbasa-anki-host-design.md`

**One change from the spec's phase order:** the Mac code is written and tested against an empty Nimbasa profile *before* the collection moves. Every change falls back to local Anki when `connection.json` is absent, so the Mac keeps working throughout, and the move itself becomes one short step instead of a sitting with broken shortcuts.

## Global Constraints

- Anki version on Nimbasa: **26.9.3**, the same as the Mac.
- `webBindAddress` on Nimbasa stays `127.0.0.1`. `webCorsOriginList` stays `["http://localhost"]`.
- Mac settings file: `~/Library/Application Support/Amadare/connection.json`, mode `600`, shape `{ "url": "...", "apiKey": "..." }`. A missing or malformed file means local Anki.
- Cache file: `~/Library/Application Support/AnkiQuickAdd/notes-cache.json`, mode `600`, shape `{ "savedAt": <ms>, "notes": [<raw notesInfo objects>] }`.
- Never put the API key in this repo, in the vault, or in a Claude session. Noah pastes it into prompts by hand. Scripts on Nimbasa read it from the user environment variable `ANKI_API_KEY`.
- This repo is public: no tailnet name, IP address or key in anything committed. Use `nimbasa.<tailnet>.ts.net` in docs.
- Muse stays read-only, through the proxy only.
- No third-party packages.
- Swift tests: `swift test --scratch-path ~/Library/Caches/Amadare/build`. JS tests: `node --test Tests/QuickActions/`.
- Work on the branch `nimbasa-anki`. Commit after every task. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Quick Action sources live in `QuickActions/`; run `scripts/install-quick-actions.sh` after editing them.

## File Map

```
Sources/AmadareCore/AnkiConnection.swift     new: the connection settings, parsed and testable
Sources/AmadareCore/AnkiClient.swift         5xx replies count as unreachable
Sources/Amadare/AnkiConnectConfig.swift      connection(): file, else local
Sources/Amadare/AppModel.swift               builds LiveAnki from the connection
Sources/Amadare/DashboardView.swift          remote wording; no Open Anki button
QuickActions/connection.js                   new: same settings, for the JXA scripts
QuickActions/add-to-anki.js                  remote URL, one multi call, editor reopens on failure
QuickActions/lookup-in-anki.js               remote URL, reads and saves the cache
QuickActions/lookup.html                     remote URL, timeouts, snapshot search and refresh
QuickActions/lookup-search.js                new: pure snapshot matching
Tests/AmadareCoreTests/AnkiConnectionTests.swift  new
Tests/AmadareCoreTests/AnkiClientTests.swift      5xx test
Tests/QuickActions/lookup-search.test.mjs    new
scripts/install-quick-actions.sh             copies the new files
scripts/use-anki-server.sh                   new: turns server mode on and off
scripts/measure-anki-latency.sh              new: median and p95 of a full search
scripts/nimbasa/configure-ankiconnect.ps1    new: API key and bind address
scripts/nimbasa/keep-anki-running.ps1        new: starts Anki if nothing is listening
scripts/nimbasa/anki-sync.ps1                new: daily AnkiWeb sync
scripts/nimbasa/install-tasks.ps1            new: registers the scheduled tasks
README.md                                    server mode
```

---

### Task 1: Amadare connection settings (Mac)

**Files:**
- Create: `Sources/AmadareCore/AnkiConnection.swift`, `Tests/AmadareCoreTests/AnkiConnectionTests.swift`
- Modify: `Sources/AmadareCore/AnkiClient.swift:209-220`, `Sources/Amadare/AnkiConnectConfig.swift`, `Sources/Amadare/AppModel.swift:12-14`, `Sources/Amadare/DashboardView.swift:94-119`, `Tests/AmadareCoreTests/AnkiClientTests.swift`

**Interfaces:**
- Produces: `AnkiConnection` with `url: URL`, `apiKey: String?`, `isRemote: Bool`, `hostName: String`, `static func local(apiKey: String?) -> AnkiConnection`, `static func remote(fromJSON: Data) -> AnkiConnection?`. `AnkiConnectConfig.connection() -> AnkiConnection`. `AppModel.connection`.

- [ ] **Step 1: Create the branch**

```bash
git switch -c nimbasa-anki
```

- [ ] **Step 2: Write the failing tests**

`Tests/AmadareCoreTests/AnkiConnectionTests.swift`:

```swift
import Foundation
import Testing
@testable import AmadareCore

@Test func readsARemoteConnection() throws {
    let json = #"{"url":"https://nimbasa.example.ts.net","apiKey":"secret"}"#
    let connection = try #require(AnkiConnection.remote(fromJSON: Data(json.utf8)))
    #expect(connection.url == URL(string: "https://nimbasa.example.ts.net"))
    #expect(connection.apiKey == "secret")
    #expect(connection.isRemote)
    #expect(connection.hostName == "nimbasa")
}

@Test func aMalformedConnectionFileIsIgnored() {
    #expect(AnkiConnection.remote(fromJSON: Data("not json".utf8)) == nil)
    #expect(AnkiConnection.remote(fromJSON: Data(#"{"apiKey":"secret"}"#.utf8)) == nil)
    #expect(AnkiConnection.remote(fromJSON: Data(#"{"url":""}"#.utf8)) == nil)
}

@Test func aConnectionWithoutAKeyStillWorks() throws {
    let connection = try #require(AnkiConnection.remote(fromJSON: Data(#"{"url":"https://a.ts.net"}"#.utf8)))
    #expect(connection.apiKey == nil)
}

@Test func localConnectionUsesTheDefaultURL() {
    let connection = AnkiConnection.local(apiKey: "k")
    #expect(connection.url == LiveAnki.defaultURL)
    #expect(connection.apiKey == "k")
    #expect(!connection.isRemote)
}
```

In `Tests/AmadareCoreTests/AnkiClientTests.swift`, add to `StubURLProtocol`, next to the other static vars:

```swift
    nonisolated(unsafe) static var statusCode = 200
```

Change the `HTTPURLResponse` line in `startLoading` to:

```swift
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
```

Add to `StubbedAnkiTests`:

```swift
    @Test func aBadGatewayMeansAnkiIsUnreachable() async {
        StubURLProtocol.statusCode = 502
        defer { StubURLProtocol.statusCode = 200 }
        StubURLProtocol.responses = ["Bad Gateway"]
        await #expect(throws: AnkiError.notRunning) { _ = try await stubbedAnki().deckNames() }
    }
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --scratch-path ~/Library/Caches/Amadare/build`
Expected: a build failure, because `AnkiConnection` doesn't exist.

- [ ] **Step 4: Write the implementation**

`Sources/AmadareCore/AnkiConnection.swift`:

```swift
import Foundation

/// Where AnkiConnect is and how to authenticate. Remote when `connection.json` names a server;
/// otherwise the local Anki at the default address.
public struct AnkiConnection: Equatable, Sendable {
    public let url: URL
    public let apiKey: String?
    public let isRemote: Bool

    /// The machine's short name, for messages: "nimbasa" for `https://nimbasa.example.ts.net`.
    public var hostName: String {
        url.host()?.split(separator: ".").first.map(String.init) ?? url.absoluteString
    }

    public static func local(apiKey: String?) -> AnkiConnection {
        AnkiConnection(url: LiveAnki.defaultURL, apiKey: apiKey, isRemote: false)
    }

    /// Parses `connection.json`. Nil when it's malformed or names no server, which means local Anki.
    public static func remote(fromJSON data: Data) -> AnkiConnection? {
        struct File: Decodable {
            let url: String
            let apiKey: String?
        }
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              let url = LiveAnki.serverURL(from: file.url)
        else { return nil }
        return AnkiConnection(url: url, apiKey: file.apiKey, isRemote: true)
    }
}
```

In `Sources/AmadareCore/AnkiClient.swift`, replace the `do` block at the end of `send`:

```swift
        do {
            let (data, response) = try await session.data(for: request)
            // Tailscale Serve answers 502 when Anki is closed on the server.
            if let http = response as? HTTPURLResponse, (500...599).contains(http.statusCode) {
                throw AnkiError.notRunning
            }
            return data
        } catch is URLError {
            throw AnkiError.notRunning
        }
```

The spec says a non-JSON reply from a remote server counts as unreachable. This checks the status code instead, because the iPhone's Settings screen relies on `.badResponse` to say "Something at … answered, but not like AnkiConnect".

In `Sources/Amadare/AnkiConnectConfig.swift`, add inside the enum, and update its doc comment to mention the file:

```swift
    static let connectionFile = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Amadare/connection.json")

    /// The server named in `connection.json` (see `scripts/use-anki-server.sh`), else this Mac's Anki.
    static func connection() -> AnkiConnection {
        if let data = try? Data(contentsOf: connectionFile), let remote = AnkiConnection.remote(fromJSON: data) {
            return remote
        }
        return .local(apiKey: localAPIKey())
    }
```

Add `import AmadareCore` at the top of that file.

In `Sources/Amadare/AppModel.swift`, replace `let anki = LiveAnki(apiKey: AnkiConnectConfig.localAPIKey())` with:

```swift
    let connection: AnkiConnection
    let anki: LiveAnki
```

and add, before `prepareAnki`:

```swift
    init() {
        let connection = AnkiConnectConfig.connection()
        self.connection = connection
        anki = LiveAnki(url: connection.url, apiKey: connection.apiKey)
    }
```

In `Sources/Amadare/DashboardView.swift`, replace `notRunningView` with:

```swift
    private var notRunningView: some View {
        VStack(spacing: 16) {
            Text(model.connection.isRemote ? "Can't reach Anki on \(model.connection.hostName)" : "Anki isn't open")
                .font(.title2.bold())
            Text(model.connection.isRemote
                 ? "Check that Tailscale is on and that Anki is running on \(model.connection.hostName)."
                 : "Amadare reads your cards through AnkiConnect, so Anki needs to be running.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                if !model.connection.isRemote {
                    Button(isLaunching ? "Opening Anki…" : "Open Anki") {
                        Task {
                            isLaunching = true
                            _ = await AnkiLauncher.openAndWait(anki: model.anki)
                            isLaunching = false
                            await load()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.mizu)
                    .disabled(isLaunching)
                }
                Button("Try again") { Task { await load() } }
                    .buttonStyle(.glass)
                    .disabled(isLaunching)
            }
        }
        .padding(36)
        .frame(maxWidth: 440)
        .glassEffect(in: .rect(cornerRadius: 28))
    }
```

- [ ] **Step 5: Run the tests and build the app**

Run: `swift test --scratch-path ~/Library/Caches/Amadare/build && scripts/build-app.sh`
Expected: all tests pass, and the app builds and installs. With no `connection.json`, Amadare behaves as before.

- [ ] **Step 6: Commit**

```bash
git add Sources Tests/AmadareCoreTests
git commit -m "Let Amadare use an Anki on another machine" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Server-mode scripts and Add to Anki (Mac)

**Files:**
- Create: `QuickActions/connection.js`, `scripts/use-anki-server.sh`, `scripts/measure-anki-latency.sh`
- Modify: `QuickActions/add-to-anki.js`, `scripts/install-quick-actions.sh:10`

**Interfaces:**
- Produces: global JXA function `readAnkiConnection()` returning `{ url, key, remote }`, loaded with `(0, eval)`. Later tasks rely on it.

- [ ] **Step 1: Write `QuickActions/connection.js`**

It must only declare functions, because `const` doesn't survive `(0, eval)`.

```js
// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Where AnkiConnect is, for the Quick Actions: the server in connection.json (scripts/use-anki-server.sh), else this Mac.
// Sources/Amadare/AnkiConnectConfig.swift does the same; keep the two in step.
function readAnkiConnection() {
  const read = path => $.NSString.stringWithContentsOfFileEncodingError(
    $.getenv('HOME') + path, $.NSUTF8StringEncoding, null).js;
  try {
    const file = JSON.parse(read('/Library/Application Support/Amadare/connection.json'));
    if (file.url) return { url: file.url, key: file.apiKey || null, remote: true };
  } catch (e) {}
  let key = null;
  try {
    key = (JSON.parse(read('/Library/Application Support/Anki2/addons21/2055492159/meta.json')).config || {}).apiKey || null;
  } catch (e) {}
  return { url: 'http://127.0.0.1:8765', key, remote: false };
}
```

- [ ] **Step 2: Copy it on install**

In `scripts/install-quick-actions.sh`, change the `cp` line to:

```zsh
cp add-to-anki.js lookup-in-anki.js lookup.html lookup-search.js connection.js furigana.js kanji-readings.txt "$DEST/"
```

Task 6 adds `lookup-search.js`, so until then create it as an empty placeholder file with only the source comment:

```js
// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
```

- [ ] **Step 3: Update `QuickActions/add-to-anki.js`**

After `setKanjiReadings(readFile('kanji-readings.txt'));`, add:

```js
(0, eval)(readFile('connection.js'));
const CONNECTION = readAnkiConnection();
```

Replace the `ankiKey` and `anki` functions with:

```js
const UNREACHABLE = 'unreachable';

function anki(app, action, params) {
  const body = JSON.stringify({ action, version: 6, key: CONNECTION.key, params: params || {} });
  let res;
  try {
    res = JSON.parse(app.doShellScript('curl -s --connect-timeout 3 --max-time 8 -X POST ' +
      quoted(CONNECTION.url) + ' --data-binary ' + quoted(body)));
  } catch (e) {
    throw new Error(UNREACHABLE); // curl failed, or something other than AnkiConnect answered
  }
  if (res.error) throw new Error(res.error);
  return res.result;
}

// One request, so curl only makes one connection. Each action in a multi needs its own key,
// and reports its own error in its result.
function addCard(app, fields) {
  const results = anki(app, 'multi', { actions: [
    { action: 'createDeck', version: 6, key: CONNECTION.key, params: { deck: DECK } },
    { action: 'addNote', version: 6, key: CONNECTION.key, params: { note: {
      deckName: DECK, modelName: MODEL,
      fields,
      options: { allowDuplicate: false }, tags: ['quick-add']
    }}}
  ]});
  const failed = results.find(r => r && r.error);
  if (failed) throw new Error(failed.error);
}

function errorText(e) {
  if (e.message !== UNREACHABLE) return String(e.message);
  return CONNECTION.remote
    ? 'Couldn\'t reach Anki on the server. Your card isn\'t saved yet. Check Tailscale, then try again.'
    : 'Couldn\'t reach Anki. Your card isn\'t saved yet. Make sure Anki is open and the AnkiConnect add-on is installed.';
}
```

The field delegate class is registered only once per process, so its method would keep calling the first window's closure when the editor reopens. Add above `editCard`:

```js
let onFieldChange = () => {};
```

Change the signature and comment of `editCard`:

```js
// Native window with editable Word, Meaning, Reading, Mnemonic and Notes fields. Returns null if cancelled.
// `values` fills the fields; `error`, if any, says why the last try failed, and Add becomes Try Again.
// Tab switches fields, Return adds, Option-Return inserts a new line, Esc cancels.
// Add stays disabled while Word or Meaning is empty; the rest are optional.
function editCard(values, error) {
```

Replace the delegate method's implementation, and set the callback right after the `if (!$.AnkiFieldDelegate) { … }` block:

```js
      methods: { 'controlTextDidChange:': { types: ['void', ['id']], implementation: function () { onFieldChange(); } } }
```

```js
  onFieldChange = () => { relayout(); updateAddButton(); };
```

Replace the `field:` line in the `rows` map:

```js
    field: addField(values[name] || '', name === 'Word' ? WORD_FONT_SIZE : undefined)
```

Replace the alert text and first button:

```js
  alert.messageText = 'Add to Anki';
  alert.informativeText = error || 'Tab switches fields · Option-Return for a new line';
  alert.addButtonWithTitle(error ? 'Try Again' : 'Add');
```

Replace `run()`:

```js
function run() {
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  const front = ($.getenv('ANKI_FRONT') || '').trim();
  if (!front) return;

  let values = { Word: front }, error = null;
  for (;;) {
    const note = editCard(values, error);
    if (!note || !note.Word || !note.Meaning) return; // cancelled or emptied
    const preview = note.Word.length > 100 ? note.Word.slice(0, 100) + '…' : note.Word;
    const fields = {};
    FIELDS.forEach(([name]) => { fields[name] = html(note[name]); });
    fields.Furigana = html(furigana(note.Word, note.Reading));

    try {
      addCard(app, fields);
      app.displayNotification(preview, { withTitle: 'Card added to ' + DECK });
      return;
    } catch (e) {
      values = note;
      error = errorText(e);
    }
  }
}
```

- [ ] **Step 4: Write `scripts/use-anki-server.sh`**

```zsh
#!/bin/zsh
# Points this Mac's Amadare and Quick Actions at an Anki on another machine.
#
#   scripts/use-anki-server.sh https://your-server.your-tailnet.ts.net
#   scripts/use-anki-server.sh --off     back to the Anki on this Mac
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$HOME/Library/Application Support/Amadare"
FILE="$DIR/connection.json"

if [[ "${1:-}" == "--off" ]]; then
  rm -f "$FILE"
  "$ROOT/scripts/install-quick-actions.sh"
  echo "Using the Anki on this Mac. Reopen Amadare to pick this up."
  exit 0
fi

URL="${1:?Usage: scripts/use-anki-server.sh <url> or --off}"
read -rs "KEY?AnkiConnect API key: "
echo

mkdir -p "$DIR"
umask 077
URL="$URL" KEY="$KEY" /usr/bin/python3 -c '
import json, os, sys
json.dump({"url": os.environ["URL"], "apiKey": os.environ["KEY"]}, open(sys.argv[1], "w"))
' "$FILE"
chmod 600 "$FILE"
"$ROOT/scripts/install-quick-actions.sh"

REPLY=$(curl -s --connect-timeout 3 --max-time 8 -X POST "$URL" \
  --data-binary "{\"action\":\"deckNames\",\"version\":6,\"key\":\"$KEY\"}" || true)
case "$REPLY" in
  *'"error": null'*|*'"error":null'*) echo "Connected. Reopen Amadare to pick this up." ;;
  *) echo "Saved, but the server didn't answer as expected: ${REPLY:-no reply}" >&2; exit 1 ;;
esac
```

Then run `chmod +x scripts/use-anki-server.sh`.

- [ ] **Step 5: Write `scripts/measure-anki-latency.sh`**

```zsh
#!/bin/zsh
# Times a full lookup search (findNotes, then notesInfo) against the Anki in connection.json, reusing the
# connection between the two calls as the lookup window does. Prints the median and p95 of 20 searches.
set -euo pipefail
FILE="$HOME/Library/Application Support/Amadare/connection.json"
read -r URL KEY <<< "$(/usr/bin/python3 -c '
import json, sys
c = json.load(open(sys.argv[1]))
print(c["url"], c.get("apiKey") or "")
' "$FILE")"

FIND="{\"action\":\"findNotes\",\"version\":6,\"key\":\"$KEY\",\"params\":{\"query\":\"deck:*\"}}"
INFO="{\"action\":\"notesInfo\",\"version\":6,\"key\":\"$KEY\",\"params\":{\"query\":\"deck:*\"}}"

for i in {1..20}; do
  curl -s -o /dev/null -w '%{time_total}\n' -X POST "$URL" --data-binary "$FIND" \
    --next -s -o /dev/null -w '%{time_total}\n' -X POST "$URL" --data-binary "$INFO" \
    | awk '{ total += $1 } END { printf "%.0f\n", total * 1000 }'
done | sort -n | awk '{ v[NR] = $1 } END {
  printf "Full search, %d runs: median %d ms, p95 %d ms\n", NR, v[int((NR + 1) / 2)], v[int(NR * 0.95)]
}'
```

Then run `chmod +x scripts/measure-anki-latency.sh`.

- [ ] **Step 6: Test against local Anki**

Noah opens Anki on the Mac, then:

```bash
scripts/install-quick-actions.sh
```

Select a test word in any app and press ⌃⌘A:
- Add a note. Expected: the "Card added" notification appears, and the note exists in Anki with its Furigana field filled in.
- Add the same word again. Expected: the editor reopens with the duplicate error and **Try Again**, with all fields kept. Typing in a reopened field still resizes it and updates the button.
- Quit Anki and press Add. Expected: the editor reopens with "Couldn't reach Anki". Reopen Anki and press **Try Again**, and the note is added.

Delete the test note in Anki afterwards.

- [ ] **Step 7: Commit**

```bash
git add QuickActions scripts/install-quick-actions.sh scripts/use-anki-server.sh scripts/measure-anki-latency.sh
git commit -m "Add to Anki works with a remote server and keeps your text on failure" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Live lookup against the configured server (Mac)

**Files:**
- Modify: `QuickActions/lookup-in-anki.js`, `QuickActions/lookup.html`

**Interfaces:**
- Consumes: `readAnkiConnection()` from Task 2.
- Produces: page constants `ANKI_URL`, `REMOTE`, `HINTS`; page function `isNetworkError(e)`.

- [ ] **Step 1: Update `QuickActions/lookup-in-anki.js`**

Delete the `ankiKey` function and its comment. Update line 4's comment to say the page talks to AnkiConnect directly at the configured address. Inside `run()`, after the `read` constant, add:

```js
  (0, eval)(read('connection.js'));
  const connection = readAnkiConnection();
```

Replace the last injection and add the new ones:

```js
    .replace('__ANKI_KEY__', () => JSON.stringify(connection.key))
    .replace('__ANKI_URL__', () => JSON.stringify(connection.url))
    .replace('__ANKI_REMOTE__', () => JSON.stringify(connection.remote));
```

Move the `read` constant above its first use if needed, so that `connection` is ready before the `html` line runs.

- [ ] **Step 2: Update `QuickActions/lookup.html`**

After `const KEY = __ANKI_KEY__;` add:

```js
const ANKI_URL = __ANKI_URL__;
const REMOTE = __ANKI_REMOTE__;
const HINTS = '↑↓ to move · ⌘E edits' + (REMOTE ? '' : ' · ⌘O opens in Anki') + ' · Esc closes';
```

Replace the `anki` function:

```js
async function anki(action, params) {
  const r = await fetch(ANKI_URL, {
    method: 'POST',
    signal: AbortSignal.timeout(8000),
    body: JSON.stringify({ action, version: 6, key: KEY, params: params || {} })
  });
  if (!r.ok) throw new Error('network: HTTP ' + r.status); // Tailscale Serve answers 502 when Anki is closed
  const j = await r.json();
  if (j.error) throw new Error(j.error);
  return j.result;
}

const isNetworkError = e => /fetch|Load failed|network|timed out|abort/i.test(e.message);
const UNREACHABLE = REMOTE
  ? 'Couldn’t reach Anki on ' + esc(new URL(ANKI_URL).hostname.split('.')[0]) + '. Check that Tailscale is on and that Anki is running there.'
  : 'Couldn’t reach Anki. Make sure Anki is open and the AnkiConnect add-on is installed.';
```

`UNREACHABLE` uses `esc`, so move the `esc` declaration above this block.

In `search()`:
- In the status line, replace the literal hint text with `HINTS`: `' · ' + HINTS`.
- Replace the `catch` body's `showEmpty(...)` with `showEmpty(isNetworkError(e) ? UNREACHABLE : esc(e.message));`.

In `saveEdit()`, replace the error line with:

```js
    msg.textContent = isNetworkError(e) ? 'Couldn’t reach Anki — not saved.' : 'Not saved: ' + e.message;
```

Hide Open in Anki on a remote server. In `showDetail()`, replace the action buttons in the template with:

```js
       `<div id="cards"></div><div class="actions"><button id="edit">Edit</button>` +
       (REMOTE ? '' : `<button id="open">Open in Anki</button>`) +
       `<span class="msg" id="msg">${esc(r.savedMsg || '')}</span></div></div>`;
```

Replace the `open` handler line with:

```js
  if (!REMOTE) document.getElementById('open').onclick = openInAnki;
```

Add a guard to `openInAnki`:

```js
function openInAnki() {
  const r = results[sel];
  if (r && !REMOTE) anki('guiBrowse', { query: 'nid:' + r.note.noteId }).catch(() => {});
}
```

Replace the footer's initial text with an empty string, and add before `$q.value = INITIAL;`:

```js
$status.textContent = HINTS;
```

- [ ] **Step 3: Test against local Anki**

```bash
scripts/install-quick-actions.sh
```

With Anki open on the Mac: ⌃⌘L on a selected word finds it, ⌘E edit saves, ⌘O opens Anki's browser, ⌥⌘L lists every note. With Anki quit: lookup shows the "Couldn't reach Anki" message rather than hanging.

- [ ] **Step 4: Commit**

```bash
git add QuickActions
git commit -m "Lookup uses the configured Anki, with timeouts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Nimbasa scripts (Mac)

These live in the repo so they're versioned, and the Nimbasa clone gets them with `git pull`. They hold no tailnet names or keys.

**Files:**
- Create: `scripts/nimbasa/configure-ankiconnect.ps1`, `scripts/nimbasa/keep-anki-running.ps1`, `scripts/nimbasa/anki-sync.ps1`, `scripts/nimbasa/install-tasks.ps1`

**Interfaces:**
- Produces: scheduled tasks `Amadare Keep Anki Running` and `Amadare Anki Sync`. User environment variable `ANKI_API_KEY`.

- [ ] **Step 1: Write `scripts/nimbasa/configure-ankiconnect.ps1`**

```powershell
# Sets AnkiConnect to localhost only, with a new API key. Run with Anki closed: it keeps add-on settings in
# memory and may write them back. The key is never printed. It's kept in ANKI_API_KEY for the other scripts,
# and Noah reads it with:  [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
$ErrorActionPreference = 'Stop'
$addon = Join-Path $env:APPDATA 'Anki2\addons21\2055492159'
$config = Get-Content (Join-Path $addon 'config.json') -Raw | ConvertFrom-Json
$meta = Get-Content (Join-Path $addon 'meta.json') -Raw | ConvertFrom-Json

$key = [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
if (-not $key) {
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $key = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
    [Environment]::SetEnvironmentVariable('ANKI_API_KEY', $key, 'User')
}

$config.webBindAddress = '127.0.0.1'
$config.apiKey = $key
$meta | Add-Member -NotePropertyName config -NotePropertyValue $config -Force
# WriteAllText writes UTF-8 with no byte-order mark. PowerShell 5's Set-Content would add one, which breaks JSON readers.
[IO.File]::WriteAllText((Join-Path $addon 'meta.json'), ($meta | ConvertTo-Json -Depth 10))
Write-Output 'AnkiConnect configured: localhost only, API key set.'
```

- [ ] **Step 2: Write `scripts/nimbasa/keep-anki-running.ps1`**

```powershell
# Starts Anki if nothing is listening on AnkiConnect's port. Run by a scheduled task in the desktop session,
# since Anki can't start from a service or an SSH session.
param([Parameter(Mandatory)][string]$AnkiExe)
if (Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue) { exit 0 }
Start-Process -FilePath $AnkiExe
```

- [ ] **Step 3: Write `scripts/nimbasa/anki-sync.ps1`**

```powershell
# Syncs the collection to AnkiWeb: the off-machine backup. Logs each run, because the task's own result
# shows 0 even when this fails (it runs through conhost).
$log = Join-Path $env:LOCALAPPDATA 'Amadare\anki-sync.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$key = [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
$body = @{ action = 'sync'; version = 6; key = $key } | ConvertTo-Json
try {
    $reply = Invoke-RestMethod -Uri 'http://127.0.0.1:8765' -Method Post -Body $body -TimeoutSec 300
    $outcome = if ($reply.error) { "failed: $($reply.error)" } else { 'ok' }
} catch {
    $outcome = "failed: $_"
}
Add-Content $log "$(Get-Date -Format s) $outcome"
```

- [ ] **Step 4: Write `scripts/nimbasa/install-tasks.ps1`**

```powershell
# Registers the scheduled tasks. They run through conhost --headless so that no console window flashes.
param([Parameter(Mandatory)][string]$AnkiExe)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)

function Register-Headless($name, $script, $arguments, $triggers) {
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' `
        -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$here\$script`" $arguments"
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
}

$every5 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-Headless 'Amadare Keep Anki Running' 'keep-anki-running.ps1' "-AnkiExe `"$AnkiExe`"" @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME), $every5)
Register-Headless 'Amadare Anki Sync' 'anki-sync.ps1' '' (New-ScheduledTaskTrigger -Daily -At 4am)
Write-Output 'Scheduled tasks registered.'
```

- [ ] **Step 5: Commit and push the branch**

Push only once Noah has agreed to it for this branch, since Nimbasa pulls from origin.

```bash
git add scripts/nimbasa
git commit -m "Add the scripts that run Anki on Nimbasa" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push -u origin nimbasa-anki
```

---

### Task 5: Install Anki on Nimbasa, empty profile (**Nimbasa**)

Run in a Nimbasa-Claude session in `C:\Users\noahj\repos\amadare`, then finish the check from the Mac. Installing software and changing system settings needs Noah's go-ahead for each step.

- [ ] **Step 1: Get the scripts**

```powershell
git fetch origin; git switch nimbasa-anki; git pull
```

- [ ] **Step 2: Noah: install and first launch**

Noah installs Anki 26.9.3 from apps.ankiweb.net or winget, opens it on the desktop, picks a language, then **Tools → Add-ons → Get Add-ons…**, code `2055492159`, restarts it once and quits it. Turn off the update check in **Preferences**. Noah doesn't sign in to AnkiWeb yet: that happens after the collection moves (Task 8), so an empty profile can't conflict with it.

Record the installed path of `anki.exe`, for example from the Start Menu shortcut's target. Call it `<anki.exe>` below.

- [ ] **Step 3: Configure and register tasks**

```powershell
scripts\nimbasa\configure-ankiconnect.ps1
scripts\nimbasa\install-tasks.ps1 -AnkiExe "<anki.exe>"
```

Wait up to 5 minutes, or run the task once with `Start-ScheduledTask 'Amadare Keep Anki Running'`. Then check:

```powershell
Get-NetTCPConnection -LocalPort 8765 -State Listen | Select-Object LocalAddress, LocalPort
```

Expected: `127.0.0.1`, port `8765`, and no console window appeared on the desktop.

- [ ] **Step 4: Noah: enable HTTPS**

In the Tailscale admin console, under DNS, enable **HTTPS Certificates**. This adds the machine name to public certificate logs.

- [ ] **Step 5: Expose it through Serve**

```powershell
tailscale serve --bg --https=443 http://127.0.0.1:8765
tailscale serve status
```

Expected: `https://nimbasa.<tailnet>.ts.net` proxying to `http://127.0.0.1:8765`. If `tailscale` asks for elevation, Noah runs it from an elevated terminal.

- [ ] **Step 6: Noah: survive restarts**

Noah decides on auto-login. If yes: set it up with Sysinternals Autologon, and add a logon task to lock the screen (`rundll32.exe user32.dll,LockWorkStation`). Also check the BIOS setting that powers the PC on after an outage.

- [ ] **Step 7: Verify from the Mac**

Noah gets the key on Nimbasa with `[Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')`, and from the Mac's own terminal runs:

```bash
scripts/use-anki-server.sh https://nimbasa.<tailnet>.ts.net
```

Expected: `Connected. Reopen Amadare to pick this up.`

If Serve can't work here, use the spec's fallback: set `webBindAddress` to the Tailscale IP, add a firewall rule on the Tailscale interface, and add an HTTP exception to `scripts/build-app.sh`.

- [ ] **Step 8: Reboot test**

Reboot Nimbasa, then run `scripts/measure-anki-latency.sh` on the Mac and open Amadare. Expected: with auto-login on, Amadare shows its dashboard within about 6 minutes of the reboot with nobody touching the PC. Without auto-login, it does so after Noah logs in.

- [ ] **Step 9: Record it in the vault**

Nimbasa-Claude writes `Changes/YYYY-MM-DD-HHMMZ-nimbasa-claude-anki-installed.md` from `Templates/Change-Entry`, noting the state, and that the key is in the user environment and not in the vault.

---

### Task 6: Measure, try the Mac tools, decide on the cache (Mac)

This runs against the empty Nimbasa profile, whose contents are thrown away in Task 8.

- [ ] **Step 1: Try the tools on the empty profile**

Reopen Amadare. It creates the `Japanese Vocab` note type on launch. Then:
- ⌃⌘A adds a test word. Expected: "Card added to Inbox".
- ⌃⌘L finds it. ⌘E edit saves. There's no Open in Anki button, and the footer doesn't mention ⌘O.
- Lookup with Tailscale off shows the "Couldn't reach Anki on nimbasa" message within 8 seconds. Add to Anki with Tailscale off reopens the editor with your text.
- In Amadare with Tailscale off: "Can't reach Anki on nimbasa", with only **Try again**.

Add a few more test notes, so that the measurement in the next step has real data.

- [ ] **Step 2: Measure**

```bash
scripts/measure-anki-latency.sh
```

Run it at home, and again away from home or on a phone hotspot. Add both results to the spec, under "Is it worth it?", replacing the estimates.

- [ ] **Step 3: Decide**

Build the cache (Task 7) unless the p95 is under 100 ms in both places **and** Noah doesn't want offline lookup. Skipping it needs Noah's agreement.

- [ ] **Step 4: Go back to local until the move**

```bash
scripts/use-anki-server.sh --off
```

- [ ] **Step 5: Commit the measurements**

```bash
git add docs/superpowers/specs/2026-11-01-nimbasa-anki-host-design.md
git commit -m "Record measured lookup latency to Nimbasa" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Lookup cache (Mac)

**Files:**
- Modify: `QuickActions/lookup-search.js`, `QuickActions/lookup-in-anki.js`, `QuickActions/lookup.html`
- Create: `Tests/QuickActions/lookup-search.test.mjs`

**Interfaces:**
- Consumes: `anki`, `isNetworkError`, `UNREACHABLE`, `HINTS` from Task 3.
- Produces: `matchNotes(notes, query, fieldTexts)` returning the matching notes.

- [ ] **Step 1: Write the failing test**

`Tests/QuickActions/lookup-search.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const context = {};
vm.runInNewContext(readFileSync(new URL('../../QuickActions/lookup-search.js', import.meta.url), 'utf8'), context);
const { matchNotes } = context;

const notes = [
  { noteId: 1, texts: ['日記', 'diary', 'にっき'] },
  { noteId: 2, texts: ['天気', 'weather', 'てんき'] },
];
const fieldTexts = n => n.texts;
const ids = q => Array.from(matchNotes(notes, q, fieldTexts), n => n.noteId);

test('an empty query returns every note', () => assert.deepEqual(ids(''), [1, 2]));
test('matches Japanese in any field', () => assert.deepEqual(ids('てん'), [2]));
test('matches English regardless of case', () => assert.deepEqual(ids('DIA'), [1]));
test('matches the middle of a field', () => assert.deepEqual(ids('eat'), [2]));
test('returns nothing when nothing matches', () => assert.deepEqual(ids('猫'), []));
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test Tests/QuickActions/`
Expected: FAIL, because `matchNotes` is undefined.

- [ ] **Step 3: Write `QuickActions/lookup-search.js`**

```js
// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Searches the local snapshot of notes. Used by lookup.html; kept apart from the page so it can be tested.

// The notes with a field containing the query, ignoring case. fieldTexts(note) gives its fields as lowercase plain text.
function matchNotes(notes, query, fieldTexts) {
  const q = query.toLowerCase();
  if (!q) return notes;
  return notes.filter(n => fieldTexts(n).some(text => text.includes(q)));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node --test Tests/QuickActions/`
Expected: 5 tests pass.

- [ ] **Step 5: Load and save the cache in `QuickActions/lookup-in-anki.js`**

Add near the top, after `DIR`:

```js
const CACHE = DIR + '/notes-cache.json';

// Written atomically, readable only by you: it holds your card text.
function saveCache(json) {
  $(json).writeToFileAtomicallyEncodingError(CACHE, true, $.NSUTF8StringEncoding, null);
  $.NSFileManager.defaultManager.setAttributesOfItemAtPathError(
    $.NSDictionary.dictionaryWithObjectForKey($.NSNumber.numberWithShort(0o600), $.NSFilePosixPermissions), CACHE, null);
}

function loadCache() {
  try {
    const cache = JSON.parse($.NSString.stringWithContentsOfFileEncodingError(CACHE, $.NSUTF8StringEncoding, null).js);
    return Array.isArray(cache.notes) ? cache : null;
  } catch (e) { return null; }
}
```

Replace the message handler's implementation:

```js
        // The page posts 'close' on Esc, and the snapshot's JSON whenever it changes.
        'userContentController:didReceiveScriptMessage:': {
          types: ['void', ['id', 'id']],
          implementation: function (controller, message) {
            const body = ObjC.unwrap(message.body);
            if (body === 'close') win.performClose(null);
            else saveCache(body);
          }
        },
```

Add the new injections at the **end** of the `html` chain, moving the semicolon:

```js
    .replace('__SEARCH_JS__', () => read('lookup-search.js'))
    .replace('__CACHE__', () => JSON.stringify(loadCache()).replace(/</g, '\\u003c'));
```

The cache goes last so that nothing later can match text inside your cards. Each uses a replacer function, so `$` in card text stays literal.

- [ ] **Step 6: Search the snapshot in `QuickActions/lookup.html`**

Add a script block above the page's main script:

```html
<script>
__SEARCH_JS__
</script>
```

After the `HINTS` line add:

```js
const CACHE = __CACHE__;
let snapshot = CACHE ? CACHE.notes : null, savedAt = CACHE ? CACHE.savedAt : null, offline = false;

// Stripping a field's HTML means parsing it, so keep the result between keystrokes.
const textsByNote = new WeakMap();
function fieldTexts(note) {
  if (!textsByNote.has(note)) textsByNote.set(note, Object.values(note.fields).map(f => plain(f.value).toLowerCase()));
  return textsByNote.get(note);
}

function saveSnapshot() {
  savedAt = Date.now();
  window.webkit.messageHandlers.lookup.postMessage(JSON.stringify({ savedAt, notes: snapshot }));
}

const footer = count => {
  const parts = [];
  if (offline && savedAt) parts.push('Offline · cards from ' + new Date(savedAt).toLocaleDateString());
  if (count !== undefined) parts.push(count + (count === 1 ? ' card' : ' cards'));
  parts.push(HINTS);
  $status.textContent = parts.join(' · ');
};
```

Replace `search()` with:

```js
// No snapshot yet (the first run): ask Anki.
async function liveNotes(q) {
  const found = await anki('findNotes', { query: q ? ankiTerm(q) : 'deck:*' });
  const ids = q ? found : found.sort((a, b) => b - a);
  return ids.length ? anki('notesInfo', { notes: ids.slice(0, MAX) }) : [];
}

// keepId keeps that note selected when a background refresh re-runs the search.
async function search(keepId) {
  const q = $q.value.trim(), my = ++seq;
  try {
    const notes = snapshot ? matchNotes(snapshot, q, fieldTexts) : await liveNotes(q);
    if (my !== seq) return;
    const lq = q.toLowerCase();
    results = notes.map(n => {
      const f = fieldsInOrder(n), p = f.map(([, v]) => plain(v).toLowerCase());
      const rank = p.some(v => v === lq) ? 0 : p.some(v => v.startsWith(lq)) ? 1 : 2;
      return { note: n, fields: f, title: plain(f[0] ? f[0][1] : ''), sub: plain(f[1] ? f[1][1] : ''), rank };
    });
    if (q) results.sort((a, b) => a.rank - b.rank || a.title.length - b.title.length);
    else results.sort((a, b) => b.note.noteId - a.note.noteId);
    const total = results.length;
    results = results.slice(0, MAX);
    const kept = results.findIndex(r => r.note.noteId === keepId);
    sel = kept >= 0 ? kept : results.length ? 0 : -1;
    render(q);
    if (!results.length) showEmpty(q ? 'No cards contain “' + esc(q) + '”.' : 'Your collection has no cards yet.');
    else showDetail();
    footer(total);
  } catch (e) {
    if (my !== seq) return;
    results = []; render(q);
    showEmpty(isNetworkError(e) ? UNREACHABLE : esc(e.message));
  }
}

// Replaces the snapshot with what's in Anki now. Skips the re-render when nothing changed, and leaves an open editor alone.
async function refresh() {
  try {
    const notes = await anki('notesInfo', { query: 'deck:*' });
    offline = false;
    const changed = !snapshot || JSON.stringify(notes) !== JSON.stringify(snapshot);
    if (changed) {
      snapshot = notes;
      saveSnapshot();
      if (!editing) await search(results[sel] && results[sel].note.noteId);
    }
    if (!changed) footer(results.length);
  } catch (e) {
    if (isNetworkError(e)) { offline = true; footer(results.length); }
  }
}
```

In `saveEdit()`, after the `Object.assign(r, …)` line, add:

```js
    if (snapshot) {
      const i = snapshot.findIndex(s => s.noteId === n.noteId);
      if (i >= 0) { snapshot[i] = n; saveSnapshot(); }
    }
```

Replace the `input` listener, because the typing pause only exists to spare Anki:

```js
$q.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(search, snapshot ? 0 : 120); });
```

`setTimeout` calls `search` with no arguments, so `keepId` is undefined there, as intended.

Replace the end of the script:

```js
$q.value = INITIAL;
$q.focus();
$q.select();
search();
refresh();
```

The `$status.textContent = HINTS;` line from Task 3 is now redundant with `footer`, so remove it.

- [ ] **Step 7: Test by hand**

Noah opens Anki on the Mac (local mode uses the same code).

```bash
scripts/install-quick-actions.sh
```

- First ⌃⌘L: results appear from live search, then `notes-cache.json` exists. Check `stat -f %Lp ~/Library/Application\ Support/AnkiQuickAdd/notes-cache.json` prints `600`.
- Second ⌃⌘L: results appear immediately and update per keystroke with no visible pause.
- Add a card with ⌃⌘A, then ⌃⌘L for it: it appears as soon as the refresh finishes.
- Move to the third result and leave the window open while editing a note in Anki: selection stays on the same note after the next open's refresh.
- ⌘E, change a meaning, ⌘S: "Saved". Close, quit Anki, ⌃⌘L: the new text is there, and the footer reads "Offline · cards from …". Deck and schedule lines are absent, not an error.
- Offline, ⌘E then ⌘S: "Couldn't reach Anki — not saved", and the text stays in the editor.
- Search works with a Japanese IME mid-composition, and Esc still closes.

- [ ] **Step 8: Commit**

```bash
git add QuickActions Tests/QuickActions
git commit -m "Lookup searches a local copy of your cards, so it's instant and works offline" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Move the collection (Mac, **Nimbasa**, Noah)

Run in one sitting. Reviewing on either machine during this task would be lost.

- [ ] **Step 1: Noah: quit Anki on the Mac**

Confirm with `pgrep -xl Anki`: there's no output.

- [ ] **Step 2: Archive and fingerprint on the Mac**

```bash
cd ~/"Library/Application Support/Anki2" && COPYFILE_DISABLE=1 tar --no-xattrs -czf ~/Documents/anki-before-nimbasa-$(date +%F).tar.gz "User 1"
```

```bash
shasum -a 256 ~/"Library/Application Support/Anki2/User 1/collection.anki2"
```

Record the hash. Then record the note, card and review counts (24, 42 and 151 on 2026-11-01; there may be more now):

```bash
/usr/bin/python3 - <<'PY'
import os, sqlite3, urllib.parse
path = os.path.expanduser("~/Library/Application Support/Anki2/User 1/collection.anki2")
db = sqlite3.connect("file:" + urllib.parse.quote(path) + "?immutable=1", uri=True)
for table in ("notes", "cards", "revlog"):
    print(table, db.execute(f"select count(*) from {table}").fetchone()[0])
PY
```

- [ ] **Step 3: Stop Anki on Nimbasa, without it restarting**

In the Nimbasa session:

```powershell
Disable-ScheduledTask 'Amadare Keep Anki Running' | Out-Null
$key = [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
Invoke-RestMethod -Uri http://127.0.0.1:8765 -Method Post -Body (@{ action = 'guiExitAnki'; version = 6; key = $key } | ConvertTo-Json)
Start-Sleep 5; Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue
```

Expected: the last line prints nothing.

- [ ] **Step 4: Copy it over**

From the Mac (Noah's key logs in as `noahj`):

```bash
scp ~/Documents/anki-before-nimbasa-$(date +%F).tar.gz noahj@nimbasa:anki-move.tar.gz
```

On Nimbasa, replace the empty profile with it:

```powershell
Remove-Item -Recurse -Force "$env:APPDATA\Anki2\User 1"
tar -xzf "$env:USERPROFILE\anki-move.tar.gz" -C "$env:APPDATA\Anki2"
(Get-FileHash "$env:APPDATA\Anki2\User 1\collection.anki2" -Algorithm SHA256).Hash
```

Expected: the hash matches the Mac's, ignoring case. If the new profile on Nimbasa wasn't named `User 1`, stop and tell Noah. Then restart:

```powershell
Enable-ScheduledTask 'Amadare Keep Anki Running' | Out-Null
Start-ScheduledTask 'Amadare Keep Anki Running'
```

- [ ] **Step 5: Point the Mac at Nimbasa and verify**

Noah runs, in the Mac's own terminal, pasting the key:

```bash
scripts/use-anki-server.sh https://nimbasa.<tailnet>.ts.net
```

Then compare with the recorded counts, using a throwaway script that reads the key from `connection.json` without printing it:

```bash
/usr/bin/python3 - <<'PY'
import json, os, subprocess
c = json.load(open(os.path.expanduser("~/Library/Application Support/Amadare/connection.json")))
def call(action, **params):
    body = json.dumps({"action": action, "version": 6, "key": c["apiKey"], "params": params})
    return json.loads(subprocess.run(["curl", "-s", "-X", "POST", c["url"], "--data-binary", body], capture_output=True, text=True).stdout)["result"]
print("notes", len(call("findNotes", query="deck:*")))
cards = call("findCards", query="deck:*")
print("cards", len(cards))
print("reviews", sum(len(v) for v in call("getReviewsOfCards", cards=cards).values()))
print("intervals", sorted(i["interval"] for i in call("cardsInfo", cards=cards))[:10])
PY
```

Expected: the counts match the Mac's. Open Amadare: it shows the same decks and due counts as before, and a review saves.

- [ ] **Step 6: Noah: set up the backup**

On Nimbasa's desktop, Noah signs in to AnkiWeb and syncs. When Anki asks which side to keep, choose **Upload to AnkiWeb**, unless AnkiWeb holds data worth keeping, in which case stop and decide first. Then test the daily task:

```powershell
Start-ScheduledTask 'Amadare Anki Sync'
Start-Sleep 20; Get-Content "$env:LOCALAPPDATA\Amadare\anki-sync.log" -Tail 1
```

Expected: a line ending in `ok`.

- [ ] **Step 7: Retire the Mac's Anki**

```bash
scripts/share-anki.sh --off
```

This reopens nothing unless Anki was running. Confirm with `pgrep -xl Anki`. Leave the app installed for a week of use, then Noah removes it. Keep the archive in `~/Documents`.

Rollback, if needed: run `scripts/use-anki-server.sh --off` and copy `collection.anki2` back from Nimbasa, so reviews since the move aren't lost. Restore the archive only if Nimbasa's copy is gone.

---

### Task 9: Point the iPhone at Nimbasa (Noah)

No code. The Mac's re-sign agent isn't affected.

- [ ] **Step 1:** Open Tailscale on the iPhone, sign in if needed, and connect. On the Mac, `tailscale status` should show the iPhone as active. Turn on the app's VPN On Demand setting.
- [ ] **Step 2:** In Amadare → Settings, enter `https://nimbasa.<tailnet>.ts.net` and the new key, then **Test connection**. Expected: success.
- [ ] **Step 3:** Put the Mac to sleep, turn off Wi-Fi on the iPhone, and complete a review on cellular. Wake the Mac: Amadare on the Mac shows that answer as done.

---

### Task 10: Read-only proxy for Muse (**Nimbasa**)

**Files:**
- Modify: vault `System/Setup/anki-readonly-proxy.py` (Nimbasa-Claude owns `System/Setup`)
- Create: `scripts/nimbasa/keep-proxy-running.ps1` in this repo

- [ ] **Step 1: Add the API key to the proxy**

Add `import os` to the imports, and below `ANKI_URL`:

```python
# AnkiConnect requires this key. The proxy adds it, so callers never hold it.
API_KEY = os.environ.get("ANKI_API_KEY")
```

In `do_POST`, right after the `FORWARD` print, add:

```python
        payload["key"] = API_KEY
        if payload.get("action") == "multi":
            # AnkiConnect checks the key on each action inside a multi too.
            for sub in payload["params"]["actions"]:
                sub["key"] = API_KEY
        raw = json.dumps(payload).encode("utf-8")
```

Include a `multi` of `deckNames` and `modelNames` in the next step's test.

- [ ] **Step 2: Test it locally, including rejection**

Start the proxy on `127.0.0.1` with `python anki-readonly-proxy.py`, then:

```powershell
$url = 'http://127.0.0.1:18765'
Invoke-RestMethod $url -Method Post -Body '{"action":"deckNames","version":6}'
Invoke-RestMethod $url -Method Post -Body '{"action":"getDeckStats","version":6,"params":{"decks":["Inbox"]}}'
try { Invoke-RestMethod $url -Method Post -Body '{"action":"addNote","version":6,"params":{}}' } catch { $_.Exception.Response.StatusCode.value__ }
```

Expected: real decks and stats with no key sent, and `403` for `addNote`. Stop the proxy.

- [ ] **Step 3: Write `scripts/nimbasa/keep-proxy-running.ps1`, push it, and register it**

```powershell
# Starts Muse's read-only Anki proxy if it isn't listening. Pass the Tailscale IP as -Bind: the proxy fails to
# start until Tailscale is up, so this retries on a schedule.
param(
    [Parameter(Mandatory)][string]$Proxy,
    [Parameter(Mandatory)][string]$Bind
)
if (Get-NetTCPConnection -LocalPort 18765 -State Listen -ErrorAction SilentlyContinue) { exit 0 }
Start-Process -FilePath pythonw.exe -ArgumentList "`"$Proxy`"", '--bind', $Bind, '--port', '18765' -WindowStyle Hidden
```

Register it, filling in the proxy's path in Nimbasa's vault:

```powershell
$here = (Resolve-Path scripts\nimbasa).Path
$proxy = '<vault>\System\Setup\anki-readonly-proxy.py'
$ip = (tailscale ip -4)
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$here\keep-proxy-running.ps1`" -Proxy `"$proxy`" -Bind $ip"
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$triggers = @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME),
              (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)))
Register-ScheduledTask -TaskName 'Amadare Anki Proxy' -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask 'Amadare Anki Proxy'
```

Python must be on the PATH, with `pythonw.exe`. If it isn't, Noah installs it first (`winget install Python.Python.3.12`). The proxy only reads `ANKI_API_KEY` at start, so a key change needs a proxy restart.

- [ ] **Step 4: Noah: allow it through the firewall**

From an elevated terminal:

```powershell
New-NetFirewallRule -DisplayName 'Anki read-only proxy (Tailscale)' -Direction Inbound -Protocol TCP -LocalPort 18765 -InterfaceAlias Tailscale -Action Allow
```

- [ ] **Step 5: Verify from another tailnet machine**

From the Mac:

```bash
curl -s -X POST http://nimbasa:18765 --data-binary '{"action":"deckNames","version":6}'
```

Expected: the real deck list. Check the tailnet's access rules allow the `muse` device to reach this port. If they need changing, that's for Noah to do.

- [ ] **Step 6: Commit**

```bash
git add scripts/nimbasa/keep-proxy-running.ps1
git commit -m "Keep Muse's read-only Anki proxy running on Nimbasa" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push
```

---

### Task 11: Anki API guide for Muse (**Nimbasa**)

**Files:**
- Create: vault `Nimbasa-Claude/Japanese/Anki-API-Guide.md`
- Modify: vault `System/Setup/Muse-Setup.md`, `Projects/Japanese-Learning.md` (with the rev check)

- [ ] **Step 1: Write the guide**

Write it for an agent that has never seen this setup. Run every example through the proxy first and paste shortened real responses. Frontmatter:

```yaml
---
type: note
agent: Nimbasa-Claude
project: japanese-learning
tags: [japanese, anki, setup]
last-updated: <date>
---
```

Sections, in this order:

1. **What's there.** Noah's live Anki collection runs on Nimbasa. It's the only copy Amadare, the iPhone and the Mac use. Name the decks (`Inbox` is where ⌃⌘A adds cards), the `Japanese Vocab` fields (Word, Meaning, Reading, Mnemonic, Notes, Furigana), the two cards per note (ord 0 Meaning, ord 1 Reading), and the `quick-add` tag.
2. **How to connect.** `POST http://Nimbasa:18765`, reached through Muse's Tailscale tunnel proxy. The body is JSON: `{"action": "...", "version": 6, "params": {...}}`. Don't send a key; the proxy adds it.
3. **What it can do.** Every action in the proxy's `READ_ACTIONS`, copied from the live file, each with one line of purpose. Say this list comes from the proxy, and that `multi` works if every sub-action is on it.
4. **Common questions**, each with its tested request and a shortened response:

   | Question | Request |
   |---|---|
   | Which decks exist, and how many cards are in each? | `getDeckStats` with `{"decks": ["Inbox"]}`; `deckNames` for the list |
   | How many reviews are due today? | `findCards` with `{"query": "deck:Inbox is:due"}`, then count; note `getDeckStats`' `review_count` |
   | Is this word already a card, and what are its fields? | `notesInfo` with `{"query": "deck:* Word:日記"}` |
   | When and how was this card last reviewed? | `cardReviews` with `{"deck": "Inbox", "startID": 0}`, filtered by card ID |

5. **How to read the answers.** Card `type`: 0 new, 1 learning, 2 review, 3 relearning. `queue`: -1 suspended, 0 new, 1 learning, 2 review, 3 day-learning. `interval`: days when positive, seconds when negative. `due`: depends on the queue. Amadare's stages by interval in days: copy the thresholds from `Sources/AmadareCore/` in the repo, and link to them.
6. **Failures.** 403 means the action isn't allowed. That's the proxy working, so don't try to get around it. 502 means Anki isn't running: tell Noah. A connection failure means check the tunnel, then tell Noah.
7. **Rules.** Read only. Writes need a separate route that Noah approves. Write the date next to any count put in the vault, because counts go stale. The API key never goes in the vault.

- [ ] **Step 2: Link it**

Add a `[[Nimbasa-Claude/Japanese/Anki-API-Guide]]` link to `Muse-Setup.md`'s Anki read test, and to the "What each agent knows" section of `Projects/Japanese-Learning.md`, replacing "Nimbasa-Claude knows: nothing Japanese-specific yet". Follow the rev check for the project page. Update `Nimbasa-Claude/Index.md`, which lists Anki and the proxy as not done.

- [ ] **Step 3: Push to the vault**

Nimbasa-Claude adds a `Changes/` entry saying the guide exists and the proxy is live, and pushes.

- [ ] **Step 4: Noah: tell Muse, and check it**

Noah tells Muse in chat that Anki is ready. Acceptance: Muse runs the read test (`deckNames` and `getDeckStats` succeed; `addNote` returns 403). Then, from the guide alone, Muse reports how many reviews are due, and the number matches Amadare's dashboard at that moment. If Muse has to ask anything the guide should have said, add it to the guide.

---

### Task 12: Docs, final checks and merge (Mac)

**Files:**
- Modify: `README.md`, vault `Mac-Claude/Japanese/Anki-App-and-Decks.md`, vault `Projects/Japanese-Learning.md`

- [ ] **Step 1: Update `README.md`**

First run `git pull`, to get the proxy script committed from Nimbasa in Task 10.

In "On the iPhone", replace the sentence beginning "It reaches your Anki over the network" through "change the address in the app's Settings." with:

```markdown
It reaches your Anki over the network through AnkiConnect, so whichever machine runs Anki needs to be on with
Anki open while you review: your Mac, or an always-on PC (see [Running Anki on a server](#running-anki-on-a-server)).
```

In "Quick Actions", replace "They talk to AnkiConnect too, so Anki needs to be open." with:

```markdown
They talk to AnkiConnect too, so Anki needs to be running, on this Mac or on your server.
```

Add to the file list:

```markdown
- `connection.js`: where AnkiConnect is, for both scripts: your server if one is set, else this Mac.
- `lookup-search.js`: searches the local copy of your cards. Test it with `node --test Tests/QuickActions/`.
```

Add a section before "Quick Actions":

```markdown
## Running Anki on a server

Anki can live on an always-on PC instead of your Mac, so reviews on the iPhone don't need the Mac awake.
`scripts/nimbasa/` holds the Windows side: a task that keeps Anki running in your desktop session, and a daily
AnkiWeb sync. [Tailscale Serve](https://tailscale.com/kb/1312/serve) makes it reachable over HTTPS from your own
devices, while AnkiConnect stays bound to localhost on the PC.

On the Mac, point Amadare and the Quick Actions at it:

    scripts/use-anki-server.sh https://your-pc.your-tailnet.ts.net

It asks for the API key and saves both in `~/Library/Application Support/Amadare/connection.json`.
`scripts/use-anki-server.sh --off` goes back to the Anki on your Mac. On the iPhone, enter the same address and
key in Settings.

With a server set:

- **Look Up and Search** use a local copy of your cards, so they're instant and work offline. Each time you open
  one, the copy refreshes in the background. Saving an edit, deck and schedule details, and images need the server.
- **Add to Anki** needs the server. If it can't be reached, the window reopens with what you typed so you can
  try again.
- **Reviews** need the server, since Anki does the scheduling.
- **Open in Anki** is hidden, because Anki's window is on the other machine.
```

- [ ] **Step 2: Run the full automated tests**

```bash
swift test --scratch-path ~/Library/Caches/Amadare/build
```

```bash
node --test Tests/QuickActions/
```

Expected: everything passes. Also run `git grep -nE 'ts\.net|100\.[0-9]+\.[0-9]+\.' -- . ':!Tests'`: the only `ts.net` matches should be placeholders (`<tailnet>`, `your-tailnet`, `example`), and there should be no real addresses.

- [ ] **Step 3: Run the spec's acceptance checks**

All from "Testing" in the spec, on the real setup: iPhone on cellular with the Mac asleep; ⌃⌘A from Safari, with and without Tailscale; ⌃⌘L instantly, and offline; an edit surviving reopen; a Nimbasa reboot. Local mode was checked in Tasks 2, 3 and 7, before the move, so don't reopen the Mac's Anki for this. Muse's check was done in Task 11.

- [ ] **Step 4: Commit and merge**

```bash
git add README.md
git commit -m "README: running Anki on a server" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Use the finishing-a-development-branch skill to merge `nimbasa-anki`, and rebuild the installed apps from the result with `scripts/build-app.sh` and `scripts/install-quick-actions.sh`.

- [ ] **Step 5: Update the vault**

Mac-Claude copies `Mac-Claude/Japanese/Anki-App-and-Decks.md` and `Projects/Japanese-Learning.md` to the outbox. Update "How it runs" and "Known next steps" on the first, and "Current state", "Open questions" and "Next steps" on the second, using the rev check. Add a `Changes/` entry, then:

```bash
~/.claude/hivemind/hivemind push
```
