#!/usr/bin/env python3
"""Generate 160x120 RGBA placeholder panel-content images for book items."""

import os
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "books")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 160, 120


def save(img, name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    img.save(path)
    print(f"  wrote {path}")


def gen_garden_book():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Sky background
    d.rectangle([0, 0, W, H], fill=(180, 220, 160, 255))

    # Soil strip at bottom
    d.rectangle([0, 90, W, H], fill=(90, 58, 30, 255))
    # Soil highlight line
    d.line([(0, 90), (W, 90)], fill=(120, 80, 45, 255), width=2)

    # Sun top-right
    d.ellipse([128, 8, 152, 32], fill=(240, 210, 80, 255))

    # Grass strip
    d.rectangle([0, 84, W, 92], fill=(60, 130, 40, 255))

    # Plant 1 — tall stem with leaves
    cx = 28
    d.rectangle([cx - 2, 50, cx + 2, 88], fill=(50, 110, 30, 255))
    d.ellipse([cx - 14, 38, cx + 4, 58], fill=(70, 160, 50, 255))
    d.ellipse([cx - 2, 32, cx + 16, 52], fill=(80, 180, 55, 255))
    d.ellipse([cx - 8, 28, cx + 10, 44], fill=(100, 200, 60, 255))

    # Plant 2 — bushier
    cx = 80
    d.rectangle([cx - 2, 55, cx + 2, 88], fill=(50, 110, 30, 255))
    d.ellipse([cx - 18, 40, cx + 18, 70], fill=(60, 150, 40, 255))
    d.ellipse([cx - 12, 32, cx + 12, 58], fill=(80, 175, 55, 255))
    d.ellipse([cx - 8, 26, cx + 8, 46], fill=(95, 195, 60, 255))

    # Plant 3 — flower
    cx = 132
    d.rectangle([cx - 2, 58, cx + 2, 88], fill=(50, 110, 30, 255))
    for dx, dy in [(-10, 0), (10, 0), (0, -10), (0, 10), (-7, -7), (7, -7), (-7, 7), (7, 7)]:
        d.ellipse([cx + dx - 6, 48 + dy - 6, cx + dx + 6, 48 + dy + 6], fill=(220, 100, 120, 255))
    d.ellipse([cx - 7, 41, cx + 7, 55], fill=(240, 200, 80, 255))

    # Small stones in soil
    for sx, sy in [(20, 98), (60, 104), (100, 96), (140, 102)]:
        d.ellipse([sx - 4, sy - 3, sx + 4, sy + 3], fill=(110, 75, 45, 255))

    save(img, "garden_book")


def gen_microwave_book():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Background — dark grey kitchen wall
    d.rectangle([0, 0, W, H], fill=(55, 55, 62, 255))

    # Counter surface at bottom
    d.rectangle([0, 92, W, H], fill=(80, 78, 85, 255))
    d.line([(0, 92), (W, 92)], fill=(100, 98, 108, 255), width=2)

    # Microwave body
    bx, by, bw, bh = 24, 30, 112, 58
    d.rectangle([bx, by, bx + bw, by + bh], fill=(120, 120, 132, 255))
    d.rectangle([bx + 1, by + 1, bx + bw - 1, by + bh - 1], fill=(140, 140, 152, 255))

    # Door window (left side)
    wx, wy, ww, wh = bx + 6, by + 8, 62, 42
    d.rectangle([wx, wy, wx + ww, wy + wh], fill=(40, 40, 48, 255))
    d.rectangle([wx + 2, wy + 2, wx + ww - 2, wy + wh - 2], fill=(30, 32, 40, 255))
    # Door handle
    d.rectangle([wx + ww + 2, wy + wh // 2 - 5, wx + ww + 6, wy + wh // 2 + 5], fill=(100, 100, 110, 255))

    # Control panel (right side)
    cpx = bx + 6 + 62 + 10
    # Buttons — 3x3 grid
    for row in range(3):
        for col in range(2):
            bpx = cpx + col * 14
            bpy = by + 10 + row * 13
            d.rectangle([bpx, bpy, bpx + 10, bpy + 8], fill=(90, 90, 100, 255))
            d.rectangle([bpx + 1, bpy + 1, bpx + 9, bpy + 7], fill=(105, 105, 118, 255))
    # Display strip
    d.rectangle([cpx, by + 52, cpx + 26, by + 56], fill=(60, 90, 60, 255))
    d.rectangle([cpx + 2, by + 53, cpx + 18, by + 55], fill=(80, 180, 80, 255))

    # Steam lines above microwave
    for sx in [50, 70, 90, 110]:
        d.line([(sx, by - 4), (sx - 2, by - 12)], fill=(170, 170, 180, 255), width=1)
        d.line([(sx - 2, by - 12), (sx + 2, by - 20)], fill=(150, 150, 162, 255), width=1)

    # Shadow under microwave
    d.rectangle([bx + 4, by + bh, bx + bw - 4, by + bh + 4], fill=(45, 45, 52, 255))

    save(img, "microwave_book")


if __name__ == "__main__":
    print(f"Generating book pages into {os.path.abspath(OUT_DIR)}/")
    gen_garden_book()
    gen_microwave_book()
    print("Done.")
