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

fail() {
  echo "error: $*" >&2
  exit 1
}

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "the version must look like 1.2.3 (got: ${version})"
fi

# The release commit below takes only the version files. Anything else lying around would either
# be left out of the tagged commit or, worse, be swept into it — so a dirty tree stops here.
if [ -n "$(git status --porcelain)" ]; then
  git status --short >&2
  fail "the working tree has uncommitted changes; commit or stash them first"
fi
if [ "$(git branch --show-current)" != "main" ]; then
  fail "releases are cut from main"
fi
if git rev-parse -q --verify "refs/tags/v${version}" >/dev/null ||
  git ls-remote --exit-code --tags origin "refs/tags/v${version}" >/dev/null; then
  fail "tag v${version} already exists"
fi

# The release notes are this version's section of CHANGELOG.md. --generate-notes only finds
# pull requests, and everything here goes straight to main, so it produced a bare
# "Full Changelog" link.
notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT
awk -v head="## [${version}]" '
  /^## / { if (found) exit; if (index($0, head) == 1) { found = 1; next } }
  found { print }
' CHANGELOG.md >"$notes"
if ! grep -q '[^[:space:]]' "$notes"; then
  fail "CHANGELOG.md has no \"## [${version}]\" section, or it is empty"
fi

# Sparkle compares CFBundleVersion, not the version people read, so it has to keep climbing.
build_number=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" Resources/Info.plist
./scripts/build.sh

built="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")"
[ "$built" = "$version" ] || fail "the built app says ${built}, expected ${version}"
codesign --verify --deep --strict "$app" || fail "the built app's signature does not verify"

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

git add Resources/Info.plist
git commit -q -m "chore(release): ${version}"
git tag "v${version}"
git push -q origin main
git push -q origin "v${version}"

gh release create "v${version}" \
  --repo "$repo" \
  --title "Macview ${version}" \
  --notes-file "$notes" \
  "dist/${dmg}" "dist/update/${zip}" "dist/update/appcast.xml"

echo "released: https://github.com/${repo}/releases/tag/v${version}"
shasum -a 256 "dist/${dmg}"
