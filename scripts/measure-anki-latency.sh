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
