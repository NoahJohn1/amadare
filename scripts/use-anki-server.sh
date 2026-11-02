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
