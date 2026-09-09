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

# Sparkle ships for both architectures, in every language, with its headers. None of that is
# needed inside an arm64-only app: dropping it takes the framework from 3.0 MB to about 1.5 MB.
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
rm -rf "$sparkle/Headers" "$sparkle/PrivateHeaders" "$sparkle/Modules"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Headers" \
       "$app/Contents/Frameworks/Sparkle.framework/PrivateHeaders" \
       "$app/Contents/Frameworks/Sparkle.framework/Modules"
for binary in \
  "$sparkle/Sparkle" \
  "$sparkle/Autoupdate" \
  "$sparkle/Updater.app/Contents/MacOS/Updater" \
  "$sparkle/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
  "$sparkle/XPCServices/Installer.xpc/Contents/MacOS/Installer"; do
  [ -f "$binary" ] || continue
  lipo -thin arm64 "$binary" -output "$binary.arm64" 2>/dev/null && mv "$binary.arm64" "$binary"
done
# Sparkle's own dialogs are the only text the app shows. English and Japanese are kept; the
# other 34 languages would only be carried around.
find "$sparkle/Resources" -maxdepth 1 -name "*.lproj" \
  ! -name "en.lproj" ! -name "ja.lproj" -exec rm -rf {} +

# The bundled framework is signed from the inside out: signing the app first and then changing
# something inside it leaves the app's own signature broken.
for helper in XPCServices/Downloader.xpc XPCServices/Installer.xpc Autoupdate Updater.app; do
  codesign --force --sign - "$app/Contents/Frameworks/Sparkle.framework/Versions/B/$helper" 2>/dev/null || true
done
codesign --force --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"

echo "built $app ($(du -sh "$app" | cut -f1))"
