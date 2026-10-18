// Source: Ankani repo, QuickActions/. Edit it there and run scripts/install-quick-actions.sh; installed copies get overwritten.
// Search the Anki collection like a dictionary: a floating window with a search box, matching notes and their details.
// Called by the "Look Up in Anki" Quick Action with the selection in $ANKI_QUERY, or by "Anki Lookup" with no selection.
// The UI is lookup.html in a web view; it talks to AnkiConnect (http://127.0.0.1:8765) directly.
ObjC.import('stdlib');
ObjC.import('Cocoa');
ObjC.import('WebKit');

const DIR = $.getenv('HOME') + '/Library/Application Support/AnkiQuickAdd';

function run() {
  let query = '';
  try { query = $.getenv('ANKI_QUERY') || ''; } catch (e) {} // unset when opened without a selection
  query = query.replace(/\s+/g, ' ').trim().slice(0, 200);

  const nsapp = $.NSApplication.sharedApplication;
  nsapp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  // osascript has no menu bar, so ⌘V/⌘C/⌘X/⌘A/⌘Z/⌘W do nothing without menus to route them.
  const mainMenu = $.NSMenu.alloc.init;
  const editItem = $.NSMenuItem.alloc.init;
  mainMenu.addItem(editItem);
  const editMenu = $.NSMenu.alloc.initWithTitle('Edit');
  [['Undo', 'undo:', 'z'], ['Redo', 'redo:', 'Z'], null,
   ['Cut', 'cut:', 'x'], ['Copy', 'copy:', 'c'], ['Paste', 'paste:', 'v'], ['Select All', 'selectAll:', 'a'], null,
   ['Close', 'performClose:', 'w']]
    .forEach(i => i ? editMenu.addItemWithTitleActionKeyEquivalent(i[0], i[1], i[2]) : editMenu.addItem($.NSMenuItem.separatorItem));
  editItem.submenu = editMenu;
  nsapp.mainMenu = mainMenu;

  if (!$.AnkiLookupHandler) {
    ObjC.registerSubclass({
      name: 'AnkiLookupHandler',
      // No protocols list: JXA can't look up WKScriptMessageHandler, and AppKit/WebKit only check for the methods.
      protocols: [],
      methods: {
        // The page posts 'close' on Esc.
        'userContentController:didReceiveScriptMessage:': {
          types: ['void', ['id', 'id']],
          implementation: function (controller, message) { if (ObjC.unwrap(message.body) === 'close') win.performClose(null); }
        },
        'windowWillClose:': {
          types: ['void', ['id']],
          implementation: function () { $.NSApplication.sharedApplication.stopModal; }
        }
      }
    });
  }
  const handler = $.AnkiLookupHandler.alloc.init;

  const config = $.WKWebViewConfiguration.alloc.init;
  config.userContentController.addScriptMessageHandlerName(handler, 'lookup');

  const W = 760, H = 480;
  const style = $.NSWindowStyleMaskTitled | $.NSWindowStyleMaskClosable | $.NSWindowStyleMaskResizable;
  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, W, H), style, $.NSBackingStoreBuffered, false);
  win.title = 'Anki Lookup';
  win.releasedWhenClosed = false;
  win.level = $.NSFloatingWindowLevel;
  win.minSize = $.NSMakeSize(480, 280);
  win.delegate = handler;

  const web = $.WKWebView.alloc.initWithFrameConfiguration($.NSMakeRect(0, 0, W, H), config);
  web.autoresizingMask = $.NSViewWidthSizable | $.NSViewHeightSizable;
  win.contentView = web;

  // The http://localhost origin is on AnkiConnect's default CORS allow-list, so the page can fetch from it.
  const template = $.NSString.stringWithContentsOfFileEncodingError(DIR + '/lookup.html', $.NSUTF8StringEncoding, null).js;
  const furiganaJs = $.NSString.stringWithContentsOfFileEncodingError(DIR + '/furigana.js', $.NSUTF8StringEncoding, null).js;
  const html = template.replace('__INITIAL__', () => JSON.stringify(query).replace(/</g, '\\u003c'))
    .replace('__FURIGANA_JS__', () => furiganaJs);
  web.loadHTMLStringBaseURL(html, $.NSURL.URLWithString('http://localhost/'));

  win.center;
  win.makeKeyAndOrderFront(null);
  win.makeFirstResponder(web);
  // macOS 14+ may ignore the old call when another app is frontmost; NSApp.activate is the newer API.
  try { nsapp.activate; } catch (e) {}
  nsapp.activateIgnoringOtherApps(true);
  nsapp.runModalForWindow(win);
}
