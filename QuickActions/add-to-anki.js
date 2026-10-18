// Source: Ankani repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Add selected text to Anki as a Japanese Vocab note (Meaning + Reading cards), with all fields editable before adding.
// Requires furigana.js next to this script.
// Called by the "Add to Anki" Quick Action with the selection in $ANKI_FRONT.
ObjC.import('stdlib');
ObjC.import('Cocoa');

// furigana(word, reading), shared with the lookup popup.
(0, eval)($.NSString.stringWithContentsOfFileEncodingError(
  $.getenv('HOME') + '/Library/Application Support/AnkiQuickAdd/furigana.js', $.NSUTF8StringEncoding, null).js);

const DECK = 'Inbox';
const MODEL = 'Japanese Vocab';
// [field name, required to add]. An empty Reading means no Reading card.
// The note's Furigana field isn't shown; it's generated from Word and Reading when adding.
const FIELDS = [['Word', true], ['Meaning', true], ['Reading', false], ['Mnemonic', false], ['Notes', false]];

function html(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\r?\n/g, '<br>');
}

function anki(app, action, params) {
  const body = JSON.stringify({ action, version: 6, params: params || {} });
  const out = app.doShellScript('curl -s --max-time 5 -X POST http://127.0.0.1:8765 --data-binary ' + quoted(body));
  const res = JSON.parse(out);
  if (res.error) throw new Error(res.error);
  return res.result;
}

function quoted(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}

// Native window with editable Word, Meaning, Reading, Mnemonic and Notes fields. Returns null if cancelled.
// Tab switches fields, Return adds, Option-Return inserts a new line, Esc cancels.
// Add stays disabled while Word or Meaning is empty; the rest are optional.
function editCard(word) {
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
      methods: { 'controlTextDidChange:': { types: ['void', ['id']], implementation: function () { relayout(); updateAddButton(); } } }
    });
  }
  const fieldDelegate = $.AnkiFieldDelegate.alloc.init;

  const rows = FIELDS.map(([name, required]) => ({
    name, required,
    label: addLabel(required ? name : name + ' (optional)'),
    field: name === 'Word' ? addField(word, WORD_FONT_SIZE) : addField('')
  }));
  // Tab order follows the on-screen order.
  rows.forEach((r, i) => { r.field.nextKeyView = rows[(i + 1) % rows.length].field; });
  relayout();

  alert = $.NSAlert.alloc.init;
  alert.messageText = 'Add to Anki';
  alert.informativeText = 'Tab switches fields · Option-Return for a new line';
  alert.addButtonWithTitle('Add');
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

  const note = editCard(front);
  if (!note || !note.Word || !note.Meaning) return; // cancelled or emptied
  const preview = note.Word.length > 100 ? note.Word.slice(0, 100) + '…' : note.Word;
  const fields = {};
  FIELDS.forEach(([name]) => { fields[name] = html(note[name]); });
  fields.Furigana = html(furigana(note.Word, note.Reading));

  try {
    anki(app, 'createDeck', { deck: DECK });
    anki(app, 'addNote', { note: {
      deckName: DECK, modelName: MODEL,
      fields,
      options: { allowDuplicate: false }, tags: ['quick-add']
    }});
    app.displayNotification(preview, { withTitle: 'Card added to ' + DECK });
  } catch (e) {
    const msg = /curl|Unexpected|JSON/i.test(String(e.message))
      ? 'Couldn\'t reach Anki. Make sure Anki is open and the AnkiConnect add-on is installed.'
      : String(e.message);
    app.displayDialog(msg, { withTitle: 'Add to Anki', buttons: ['OK'], defaultButton: 'OK', withIcon: 'caution' });
  }
}
