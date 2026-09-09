#!/usr/bin/env python3
"""Turns Resources/icon/source.png into Resources/AppIcon.icns.

The drawing arrives sitting on the app's own charcoal with a wide margin around it. The
margin is trimmed away so the picture fills the icon, and what is left is written out
fully opaque, square, corners and all: macOS rounds app icons itself, and an icon that
arrives pre-rounded gets the system shape laid over the top of its own.
"""
import pathlib
import subprocess
from PIL import Image, ImageChops

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources" / "icon" / "source.png"
ICNS = ROOT / "Resources" / "AppIcon.icns"

CANVAS = 1024
GROUND = (33, 33, 33)  # #212121, the charcoal the drawing sits on.
TOLERANCE = 24


def picture_bounds(image):
    """The drawn picture, without the charcoal around it."""
    pixels = image.convert("RGB")
    ground = Image.new("RGB", pixels.size, GROUND)
    difference = ImageChops.difference(pixels, ground).convert("L")
    box = difference.point(lambda value: 255 if value > TOLERANCE else 0).getbbox()
    if box is None:
        raise SystemExit("the source is entirely background")
    return box


def main():
    source = Image.open(SOURCE).convert("RGB")
    canvas = source.crop(picture_bounds(source)).resize((CANVAS, CANVAS), Image.LANCZOS)

    iconset = ROOT / "Resources" / "AppIcon.iconset"
    subprocess.run(["rm", "-rf", str(iconset)], check=True)
    iconset.mkdir(parents=True)
    for size in (16, 32, 128, 256, 512):
        canvas.resize((size, size), Image.LANCZOS).save(iconset / f"icon_{size}x{size}.png", optimize=True)
        canvas.resize((size * 2, size * 2), Image.LANCZOS).save(iconset / f"icon_{size}x{size}@2x.png", optimize=True)

    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS)], check=True)
    subprocess.run(["rm", "-rf", str(iconset)], check=True)
    print(f"built {ICNS.relative_to(ROOT)} ({ICNS.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
