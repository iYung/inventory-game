"""
Generates Oregon Trail / food-cart style pixel-art assets for the game.

Outputs:
  assets/images/scene/bg.png       – 1280x360 background (sky, trees, street only — no frame)
  assets/images/scene/fg.png       – 1280x360 foreground frame (metal posts + sill, transparent window)
  assets/images/customer.png       – 48x72 Oregon Trail customer character
  assets/images/merchant.png       – 48x72 Oregon Trail merchant character

Run from the repo root:
  python3 scripts/gen_scene_art.py
"""

import os
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
SKY         = (100, 150, 185)
SKY_HORIZON = (140, 185, 210)
CLOUD       = (210, 220, 228)
CLOUD_DARK  = (185, 195, 205)

TREE_DARK   = (42,  62,  38)
TREE_MID    = (58,  82,  50)
TREE_LIGHT  = (72, 100,  62)

GROUND      = (142, 118,  88)
COBBLE_MID  = (118,  96,  70)
COBBLE_DARK = ( 92,  74,  52)

# Metal stand palette (replaces brown wood)
METAL_DARK  = ( 36,  42,  50)   # dark structural steel
METAL_MID   = ( 68,  78,  92)   # main panel surface
METAL_LIGHT = (108, 122, 140)   # highlight
METAL_SEAM  = ( 28,  32,  40)   # rivet / seam lines
METAL_SHINE = (148, 166, 186)   # specular strip

SKIN        = (220, 172, 120)
SKIN_DARK   = (185, 138,  90)
HAIR_DARK   = ( 55,  35,  18)
HAT_DARK    = ( 48,  30,  12)
HAT_MID     = ( 70,  46,  22)
SHIRT_BLUE  = ( 62,  94, 130)
SHIRT_DARK  = ( 45,  70, 100)
SHIRT_RED   = (140,  55,  45)
SHIRT_RDARK = (100,  38,  30)
PANTS       = ( 55,  62,  78)
PANTS_DARK  = ( 38,  44,  58)
BOOT        = ( 38,  28,  16)
BELT        = ( 52,  36,  14)


def rect(draw, x1, y1, x2, y2, color, a=255):
    draw.rectangle([x1, y1, x2, y2], fill=color + (a,))


def spx(d, x, y, color):
    d.point((x, y), fill=color + (255,))


# ---------------------------------------------------------------------------
# Scene dimensions
# ---------------------------------------------------------------------------
W, H       = 1280, 360

HORIZON_Y  = 210   # sky meets treeline
TREELINE_H = 48    # height of tree silhouette band
GROUND_Y   = HORIZON_Y + TREELINE_H   # y=258 – top of cobblestone
SILL_Y     = 270   # where the foreground counter begins (at customer waist)
POST_W     = 62    # left/right metal post width


# ---------------------------------------------------------------------------
# Background  1280 x 360  (sky + trees + street; NO frame)
# ---------------------------------------------------------------------------
bg = Image.new("RGBA", (W, H))
d  = ImageDraw.Draw(bg)

