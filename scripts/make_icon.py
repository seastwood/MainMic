#!/usr/bin/env python3
"""Draws the MainMic app icon and writes Resources/AppIcon.icns (and a preview PNG).

Needs Pillow: pip install pillow
"""
import io
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
S = 4  # supersampling factor
N = 1024 * S


# Shared with Sources/MainMic/Glyph.swift: keep both in sync so the app icon
# and the menu bar icon are the same shape.
BAR_HEIGHTS = [0.42, 0.78, 1.0, 0.62, 0.30]
GAP_RATIO = 0.6  # gap between bars as a fraction of bar width


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        draw.line([(0, y), (size, y)], fill=lerp(top, bottom, y / (size - 1)) + (255,))
    return img


def bar_rects(x0, y0, width, height):
    count = len(BAR_HEIGHTS)
    w = width / (count + GAP_RATIO * (count - 1))
    g = w * GAP_RATIO
    mid = y0 + height / 2
    for i, h in enumerate(BAR_HEIGHTS):
        bh = max(w, height * h)
        x = x0 + i * (w + g)
        yield [x, mid - bh / 2, x + w, mid + bh / 2], w / 2


def draw_icon():
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # Rounded-square tile, sized and placed like Apple's macOS icon grid.
    tile = 824 * S
    offset = (N - tile) // 2
    radius = 185 * S
    box = [offset, offset, offset + tile, offset + tile]
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)

    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (0, 10 * S), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14 * S))
    canvas.alpha_composite(shadow)

    # Dark graphite tile with a hairline edge so it holds up on a dark Dock.
    canvas.paste(vertical_gradient(N, (46, 48, 54), (22, 23, 27)), (0, 0), mask)
    edge = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 34), width=4 * S)
    canvas.alpha_composite(edge)

    # Level bars in a single accent colour.
    glyph_w, glyph_h = 470 * S, 440 * S
    bars = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(bars)
    for rect, r in bar_rects((N - glyph_w) / 2, (N - glyph_h) / 2, glyph_w, glyph_h):
        d.rounded_rectangle(rect, radius=r, fill=255)
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    glow.paste((60, 220, 160, 90), (0, 0), bars)
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(28 * S)))
    canvas.paste(vertical_gradient(N, (120, 245, 196), (40, 200, 140)), (0, 0), bars)

    return canvas.resize((1024, 1024), Image.LANCZOS)


def png_bytes(img, size):
    buf = io.BytesIO()
    img.resize((size, size), Image.LANCZOS).save(buf, format="PNG")
    return buf.getvalue()


def write_icns(img, path):
    # PNG-encoded entries, supported by macOS 10.7+.
    entries = [
        (b"icp4", 16), (b"icp5", 32), (b"ic11", 32), (b"ic12", 64),
        (b"ic07", 128), (b"ic13", 256), (b"ic08", 256), (b"ic14", 512),
        (b"ic09", 512), (b"ic10", 1024),
    ]
    chunks = b""
    for kind, size in entries:
        data = png_bytes(img, size)
        chunks += kind + struct.pack(">I", len(data) + 8) + data
    path.write_bytes(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)


if __name__ == "__main__":
    icon = draw_icon()
    write_icns(icon, ROOT / "Resources" / "AppIcon.icns")
    icon.save(ROOT / "Resources" / "AppIcon.png")
    print("Wrote Resources/AppIcon.icns and Resources/AppIcon.png")
