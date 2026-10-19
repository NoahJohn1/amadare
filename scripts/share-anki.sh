#!/bin/zsh
# Shares this Mac's Anki with the Amadare iPhone app: AnkiConnect listens on the network instead of
# only on this Mac, and requires an API key, which this script creates once and then keeps.
# Amadare on the Mac and the Quick Actions read the key themselves.
#
#   scripts/share-anki.sh        share Anki and print what to enter on the iPhone
#   scripts/share-anki.sh --off  go back to this Mac only (the key stays set)
set -euo pipefail

ADDON="$HOME/Library/Application Support/Anki2/addons21/2055492159"
if [[ ! -f "$ADDON/meta.json" ]]; then
  echo "AnkiConnect isn't installed. In Anki: Tools → Add-ons → Get Add-ons…, code 2055492159." >&2
  exit 1
fi

BIND=0.0.0.0
[[ "${1:-}" == "--off" ]] && BIND=127.0.0.1

# Anki keeps add-on settings in memory and may write them back, so edit them while it's closed.
WAS_RUNNING=false
if pgrep -xq anki || pgrep -xq Anki; then
  WAS_RUNNING=true
  echo "Quitting Anki to change AnkiConnect's settings…"
  osascript -e 'quit app "Anki"'
  while pgrep -xq anki || pgrep -xq Anki; do sleep 0.5; done
fi

# User settings live under "config" in meta.json, on top of the add-on's config.json defaults.
KEY=$(/usr/bin/python3 - "$ADDON" "$BIND" <<'PY'
import json, secrets, sys
addon, bind = sys.argv[1], sys.argv[2]
with open(f"{addon}/meta.json") as f:
    meta = json.load(f)
with open(f"{addon}/config.json") as f:
    config = json.load(f)
config.update(meta.get("config") or {})
config["webBindAddress"] = bind
if not config.get("apiKey"):
    config["apiKey"] = secrets.token_urlsafe(18)
meta["config"] = config
with open(f"{addon}/meta.json", "w") as f:
    json.dump(meta, f)
print(config["apiKey"])
PY
)

if $WAS_RUNNING || [[ "$BIND" == 0.0.0.0 ]]; then
  open -g -b net.ankiweb.anki
fi
# Amadare reads the key at launch.
if pgrep -xq Amadare; then
  osascript -e 'quit app "Amadare"' 2>/dev/null || true
  echo "Quit Amadare so it picks up the API key; open it again when Anki is up."
fi

if [[ "$BIND" == 127.0.0.1 ]]; then
  echo "Anki is back to this Mac only."
  exit 0
fi

echo
echo "Anki is shared. In Amadare on the iPhone, open Settings and enter:"
echo
echo "  API key:  $KEY"
echo "  Server, any one of these:"
LOCAL_NAME=$(scutil --get LocalHostName 2>/dev/null || true)
[[ -n "$LOCAL_NAME" ]] && echo "    $LOCAL_NAME.local        (same Wi-Fi)"
for iface in en0 en1; do
  IP=$(ipconfig getifaddr $iface 2>/dev/null || true)
  [[ -n "$IP" ]] && echo "    $IP        (same Wi-Fi)"
done
TAILSCALE=/Applications/Tailscale.app/Contents/MacOS/Tailscale
if [[ -x "$TAILSCALE" ]] && TS_IP=$("$TAILSCALE" ip -4 2>/dev/null); then
  echo "    $TS_IP        (anywhere, over Tailscale)"
fi
echo
echo "If macOS asks whether Anki may accept incoming connections, choose Allow."
