# Macview

A macOS image viewer where the window is the image.

No toolbar, no sidebar, no title bar. The window opens at the size of the picture,
sits on a neutral dark ground, and steps through the rest of the folder with the arrow keys.

## Why

Existing minimal viewers carry their own toolkit and their own decoders. qView, for one,
ships 117 MB of Qt frameworks to show a JPEG. Macview links nothing but the system:
AppKit, CoreGraphics, ImageIO, QuartzCore. The bundle is under 200 KB.

## Formats

Whatever ImageIO reads, Macview reads — JPEG, PNG, GIF, TIFF, HEIC, WebP, AVIF, JPEG XL
and the camera RAW formats among them. There is no bundled decoder and no format list to
maintain.

## Keys

| Key | |
| --- | --- |
| → ↓ Space | next image |
| ← ↑ Delete | previous image |
| Home / End | first / last image |
| Esc | close |
| ⌘O | open a file or folder |

Files can also be dropped on the window.

## Build

```
./scripts/build.sh          # dist/Macview.app
swift run Macview --selftest # fitting, ordering and decoding checks
```

Requires macOS 14 Sonoma or later — the floor where WebP, AVIF and JPEG XL are all in
ImageIO, so no format needs a fallback path. Built for arm64; a universal binary needs
full Xcode rather than the Command Line Tools alone.

## Not included

Saving, exporting, editing, rotating, renaming and deleting. This is a viewer.
