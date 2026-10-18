#!/bin/zsh
# Installs the Anki Quick Actions (Add to Anki, Look Up in Anki, Search Anki) and their keyboard shortcuts.
# The scripts are copied out of ~/Documents: Services run inside whatever app you're in, and reading from
# ~/Documents (iCloud Drive) would ask each of those apps for permission.
set -euo pipefail
cd "$(dirname "$0")/../QuickActions"

DEST="$HOME/Library/Application Support/AnkiQuickAdd"
mkdir -p "$DEST"
cp add-to-anki.js lookup-in-anki.js lookup.html furigana.js kanji-readings.txt "$DEST/"

for wf in workflows/*.workflow; do
  rm -rf "$HOME/Library/Services/${wf:t}"
  ditto --noextattr "$wf" "$HOME/Library/Services/${wf:t}"
done

# Shortcuts: ^ = Control, ~ = Option, @ = Command. Entries for other services are left alone.
shortcut() {
  defaults write pbs NSServicesStatus -dict-add "\"(null) - $1 - runWorkflowAsService\"" \
    "{enabled_context_menu=1;enabled_services_menu=1;key_equivalent=\"$2\";presentation_modes={ContextMenu=1;ServicesMenu=1;};}"
}
shortcut "Add to Anki" '^@a'      # ⌃⌘A
shortcut "Look Up in Anki" '^@l'  # ⌃⌘L, with text selected
shortcut "Search Anki" '~@l'      # ⌥⌘L, empty search

/System/Library/CoreServices/pbs -flush
/System/Library/CoreServices/pbs -update
echo "Installed. Restart an app if a shortcut doesn't work in it yet."
