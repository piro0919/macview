#!/bin/bash
# Assembles dist/Macview.app from a release build.
# arm64 only: a universal build needs full Xcode for xcbuild, the Command Line Tools alone cannot.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Macview.app"

swift build -c release --package-path "$root"
binary="$(swift build -c release --package-path "$root" --show-bin-path)/Macview"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Macview"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"

echo "built $app ($(du -sh "$app" | cut -f1))"
