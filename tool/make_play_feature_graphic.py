#!/usr/bin/env python3
"""Render the 1024x500 Google Play feature graphic.

Play requires a 24-bit PNG or JPEG with no alpha channel, so the icon is
composited onto the gradient and the result is flattened to RGB before it is
written out.

Text is auto-fitted rather than set at a fixed size: the title is long enough
that a hard-coded size silently overflows the canvas and gets clipped.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1024, 500
MARGIN = 64

# Brand palette lifted from lib/core/theme/app_theme.dart.
DEEP = (11, 92, 69)      # 0xFF0B5C45
TEAL = (29, 158, 117)    # 0xFF1D9E75
GOLD = (184, 134, 11)    # 0xFFB8860B

TITLE = "Tajweed Practice"
SUBTITLE = "Read, Listen & Learn Tajweed"

REPO = Path(__file__).resolve().parents[1]
ICON = REPO / "assets" / "app_icon" / "app_icon_1024.png"
OUT = REPO / "release" / "play" / "play-feature-graphic-1024x500.png"

FONTS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/SFNS.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONTS:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    raise SystemExit("no usable TrueType font found")


def fit_font(
    draw: ImageDraw.ImageDraw, text: str, max_width: int, start: int, floor: int
) -> ImageFont.FreeTypeFont:
    """Largest font size at or below `start` whose text fits `max_width`."""
    for size in range(start, floor - 1, -2):
        font = load_font(size)
        if draw.textlength(text, font=font) <= max_width:
            return font
    return load_font(floor)


def diagonal_gradient(start: tuple[int, int, int], end: tuple[int, int, int]) -> Image.Image:
    """Diagonal blend, matching the direction of the app icon's gradient."""
    base = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = base.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            t = (x / WIDTH + y / HEIGHT) / 2
            pixels[x, y] = tuple(
                round(start[i] + (end[i] - start[i]) * t) for i in range(3)
            )
    return base


def rounded(image: Image.Image, radius: int) -> Image.Image:
    """Apply a rounded-rect alpha mask, matching how launchers clip icons."""
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.width - 1, image.height - 1], radius, fill=255
    )
    out = image.copy()
    out.putalpha(mask)
    return out


def main() -> int:
    if not ICON.exists():
        raise SystemExit(f"icon not found: {ICON}")

    canvas = diagonal_gradient(DEEP, TEAL)

    # The icon is green on a green field, so it needs a shadow to separate.
    icon_size = 264
    radius = int(icon_size * 0.22)
    icon = Image.open(ICON).convert("RGBA").resize(
        (icon_size, icon_size), Image.LANCZOS
    )
    icon = rounded(icon, radius)
    icon_x, icon_y = 76, (HEIGHT - icon_size) // 2

    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [icon_x, icon_y + 10, icon_x + icon_size, icon_y + icon_size + 10],
        radius=radius,
        fill=(0, 0, 0, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")
    canvas.paste(icon, (icon_x, icon_y), icon)

    draw = ImageDraw.Draw(canvas)
    text_x = icon_x + icon_size + 64
    available = WIDTH - text_x - MARGIN

    title_font = fit_font(draw, TITLE, available, start=72, floor=40)
    subtitle_font = fit_font(draw, SUBTITLE, available, start=32, floor=20)

    title_h = draw.textbbox((0, 0), TITLE, font=title_font)[3]
    subtitle_h = draw.textbbox((0, 0), SUBTITLE, font=subtitle_font)[3]
    rule_gap, rule_h = 24, 4
    block_h = title_h + rule_gap + rule_h + rule_gap + subtitle_h
    y = (HEIGHT - block_h) // 2

    draw.text((text_x, y), TITLE, font=title_font, fill=(255, 255, 255))
    y += title_h + rule_gap
    draw.rectangle([text_x, y, text_x + 120, y + rule_h], fill=GOLD)
    y += rule_h + rule_gap
    draw.text((text_x, y), SUBTITLE, font=subtitle_font, fill=(226, 244, 236))

    # Fail loudly rather than shipping a silently clipped graphic.
    widest = max(
        draw.textlength(TITLE, font=title_font),
        draw.textlength(SUBTITLE, font=subtitle_font),
    )
    if text_x + widest > WIDTH - MARGIN:
        overflow = text_x + widest - WIDTH + MARGIN
        raise SystemExit(f"text overflows canvas by {overflow:.0f}px")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Explicit RGB conversion guarantees no alpha channel survives.
    canvas.convert("RGB").save(OUT, "PNG", optimize=True)
    print(
        f"wrote {OUT.relative_to(REPO)} ({OUT.stat().st_size} bytes) "
        f"title={title_font.size}pt subtitle={subtitle_font.size}pt "
        f"widest={widest:.0f}px available={available}px"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
