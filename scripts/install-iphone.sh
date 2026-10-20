#!/bin/zsh
# Builds the iPhone app for your iPhone, signs it with your free Personal Team and installs it.
# A free team's provisioning profile lasts 7 days, so this needs re-running every week; the agent from
# scripts/install-resign-agent.sh does that for you whenever the iPhone is around.
#
#   scripts/install-iphone.sh [udid]
#
# With no udid it uses the first iPhone that's paired and connected (by cable or over Wi-Fi).
# The team id comes from AMADARE_TEAM, else iOS/Signing.local.xcconfig (not checked in), else the Personal
# Team Xcode is signed in to, which is then saved there.
# Exit codes: 0 installed, 2 no iPhone, 3 iPhone locked, 4 Developer Mode off, 5 Xcode not signed in,
# 6 app ID limit, 1 anything else.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BUNDLE_ID=io.github.noahjohn1.amadare
STATE_DIR="$HOME/Library/Application Support/Amadare/iphone"
DERIVED="$HOME/Library/Caches/Amadare/ios-device-build"
TEAM_FILE=iOS/Signing.local.xcconfig
TMP=$(mktemp -d -t amadare-iphone)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: $2" >&2; exit $1 }

# --- The iPhone ---------------------------------------------------------------------------------------
xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null 2>&1 ||
  fail 1 "devicectl couldn't list devices"
# Paired iPhones/iPads seen over USB or Wi-Fi. A Wi-Fi connection sleeps when idle; devicectl wakes it.
DEVICES='.result.devices[] | select(.hardwareProperties.reality == "physical"
  and .hardwareProperties.platform == "iOS" and .connectionProperties.pairingState == "paired"
  and .connectionProperties.transportType != null)'
UDID=${1:-$(jq -r "[$DEVICES | .hardwareProperties.udid][0] // empty" "$TMP/devices.json")}
[[ -n "$UDID" ]] || fail 2 "no iPhone connected. Plug it in (or keep it on the same Wi-Fi) and unlock it."
DEVICE=$(jq -c "$DEVICES | select(.hardwareProperties.udid == \"$UDID\")" "$TMP/devices.json")
[[ -n "$DEVICE" ]] || fail 2 "iPhone $UDID isn't connected."
NAME=$(jq -r .deviceProperties.name <<<"$DEVICE")
[[ $(jq -r .deviceProperties.developerModeStatus <<<"$DEVICE") != disabled ]] ||
  fail 4 "Developer Mode is off on $NAME. Turn it on in Settings → Privacy & Security → Developer Mode."

lock_state() {
  rm -f "$TMP/lock.json"
  xcrun devicectl device info lockState --device "$UDID" --json-output "$TMP/lock.json" >/dev/null 2>&1 &&
    jq -r .result.passcodeRequired "$TMP/lock.json"
}
locked() { [[ $(lock_state) == true ]] }
# Also brings up the connection, so the install can reach the iPhone.
xcrun devicectl device info details --device "$UDID" >/dev/null 2>&1 ||
  fail 2 "$NAME isn't reachable. Plug it in or put it on the same Wi-Fi as this Mac."

# --- The team -----------------------------------------------------------------------------------------
TEAM=${AMADARE_TEAM:-}
[[ -z "$TEAM" && -f "$TEAM_FILE" ]] && TEAM=$(sed -nE 's/^DEVELOPMENT_TEAM *= *([A-Z0-9]+).*/\1/p' "$TEAM_FILE")
if [[ -z "$TEAM" ]]; then
  TEAM=$(defaults export com.apple.dt.Xcode - 2>/dev/null |
    plutil -extract IDEProvisioningTeamByIdentifier json -o - - 2>/dev/null |
    jq -r '[.[][] | select(.isFreeProvisioningTeam == true) | .teamID] | unique | .[0] // empty')
  [[ -n "$TEAM" ]] ||
    fail 5 "Xcode isn't signed in to an Apple ID. Open Xcode → Settings → Accounts, add your Apple ID, then try again."
  print "// Your Personal Team, found in Xcode's accounts. Not checked in.\nDEVELOPMENT_TEAM = $TEAM" >"$TEAM_FILE"
  echo "Using Personal Team $TEAM (saved in $TEAM_FILE)."
fi

