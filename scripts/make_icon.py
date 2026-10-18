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


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        draw.line([(0, y), (size, y)], fill=lerp(top, bottom, y / (size - 1)) + (255,))
    return img


def draw_icon():
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # Rounded-square tile, sized and placed like Apple's macOS icon grid.
    tile = 824 * S
    offset = (N - tile) // 2
    radius = 185 * S
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [offset, offset, offset + tile, offset + tile], radius=radius, fill=255)

    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (0, 12 * S), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14 * S))
    canvas.alpha_composite(shadow)

    background = vertical_gradient(N, (255, 138, 76), (214, 46, 112))
    canvas.paste(background, (0, 0), mask)

    # Handheld microphone, drawn upright on its own layer and then tilted.
    mic = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(mic)
    cx = N // 2
    head_r = 150 * S
    head_cy = 360 * S

    # Handle: a tapered body under the head.
    top_w, bottom_w = 92 * S, 58 * S
    handle_top = head_cy + head_r - 30 * S
    handle_bottom = 830 * S
    d.polygon([
        (cx - top_w, handle_top), (cx + top_w, handle_top),
        (cx + bottom_w, handle_bottom), (cx - bottom_w, handle_bottom),
    ], fill=(250, 250, 252, 255))
    d.ellipse([cx - bottom_w, handle_bottom - bottom_w // 2,
               cx + bottom_w, handle_bottom + bottom_w // 2], fill=(250, 250, 252, 255))
    # Collar ring between head and handle.
    collar_y = handle_top + 10 * S
    d.rounded_rectangle([cx - top_w - 14 * S, collar_y - 26 * S, cx + top_w + 14 * S, collar_y + 26 * S],
                        radius=24 * S, fill=(60, 30, 60, 255))

    # Head: a ball with a grille.
    d.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r], fill=(250, 250, 252, 255))
    grille = Image.new("L", (N, N), 0)
    g = ImageDraw.Draw(grille)
    step = 38 * S
    for i in range(-6, 7):
        x = cx + i * step
        g.line([(x, head_cy - head_r), (x, head_cy + head_r)], fill=255, width=9 * S)
        y = head_cy + i * step
        g.line([(cx - head_r, y), (cx + head_r, y)], fill=255, width=9 * S)
    head_mask = Image.new("L", (N, N), 0)
    inset = 26 * S
    ImageDraw.Draw(head_mask).ellipse(
        [cx - head_r + inset, head_cy - head_r + inset, cx + head_r - inset, head_cy + head_r - inset], fill=255)
    grille = Image.composite(grille, Image.new("L", (N, N), 0), head_mask)
    mic.paste((214, 46, 112, 120), (0, 0), grille)

    mic = mic.rotate(-28, resample=Image.BICUBIC, center=(N // 2, N // 2))
    mic_shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mic_shadow.paste((60, 0, 30, 110), (0, 0), mic.getchannel("A"))
    mic_shadow = mic_shadow.filter(ImageFilter.GaussianBlur(16 * S))
    canvas.alpha_composite(mic_shadow, (6 * S, 18 * S))
    canvas.alpha_composite(mic)

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