# Sky
rect(d, 0, 0, W, HORIZON_Y // 2, SKY)
rect(d, 0, HORIZON_Y // 2, W, HORIZON_Y, SKY_HORIZON)

# Clouds
clouds = [
    (70,  28, 180, 32),
    (310, 18, 140, 28),
    (540, 35, 220, 36),
    (820, 22, 160, 30),
    (1060, 38, 170, 28),
]
for cx, cy, cw, ch in clouds:
    rect(d, cx,          cy,        cx + cw,      cy + ch,      CLOUD)
    rect(d, cx + 8,      cy - 10,   cx + cw - 8,  cy,           CLOUD)
    rect(d, cx + cw//4,  cy - 16,   cx + 3*cw//4, cy - 10,      CLOUD_DARK)
    rect(d, cx,          cy + ch,   cx + cw,       cy + ch + 2,  CLOUD_DARK)

# Treeline silhouette
def draw_tree(d, tx, ty, tw, th):
    trunk_w = max(4, tw // 5)
    trunk_h = th // 3
    tx2 = tx + tw
    mx  = (tx + tx2) // 2
    rect(d, mx - trunk_w//2, ty + th - trunk_h, mx + trunk_w//2, ty + th, TREE_DARK)
    for i, frac in enumerate([0.45, 0.65, 0.85]):
        layer_w = int(tw * frac)
        layer_h = (th - trunk_h) // 3
        lx = mx - layer_w // 2
        ly = ty + i * layer_h
        rect(d, lx, ly, lx + layer_w, ly + layer_h + 4,
             TREE_MID if i % 2 == 0 else TREE_DARK)
    rect(d, tx, ty + th - trunk_h - 4, tx2, ty + th - trunk_h + 2, TREE_LIGHT)

tree_defs = [
    (0,    HORIZON_Y - 48, 50, 50),  (38,   HORIZON_Y - 62, 44, 62),
    (80,   HORIZON_Y - 40, 48, 42),  (120,  HORIZON_Y - 55, 54, 56),
    (165,  HORIZON_Y - 42, 46, 44),  (210,  HORIZON_Y - 68, 52, 68),
    (255,  HORIZON_Y - 38, 40, 40),  (295,  HORIZON_Y - 50, 48, 52),
    (340,  HORIZON_Y - 60, 56, 62),  (390,  HORIZON_Y - 44, 44, 46),
    (428,  HORIZON_Y - 54, 50, 55),  (472,  HORIZON_Y - 48, 46, 50),
    (514,  HORIZON_Y - 65, 55, 65),  (562,  HORIZON_Y - 42, 42, 44),
    (600,  HORIZON_Y - 58, 52, 60),  (646,  HORIZON_Y - 48, 48, 50),
    (690,  HORIZON_Y - 55, 54, 57),  (738,  HORIZON_Y - 40, 44, 42),
    (778,  HORIZON_Y - 62, 50, 63),  (824,  HORIZON_Y - 50, 48, 52),
    (868,  HORIZON_Y - 44, 46, 46),  (910,  HORIZON_Y - 58, 52, 60),
    (958,  HORIZON_Y - 42, 44, 44),  (998,  HORIZON_Y - 54, 50, 56),
    (1044, HORIZON_Y - 66, 56, 67),  (1094, HORIZON_Y - 46, 46, 48),
    (1136, HORIZON_Y - 52, 50, 54),  (1182, HORIZON_Y - 40, 44, 42),
    (1222, HORIZON_Y - 58, 52, 59),  (1266, HORIZON_Y - 50, 48, 51),
]
rect(d, 0, HORIZON_Y, W, HORIZON_Y + TREELINE_H, TREE_DARK)
for args in tree_defs:
    draw_tree(d, *args)

# Ground / cobblestone street (up to SILL_Y)
rect(d, 0, GROUND_Y, W, SILL_Y, GROUND)
COBBLE_ROW_H = 18
COBBLE_COL_W = 48
for row_i, ry in enumerate(range(GROUND_Y, SILL_Y, COBBLE_ROW_H)):
    offset = (row_i % 2) * (COBBLE_COL_W // 2)
    rect(d, 0, ry, W, ry + 2, COBBLE_DARK)
    for cx in range(-COBBLE_COL_W + offset, W + COBBLE_COL_W, COBBLE_COL_W):
        rect(d, cx, ry + 2, cx + 2, ry + COBBLE_ROW_H - 2, COBBLE_DARK)
        if 0 <= cx < W:
            rect(d, cx + 3, ry + 3, min(cx + COBBLE_COL_W - 3, W - 1), ry + 6, COBBLE_MID)

bg.save("assets/images/scene/bg.png")
print("Saved assets/images/scene/bg.png")


# ---------------------------------------------------------------------------
# Foreground frame  1280 x 360  (metal posts + sill; transparent window opening)
# Drawn AFTER the customer so it occludes their lower body, creating depth.
# ---------------------------------------------------------------------------
fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))   # fully transparent base
fd = ImageDraw.Draw(fg)


def metal_panel(fd, x1, y1, x2, y2, horizontal=False):
    """Fill a rectangle with the metal panel surface + seams + shine strip."""
    rect(fd, x1, y1, x2, y2, METAL_MID)
    # Outer shadow edges
    rect(fd, x1, y1, x2, y1 + 2, METAL_SEAM)   # top edge
    rect(fd, x1, y2 - 2, x2, y2, METAL_SEAM)   # bottom edge
    rect(fd, x1, y1, x1 + 2, y2, METAL_SEAM)   # left edge
    rect(fd, x2 - 2, y1, x2, y2, METAL_SEAM)   # right edge
    if horizontal:
        # Horizontal panel lines / seams
        for sy in range(y1 + 18, y2, 18):
            rect(fd, x1 + 2, sy, x2 - 2, sy + 2, METAL_SEAM)
        # Shine strip near top
        rect(fd, x1 + 4, y1 + 4, x2 - 4, y1 + 8, METAL_SHINE)
    else:
        # Vertical panel lines / seams
        for sx in range(x1 + 18, x2, 18):
            rect(fd, sx, y1 + 2, sx + 2, y2 - 2, METAL_SEAM)
        # Shine strip near left
        rect(fd, x1 + 4, y1 + 4, x1 + 8, y2 - 4, METAL_SHINE)


def rivet_row(fd, x1, y, x2, spacing=40):
    """Draw a row of rivets along a horizontal line."""
    for rx in range(x1 + spacing // 2, x2, spacing):
        rect(fd, rx - 2, y - 2, rx + 2, y + 2, METAL_DARK)
        rect(fd, rx - 1, y - 1, rx + 1, y + 1, METAL_LIGHT)


# Left post
metal_panel(fd, 0, 0, POST_W, H, horizontal=False)
# Inner bevel on right edge of left post
rect(fd, POST_W - 6, 0, POST_W, H, METAL_DARK)
rect(fd, POST_W - 4, 4, POST_W - 2, H - 4, METAL_MID)

# Right post
metal_panel(fd, W - POST_W, 0, W, H, horizontal=False)
# Inner bevel on left edge of right post
rect(fd, W - POST_W, 0, W - POST_W + 6, H, METAL_DARK)
rect(fd, W - POST_W + 2, 4, W - POST_W + 4, H - 4, METAL_MID)

# Counter / sill (covers customer's lower body for depth)
metal_panel(fd, 0, SILL_Y, W, H, horizontal=True)
# Bold top edge of counter
rect(fd, POST_W, SILL_Y, W - POST_W, SILL_Y + 6, METAL_DARK)
rect(fd, POST_W, SILL_Y + 6, W - POST_W, SILL_Y + 12, METAL_SHINE)
# Rivet rows along top of sill where it meets the posts
rivet_row(fd, POST_W, SILL_Y + 3, W - POST_W, spacing=48)
# Rivet rows along bottom of posts
rivet_row(fd, 0, H - 10, POST_W, spacing=24)
rivet_row(fd, W - POST_W, H - 10, W, spacing=24)

fg.save("assets/images/scene/fg.png")
print("Saved assets/images/scene/fg.png")


# ---------------------------------------------------------------------------
# Character sprites  72 x 72  (square, wider proportions fill the window)
# ---------------------------------------------------------------------------
SW, SH = 72, 72

def make_sprite():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def srect(d, x1, y1, x2, y2, color, a=255):
    d.rectangle([x1, y1, x2, y2], fill=color + (a,))


def draw_character(shirt_color, shirt_dark, hat_color, hat_dark, has_beard=False):
    img, d = make_sprite()
    cx = SW // 2   # 36

    # --- Boots (y 62-71) ---
    srect(d, cx - 16, 62, cx - 3,  72, BOOT)
    srect(d, cx + 3,  62, cx + 16, 72, BOOT)
    srect(d, cx - 16, 62, cx - 4,  65, (60, 46, 28))
    srect(d, cx + 4,  62, cx + 15, 65, (60, 46, 28))

    # --- Pants (y 50-62) ---
    srect(d, cx - 15, 50, cx - 2, 62, PANTS)
    srect(d, cx + 2,  50, cx + 15, 62, PANTS)
    srect(d, cx - 15, 50, cx - 12, 62, PANTS_DARK)
    srect(d, cx + 12, 50, cx + 15, 62, PANTS_DARK)

    # --- Belt (y 47-51) ---
    srect(d, cx - 18, 47, cx + 18, 51, BELT)
    srect(d, cx - 5,  47, cx + 5,  51, (180, 145, 60))  # buckle

    # --- Torso (y 28-47) — wide, barrel-chested ---
    srect(d, cx - 18, 28, cx + 18, 47, shirt_color)
    srect(d, cx - 18, 28, cx - 15, 47, shirt_dark)
    srect(d, cx + 15, 28, cx + 18, 47, shirt_dark)
    for by in range(31, 46, 5):
        srect(d, cx - 1, by, cx + 2, by + 2, (200, 185, 160))

    # --- Arms (y 28-48) — thick ---
    srect(d, cx - 28, 28, cx - 18, 46, shirt_color)
    srect(d, cx - 28, 28, cx - 25, 46, shirt_dark)
    srect(d, cx - 29, 43, cx - 18, 51, SKIN)   # left hand
    srect(d, cx + 18, 28, cx + 28, 46, shirt_color)
    srect(d, cx + 25, 28, cx + 28, 46, shirt_dark)
    srect(d, cx + 18, 43, cx + 29, 51, SKIN)   # right hand

    # --- Neck (y 22-28) ---
    srect(d, cx - 5, 22, cx + 5, 28, SKIN)

    # --- Head (y 10-24) — wider ---
    srect(d, cx - 13, 10, cx + 13, 24, SKIN)
    srect(d, cx - 13, 10, cx - 10, 24, SKIN_DARK)
    srect(d, cx + 10, 10, cx + 13, 24, SKIN_DARK)
    # Eyes
    srect(d, cx - 8, 15, cx - 5, 18, (30, 22, 15))
    srect(d, cx + 5, 15, cx + 8, 18, (30, 22, 15))
    spx(d, cx - 7, 15, (255, 255, 255))
    spx(d, cx + 6, 15, (255, 255, 255))
    # Nose
    srect(d, cx - 1, 19, cx + 2, 20, SKIN_DARK)
    # Mouth
    srect(d, cx - 4, 22, cx + 4, 23, (150, 90, 70))
    if has_beard:
        srect(d, cx - 11, 20, cx + 11, 24, (90, 60, 35))
        srect(d, cx - 12, 22, cx + 12, 26, (75, 50, 28))

    # --- Ears ---
    srect(d, cx - 15, 13, cx - 13, 20, SKIN)
    srect(d, cx + 13, 13, cx + 15, 20, SKIN)

    # --- Hair under hat ---
    srect(d, cx - 13, 10, cx + 13, 12, HAIR_DARK)

    # --- Hat brim (y 6-10) — wide ---
    srect(d, cx - 20, 6, cx + 20, 10, hat_color)
    srect(d, cx - 13, 10, cx + 13, 12, hat_dark)

    # --- Hat crown (y 0-6) ---
    srect(d, cx - 13, 0, cx + 13, 6, hat_color)
    srect(d, cx - 13, 0, cx - 10, 6, hat_dark)
    srect(d, cx + 10, 0, cx + 13, 6, hat_dark)
    srect(d, cx - 13, 5, cx + 13, 6, hat_dark)

    return img


customer = draw_character(SHIRT_BLUE, SHIRT_DARK, HAT_MID, HAT_DARK, has_beard=True)
customer.save("assets/images/customer.png")
print("Saved assets/images/customer.png")

merchant = draw_character(SHIRT_RED, SHIRT_RDARK, (55, 35, 12), (38, 24, 8), has_beard=False)
merchant.save("assets/images/merchant.png")
print("Saved assets/images/merchant.png")
