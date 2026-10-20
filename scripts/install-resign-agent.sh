#!/bin/zsh
# Installs a launchd agent that keeps the iPhone app signed: when an iPhone is plugged in, and every half
# hour (which also catches it on the same Wi-Fi), it runs scripts/resign-iphone.sh, which rebuilds and
# reinstalls the app once it's 5 days old. Logs go to ~/Library/Logs/Amadare/resign.log.
#
#   scripts/install-resign-agent.sh            install or update the agent
#   scripts/install-resign-agent.sh --remove   remove it
#
# The agent runs the scripts in this checkout, so keep the repo where it is.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=io.github.noahjohn1.amadare.resign
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN_DIR="$HOME/Library/Application Support/Amadare/bin"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
if [[ ${1:-} == --remove ]]; then
  rm -f "$PLIST" "$BIN_DIR/resign-agent"
  echo "Removed the re-signing agent."
  exit 0
fi

mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/Amadare"
swiftc -O scripts/resign-agent.swift -o "$BIN_DIR/resign-agent"

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN_DIR/resign-agent</string>
    <string>$PWD/scripts/resign-iphone.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>1800</integer>
  <key>LaunchEvents</key>
  <dict>
    <key>com.apple.iokit.matching</key>
    <dict>
      <!-- An iPhone or iPad on USB: Apple's vendor id 0x05ac, product ids 0x12xx. -->
      <key>$LABEL.usb</key>
      <dict>
        <key>IOProviderClass</key><string>IOUSBHostDevice</string>
        <key>idVendor</key><integer>1452</integer>
        <key>idProduct</key><integer>4608</integer>
        <key>idProductMask</key><integer>65280</integer>
        <key>IOMatchLaunchStream</key><true/>
      </dict>
    </dict>
  </dict>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/Amadare/resign-agent.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/Amadare/resign-agent.log</string>
</dict>
</plist>
EOF
plutil -lint -s "$PLIST"
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Installed. Plug in your iPhone (or keep it on the same Wi-Fi) and Amadare stays signed."
echo "Log: ~/Library/Logs/Amadare/resign.log"
