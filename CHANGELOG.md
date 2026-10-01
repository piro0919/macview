# Changelog

Notable changes to Macview. `scripts/release.sh` publishes the section for the version being
released as its release notes, and stops if that section is missing or empty — so before
releasing, rename `Unreleased` to `[x.y.z] - YYYY-MM-DD` and commit.

Versions up to 0.3.3 predate this file; their history is in `git log`.

## [Unreleased]

### Fixed

- Images that cannot be decoded now show "Can't open this image" with the file name instead
  of a blank window.

### Internal

- CI runs swift-format lint, the build, the self test and the landing-page checks.
- The build verifies the SHA-256 of the Sparkle archive it downloads.
- The release script refuses a dirty working tree, an existing tag, a version the built app
  does not carry, or a missing changelog section, and commits only the version file.