# --- Build and sign -----------------------------------------------------------------------------------
echo "Building Amadare for $NAME…"
ICON="iOS/Amadare/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
[[ -f "$ICON" ]] || swift scripts/make-icon.swift "$ICON" --ios || fail 1 "couldn't make the app icon"
xcodegen generate --spec iOS/project.yml --quiet || fail 1 "xcodegen failed"
# Xcode reuses its cached profile until it has expired, so a renewal would install one with only a day
# or two left. Dropping it when it has under 6 days left makes Xcode fetch a fresh 7-day one.
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
for profile in "$PROFILES"/*.mobileprovision(N); do
  security cms -D -i "$profile" >"$TMP/profile.plist" 2>/dev/null || continue
  [[ $(plutil -extract Entitlements.application-identifier raw -o - "$TMP/profile.plist" 2>/dev/null) == "$TEAM.$BUNDLE_ID" ]] || continue
  expires=$(plutil -extract ExpirationDate raw -o - "$TMP/profile.plist")
  (( $(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$expires" +%s) - $(date +%s) < 6 * 86400 )) && rm -f "$profile"
done

# Built for any iPhone, so the build needs no connection to this one (nor for it to be unlocked); the
# profile lists the iPhones registered to the team. Only an iPhone that isn't registered yet is built for
# directly, which registers it. Always the same bundle id, so the free team's 10-new-app-IDs-a-week limit
# is never touched again.
build() {
  xcodebuild -project iOS/Amadare.xcodeproj -scheme AmadareiOS -configuration Debug \
    -destination "$1" -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_STYLE=Automatic \
    -quiet build >"$TMP/build.log" 2>&1
}
provisioned() {
  security cms -D -i "$DERIVED/Build/Products/Debug-iphoneos/Amadare.app/embedded.mobileprovision" 2>/dev/null |
    plutil -extract ProvisionedDevices json -o - - 2>/dev/null | grep -q "\"$UDID\""
}
build "generic/platform=iOS"
BUILD_STATUS=$?
if (( BUILD_STATUS == 0 )) && ! provisioned; then
  echo "Registering $NAME with your team…"
  locked && fail 3 "$NAME is locked. Unlock it and the app will be installed."
  build "id=$UDID"
  BUILD_STATUS=$?
fi
if (( BUILD_STATUS != 0 )); then
  tail -40 "$TMP/build.log" >&2
  grep -qiE "maximum number of apps|app ID limit|10 App IDs|cannot be registered to your development team" "$TMP/build.log" &&
    fail 6 "Apple's free-account limit on new app IDs was hit. It clears within 7 days; nothing to do but wait."
  grep -qiE "No Accounts|no account for team|sign in|not logged in|session has expired|Unable to log in|login details|were rejected" "$TMP/build.log" &&
    fail 5 "Xcode's Apple ID sign-in is missing or expired. Open Xcode → Settings → Accounts and sign in again."
  grep -qiE "needs to be unlocked|device is locked" "$TMP/build.log" &&
    fail 3 "$NAME is locked. Unlock it and the app will be installed."
  grep -qiE "Timed out waiting for all destinations" "$TMP/build.log" &&
    fail 2 "$NAME's connection to this Mac isn't working right now. It'll be tried again later."
  grep -qiE "developer mode is (off|disabled)|enable developer mode" "$TMP/build.log" &&
    fail 4 "Developer Mode is off on $NAME. Turn it on in Settings → Privacy & Security → Developer Mode."
  fail 1 "the build failed (see above)."
fi
APP="$DERIVED/Build/Products/Debug-iphoneos/Amadare.app"
[[ -d "$APP" ]] || fail 1 "the build didn't produce $APP"
EXPIRES=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null |
  plutil -extract ExpirationDate raw -o - - 2>/dev/null)
EXPIRES_EPOCH=$( [[ -n "$EXPIRES" ]] && date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES" +%s 2>/dev/null || echo 0)

# --- Install ------------------------------------------------------------------------------------------
if locked; then
  fail 3 "$NAME is locked. Unlock it and the app will be installed."
fi
echo "Installing on $NAME…"
if ! xcrun devicectl device install app --device "$UDID" "$APP" >"$TMP/install.log" 2>&1; then
  cat "$TMP/install.log" >&2
  grep -qiE "locked|10003" "$TMP/install.log" && fail 3 "$NAME is locked. Unlock it and the app will be installed."
  grep -qiE "developer mode" "$TMP/install.log" &&
    fail 4 "Developer Mode is off on $NAME. Turn it on in Settings → Privacy & Security → Developer Mode."
  grep -qiE "maximum number of|3 apps|installed apps" "$TMP/install.log" &&
    fail 6 "A free Apple ID can have only 3 sideloaded apps on a phone at once. Delete one, then try again."
  fail 1 "installing on $NAME failed (see above)."
fi

mkdir -p "$STATE_DIR"
print "LAST_INSTALL=$(date +%s)\nPROFILE_EXPIRES=$EXPIRES_EPOCH" >"$STATE_DIR/$UDID"
echo "Installed on $NAME. Signed until ${EXPIRES:-unknown}."
