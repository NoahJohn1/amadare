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
