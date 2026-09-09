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


def flatten(image):
    """Drops the drawing onto a small palette.

    The artwork is three flat colours, but it arrives with a pixel or two of noise across every
    flat field - enough to defeat PNG entirely: the 1024 was 751 KB. Reducing to 64 colours,
    chosen from the picture rather than from a fixed grid, leaves the colours where they were
    (the teal moves by one value) and takes the same image to 20 KB.
    """
    return image.quantize(colors=64, method=Image.FASTOCTREE, dither=Image.NONE)


def main():
    source = Image.open(SOURCE).convert("RGB")
    canvas = source.crop(picture_bounds(source)).resize((CANVAS, CANVAS), Image.LANCZOS)

    iconset = ROOT / "Resources" / "AppIcon.iconset"
    subprocess.run(["rm", "-rf", str(iconset)], check=True)
    iconset.mkdir(parents=True)
    for size in (16, 32, 128, 256, 512):
        for name, side in ((f"icon_{size}x{size}.png", size), (f"icon_{size}x{size}@2x.png", size * 2)):
            flatten(canvas.resize((side, side), Image.LANCZOS)).save(iconset / name, optimize=True)

    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS)], check=True)
    subprocess.run(["rm", "-rf", str(iconset)], check=True)
    print(f"built {ICNS.relative_to(ROOT)} ({ICNS.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
