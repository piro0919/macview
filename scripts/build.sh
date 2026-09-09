#!/bin/bash
# Assembles dist/Macview.app from a release build.
# arm64 only: a universal build needs full Xcode for xcbuild, the Command Line Tools alone cannot.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app="$root/dist/Macview.app"
sparkle_version="2.9.5"

# Sparkle carries the automatic updates. The framework is 3 MB, so it is fetched rather than
# committed; Vendor/ is outside git. Its bin/ holds generate_appcast, which scripts/release.sh uses.
if [ ! -d "Vendor/Sparkle.framework" ]; then
  echo "fetching Sparkle ${sparkle_version}..."
  mkdir -p Vendor
  tmp="$(mktemp -d)"
  curl -sL -o "$tmp/sparkle.tar.xz" \
    "https://github.com/sparkle-project/Sparkle/releases/download/${sparkle_version}/Sparkle-${sparkle_version}.tar.xz"
  tar xf "$tmp/sparkle.tar.xz" -C "$tmp"
  cp -R "$tmp/Sparkle.framework" Vendor/
  cp -R "$tmp/bin" Vendor/
  rm -rf "$tmp"
fi

swift build -c release --package-path "$root"
binary="$(swift build -c release --package-path "$root" --show-bin-path)/Macview"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$binary" "$app/Contents/MacOS/Macview"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp -R Vendor/Sparkle.framework "$app/Contents/Frameworks/"

# The bundled framework is signed from the inside out: signing the app first and then changing
# something inside it leaves the app's own signature broken.
for helper in XPCServices/Downloader.xpc XPCServices/Installer.xpc Autoupdate Updater.app; do
  codesign --force --sign - "$app/Contents/Frameworks/Sparkle.framework/Versions/B/$helper" 2>/dev/null || true
done
codesign --force --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"

echo "built $app ($(du -sh "$app" | cut -f1))"
