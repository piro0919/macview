#!/usr/bin/env python3
"""Turns Resources/icon/source.png into Resources/AppIcon.icns.

The drawing arrives as a full-bleed square on the app's own charcoal. macOS wants the
opposite: a rounded body with transparent corners, sized to Apple's grid — an 824pt body
centred on a 1024pt canvas. So the picture is lifted off its ground, grown to fill that
body, and rounded.
"""
import pathlib
import subprocess
from PIL import Image, ImageChops, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources" / "icon" / "source.png"
ICNS = ROOT / "Resources" / "AppIcon.icns"

CANVAS = 1024
BODY = 824
RADIUS = 185  # Apple's corner radius at this body size.
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
    source = Image.open(SOURCE).convert("RGBA")
    body = source.crop(picture_bounds(source)).resize((BODY, BODY), Image.LANCZOS)

    mask = Image.new("L", (BODY, BODY), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, BODY - 1, BODY - 1], radius=RADIUS, fill=255)
    body.putalpha(mask)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(body, ((CANVAS - BODY) // 2, (CANVAS - BODY) // 2), body)

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
