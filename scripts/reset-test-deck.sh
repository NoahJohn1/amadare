#!/bin/zsh
# Makes every card in a deck due today again, so it can be reviewed in Recall repeatedly.
# Usage: scripts/reset-test-deck.sh [deck]   (default: Inbox; Anki must be open)
set -euo pipefail
DECK="${1:-Inbox}"
python3 -I - "$DECK" <<'PY'
import json, sys, urllib.request

def anki(action, **params):
    request = urllib.request.Request('http://127.0.0.1:8765',
                                     json.dumps({'action': action, 'version': 6, 'params': params}).encode())
    response = json.load(urllib.request.urlopen(request))
    if response['error']:
        sys.exit(f'{action}: {response["error"]}')
    return response['result']

deck = sys.argv[1]
query = 'deck:"%s"' % deck.replace('"', '\\"')
cards = anki('findCards', query=query)
if cards:
    anki('setDueDate', cards=cards, days='0')
print(f'{len(cards)} cards in {deck} are due now.')
PY
