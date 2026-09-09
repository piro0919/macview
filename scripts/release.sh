#!/bin/bash
# Puts out one version: builds, checks, packs, signs the update, and pushes it to GitHub.
#
#   ./scripts/release.sh 0.3.0
#
# The signing key lives in the login keychain and is shared with Nonja, Gocci and Konechi.
# Losing it means no update can ever reach the copies already installed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="${1:-}"
if [ -z "$version" ]; then
  echo "usage: ./scripts/release.sh <version>   e.g. ./scripts/release.sh 0.3.0" >&2
  exit 1
fi

repo="piro0919/macview"
app="dist/Macview.app"
zip="Macview-${version}.zip"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" Resources/Info.plist
./scripts/build.sh

# Whatever is about to be handed out is checked first.
"$app/Contents/MacOS/Macview" --selftest

# The update itself travels as a zip, which is what Sparkle takes. It is kept apart from the
# dmg: generate_appcast stops on two archives of the same version sitting side by side.
rm -rf dist/update && mkdir -p dist/update
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/update/$zip"

./scripts/dmg.sh > /dev/null
dmg="Macview-${version}.dmg"

# Signs the update. The key is read from the login keychain, which asks for permission the
# first time.
./Vendor/bin/generate_appcast \
  --download-url-prefix "https://github.com/${repo}/releases/download/v${version}/" \
  dist/update

git add -A
git commit -q -m "chore(release): ${version}"
git tag "v${version}"
git push -q origin main
git push -q origin "v${version}"

gh release create "v${version}" \
  --repo "$repo" \
  --title "Macview ${version}" \
  --generate-notes \
  "dist/${dmg}" "dist/update/${zip}" "dist/update/appcast.xml"

echo "released: https://github.com/${repo}/releases/tag/v${version}"
shasum -a 256 "dist/${dmg}"
