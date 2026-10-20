#!/bin/zsh
# Re-signs and reinstalls the iPhone app when it's due: 5 days after the last install, or 2 days before
# its 7-day profile runs out. The agent from scripts/install-resign-agent.sh runs this when an iPhone is
# plugged in and every half hour (which also catches an iPhone on the same Wi-Fi). Running it yourself does
# the same; --force installs even when it isn't due.
#
# Logs to ~/Library/Logs/Amadare/resign.log and posts a notification when it installs or something needs you.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DUE_AFTER=$((5 * 86400))
EXPIRY_MARGIN=$((2 * 86400))
STATE_DIR="$HOME/Library/Application Support/Amadare/iphone"
LOG_DIR="$HOME/Library/Logs/Amadare"
FORCE=0 USB=0
for arg; do case $arg in --force) FORCE=1;; --usb) USB=1;; esac; done

mkdir -p "$STATE_DIR" "$LOG_DIR"
exec > >(while IFS= read -r line; do print -r -- "$(date '+%F %T') $line"; done | tee -a "$LOG_DIR/resign.log") 2>&1

log() { print -r -- "$*" }
notify() {
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' "$1" "$2" >/dev/null 2>&1
}
# The same problem is only notified once every 6 hours, so a half-hourly retry doesn't nag.
notify_failure() {
  local key=$1 msg=$2 file="$STATE_DIR/.notified-$1" now=$(date +%s)
  if [[ ! -f $file ]] || (( now - $(<$file) > 6 * 3600 )); then
    notify "Amadare couldn't renew on your iPhone" "$msg"
    print $now >"$file"
  fi
}

# One run at a time; a leftover lock older than an hour is from a run that died.
LOCK="$STATE_DIR/.running"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [[ -n $(find "$LOCK" -maxdepth 0 -mmin +60 2>/dev/null) ]]; then rm -rf "$LOCK"; mkdir "$LOCK"
  else exit 0; fi
fi
TMP=$(mktemp -d -t amadare-resign)
trap 'rm -rf "$LOCK" "$TMP"' EXIT

DEVICES='.result.devices[] | select(.hardwareProperties.reality == "physical"
  and .hardwareProperties.platform == "iOS" and .connectionProperties.pairingState == "paired"
  and .connectionProperties.transportType != null)'
connected() {
  xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null 2>&1 &&
    jq -r "$DEVICES | .hardwareProperties.udid" "$TMP/devices.json"
}
UDIDS=($(connected))
# A freshly plugged-in iPhone takes a few seconds to show up.
if (( USB )); then
  for _ in {1..12}; do (( ${#UDIDS} )) && break; sleep 5; UDIDS=($(connected)); done
fi
(( ${#UDIDS} )) || exit 0

for UDID in $UDIDS; do
  NAME=$(jq -r "$DEVICES | select(.hardwareProperties.udid == \"$UDID\") | .deviceProperties.name" "$TMP/devices.json")
  LAST_INSTALL=0 PROFILE_EXPIRES=0
  [[ -f "$STATE_DIR/$UDID" ]] && source "$STATE_DIR/$UDID"
  NOW=$(date +%s)
  if (( !FORCE && NOW - LAST_INSTALL < DUE_AFTER &&
        (PROFILE_EXPIRES == 0 || PROFILE_EXPIRES - NOW > EXPIRY_MARGIN) )); then
    (( USB )) && log "$NAME: not due (installed $(date -r $LAST_INSTALL '+%F %R'))."
    continue
  fi

  log "$NAME: renewing (last install: $( (( LAST_INSTALL )) && date -r $LAST_INSTALL '+%F %R' || echo never))."
  # A locked iPhone can't be installed to. Ask once, then wait up to 10 minutes for it to be unlocked.
  for attempt in {1..40}; do
    rm -f "$TMP/lock.json"; xcrun devicectl device info lockState --device "$UDID" --json-output "$TMP/lock.json" >/dev/null 2>&1
    [[ $(jq -r .result.passcodeRequired "$TMP/lock.json" 2>/dev/null) == true ]] || break
    (( attempt == 1 )) && { log "$NAME is locked; waiting for it to be unlocked."
      notify "Unlock your iPhone" "Amadare needs it unlocked to renew the app." }
    sleep 15
    [[ $(connected) == *$UDID* ]] || { log "$NAME went away."; continue 2; }
  done
  scripts/install-iphone.sh "$UDID"
  STATUS=$?

  case $STATUS in
    0) source "$STATE_DIR/$UDID"
       rm -f "$STATE_DIR"/.notified-*(N)
       notify "Amadare renewed" "Installed on $NAME, good until $(date -r $PROFILE_EXPIRES '+%a %b %-d')." ;;
    2) log "$NAME wasn't reachable; will try again later." ;;
    3) log "$NAME stayed locked; will try again later." ;;
    4) notify_failure devmode "Turn on Developer Mode: Settings → Privacy & Security → Developer Mode." ;;
    5) notify_failure signin "Sign in to your Apple ID in Xcode → Settings → Accounts." ;;
    6) notify_failure limit "Apple's free-account app limit was hit. See ~/Library/Logs/Amadare/resign.log." ;;
    *) notify_failure build "The build or install failed. See ~/Library/Logs/Amadare/resign.log." ;;
  esac
done
