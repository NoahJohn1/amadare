#!/bin/zsh
# Generates iOS/Amadare.xcodeproj and builds the iPhone app for the Simulator.
# Open iOS/Amadare.xcodeproj in Xcode afterwards to run it on a simulator or your iPhone.
# Needs XcodeGen: brew install xcodegen
set -euo pipefail
cd "$(dirname "$0")/.."

ICON="iOS/Amadare/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
[[ -f "$ICON" ]] || swift scripts/make-icon.swift "$ICON" --ios

xcodegen generate --spec iOS/project.yml --quiet
# Build output lives outside ~/Documents, like the Mac app's (see build-app.sh).
xcodebuild -project iOS/Amadare.xcodeproj -scheme AmadareiOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$HOME/Library/Caches/Amadare/ios-build" \
  -quiet build
echo "Built. Open iOS/Amadare.xcodeproj to run it."
