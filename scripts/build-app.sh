#!/bin/zsh
# Builds Amadare.app and installs it to ~/Applications.
# Build output lives outside ~/Documents: the file provider there adds attributes codesign rejects.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$HOME/Library/Caches/Amadare"
SCRATCH="$WORK/build"
swift build -c release --product Amadare --scratch-path "$SCRATCH"
BIN="$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)/Amadare"

ICONS="$WORK/icons"
if [[ ! -f "$ICONS/AppIcon.icns" ]]; then
  mkdir -p "$ICONS/AppIcon.iconset"
  swift scripts/make-icon.swift "$ICONS/icon-1024.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICONS/icon-1024.png" --out "$ICONS/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$ICONS/icon-1024.png" --out "$ICONS/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONS/AppIcon.iconset" -o "$ICONS/AppIcon.icns"
fi

APP="$WORK/Amadare.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Amadare"
cp "$ICONS/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Amadare</string>
  <key>CFBundleDisplayName</key><string>Amadare</string>
  <key>CFBundleIdentifier</key><string>io.github.noahjohn1.amadare</string>
  <key>CFBundleExecutable</key><string>Amadare</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"

DEST="$HOME/Applications/Amadare.app"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
codesign -v "$DEST"
echo "Installed $DEST"
