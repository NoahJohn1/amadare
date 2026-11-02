// Source: Amadare repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Add selected text to Anki as a Japanese Vocab note (Meaning + Reading cards), with all fields editable before adding.
// Requires furigana.js and kanji-readings.txt next to this script.
// Called by the "Add to Anki" Quick Action with the selection in $ANKI_FRONT.
ObjC.import('stdlib');
ObjC.import('Cocoa');

// furigana(word, reading), shared with the lookup popup.
const readFile = name => $.NSString.stringWithContentsOfFileEncodingError(
  $.getenv('HOME') + '/Library/Application Support/AnkiQuickAdd/' + name, $.NSUTF8StringEncoding, null).js;
(0, eval)(readFile('furigana.js'));
setKanjiReadings(readFile('kanji-readings.txt'));
(0, eval)(readFile('connection.js'));
const CONNECTION = readAnkiConnection();

const DECK = 'Inbox';
const MODEL = 'Japanese Vocab';
// [field name, required to add]. An empty Reading means no Reading card.
// The note's Furigana field isn't shown; it's generated from Word and Reading when adding.
const FIELDS = [['Word', true], ['Meaning', true], ['Reading', false], ['Mnemonic', false], ['Notes', false]];

function html(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\r?\n/g, '<br>');
}

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

function quoted(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}

// The field delegate class is registered once, so its method can't close over one window's rows: when the
// editor reopens after a failure, it has to reach the new window through this.
let onFieldChange = () => {};

// Native window with editable Word, Meaning, Reading, Mnemonic and Notes fields. Returns null if cancelled.
// `values` fills the fields; `error`, if any, says why the last try failed, and Add becomes Try Again.
// Tab switches fields, Return adds, Option-Return inserts a new line, Esc cancels.
// Add stays disabled while Word or Meaning is empty; the rest are optional.
function editCard(values, error) {
  const nsapp = $.NSApplication.sharedApplication;
  nsapp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  nsapp.activateIgnoringOtherApps(true);

  // osascript has no menu bar, so ⌘V/⌘C/⌘X/⌘A/⌘Z do nothing without an Edit menu to route them.
  const mainMenu = $.NSMenu.alloc.init;
  const editItem = $.NSMenuItem.alloc.init;
  mainMenu.addItem(editItem);
  const editMenu = $.NSMenu.alloc.initWithTitle('Edit');
  [['Undo', 'undo:', 'z'], ['Redo', 'redo:', 'Z'], null,
   ['Cut', 'cut:', 'x'], ['Copy', 'copy:', 'c'], ['Paste', 'paste:', 'v'], ['Select All', 'selectAll:', 'a']]
    .forEach(i => i ? editMenu.addItemWithTitleActionKeyEquivalent(i[0], i[1], i[2]) : editMenu.addItem($.NSMenuItem.separatorItem));
  editItem.submenu = editMenu;
  nsapp.mainMenu = mainMenu;

  // Fields fit their text: one line minimum, growing as you type, scrolling past MAX_H.
  const W = 440, MIN_H = 22, MAX_H = 180, LABEL_H = 17, GAP = 4;
  const WORD_FONT_SIZE = 30; // big enough to make out complex kanji
  const view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, W, 100));
  function addLabel(text) {
    const l = $.NSTextField.labelWithString(text);
    view.addSubview(l);
    return l;
  }
  function addField(value, fontSize) {
    const f = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, W, MIN_H));
    if (fontSize) f.font = $.NSFont.systemFontOfSize(fontSize);
    f.stringValue = value;
    f.usesSingleLineMode = false;
    f.cell.wraps = true;
    f.cell.scrollable = false;
    f.delegate = fieldDelegate;
    view.addSubview(f);
    return f;
  }
  function fitHeight(f) {
    const c = f.cell.copy;
    c.stringValue = f.stringValue;
    const h = Math.ceil(c.cellSizeForBounds($.NSMakeRect(0, 0, W, 100000)).height);
    return Math.min(MAX_H, Math.max(MIN_H, h));
  }

  let alert = null;
  let lastHeights = '';
  function relayout() {
    const heights = rows.map(r => fitHeight(r.field));
    if (heights.join(',') === lastHeights) return;
    lastHeights = heights.join(',');
    // AppKit views are bottom-up: lay rows out from the last one (y=0) upwards.
    let y = 0;
    for (let i = rows.length - 1; i >= 0; i--) {
      rows[i].field.frame = $.NSMakeRect(0, y, W, heights[i]);
      y += heights[i] + GAP;
      rows[i].label.frame = $.NSMakeRect(0, y, W, LABEL_H);
      y += LABEL_H + (i > 0 ? 8 : 0);
    }
    view.setFrameSize($.NSMakeSize(W, y));
    if (alert) alert.layout;
  }

  function updateAddButton() {
    if (!alert) return;
    const filled = r => r.field.stringValue.js.trim().length > 0;
    alert.buttons.objectAtIndex(0).enabled = rows.every(r => !r.required || filled(r));
  }

  if (!$.AnkiFieldDelegate) {
    ObjC.registerSubclass({
      name: 'AnkiFieldDelegate',
      protocols: ['NSTextFieldDelegate'],
      methods: { 'controlTextDidChange:': { types: ['void', ['id']], implementation: function () { onFieldChange(); } } }
    });
  }
  onFieldChange = () => { relayout(); updateAddButton(); };
  const fieldDelegate = $.AnkiFieldDelegate.alloc.init;

  const rows = FIELDS.map(([name, required]) => ({
    name, required,
    label: addLabel(required ? name : name + ' (optional)'),
    field: addField(values[name] || '', name === 'Word' ? WORD_FONT_SIZE : undefined)
  }));
  // Tab order follows the on-screen order.
  rows.forEach((r, i) => { r.field.nextKeyView = rows[(i + 1) % rows.length].field; });
  relayout();

  alert = $.NSAlert.alloc.init;
  alert.messageText = 'Add to Anki';
  alert.informativeText = error || 'Tab switches fields · Option-Return for a new line';
  alert.addButtonWithTitle(error ? 'Try Again' : 'Add');
  alert.addButtonWithTitle('Cancel');
  alert.accessoryView = view;
  alert.layout;
  alert.window.initialFirstResponder = rows.find(r => r.name === 'Meaning').field;
  updateAddButton();

  if (alert.runModal != $.NSAlertFirstButtonReturn) return null;
  const note = {};
  rows.forEach(r => { note[r.name] = r.field.stringValue.js.trim(); });
  return note;
}

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
