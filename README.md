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

## Animation

Animated GIF, APNG, animated WebP and HEICS play on their own frame delays, read from the
file. Frames are decoded one at a time as they are needed rather than unpacked into memory
up front, so a long animation costs no more to hold than a still.

## The window

The window is fitted to the image once, when it opens, and is then left alone — stepping
through a folder never moves or reshapes it. Images of a different shape sit centred on the
ground. The fitted window is held between a fifth and seven tenths of the screen.

These are qView's own defaults (`windowresizemode` 1, 20%, 70%) and its ground colour
(#212121), matched deliberately. No qView code is used: it is GPL-3.0 and this is not.

## Keys

| Key | |
| --- | --- |
| → ↓ Space | next image |
| ← ↑ Delete | previous image |
| Home / End | first / last image |
| Esc | close |
| ⌘O | open a file or folder |

Files can also be dropped on the window.

## Icon

`scripts/build-icon.py` turns `Resources/icon/source.png` into `Resources/AppIcon.icns`.
The drawing arrives full-bleed on the app's charcoal; the script lifts the picture off that
ground, grows it to Apple's 824pt body on a 1024pt canvas, and rounds it, so the corners are
transparent the way macOS expects. Needs Pillow.

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
