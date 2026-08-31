"""
Generates Oregon Trail / food-cart style pixel-art assets for the game.

Outputs:
  assets/images/scene/bg.png       – 1280x360 background (sky, trees, street, wood frame)
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

WOOD_DARK   = ( 74,  46,  20)
WOOD_MID    = (110,  72,  34)
WOOD_LIGHT  = (148, 104,  54)
WOOD_GRAIN  = ( 88,  56,  24)

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


def px(draw, x, y, color):
    draw.point((x, y), fill=color + (255,))


def rect(draw, x1, y1, x2, y2, color, alpha=255):
    draw.rectangle([x1, y1, x2, y2], fill=color + (alpha,))


# ---------------------------------------------------------------------------
# Background  1280 x 360
# ---------------------------------------------------------------------------
W, H = 1280, 360

HORIZON_Y  = 218   # where sky meets treeline
TREELINE_H = 52    # height of tree silhouette band
GROUND_Y   = HORIZON_Y + TREELINE_H   # y=270 – top of street
SILL_Y     = 300   # y=300 – top of wooden counter/sill
FRAME_Y    = 340   # y=340 – heavy frame beam
POST_W     = 60    # width of left/right wooden posts

bg = Image.new("RGBA", (W, H))
d  = ImageDraw.Draw(bg)

# --- Sky (gradient-ish: two bands) -----------------------------------------
rect(d, 0, 0, W, HORIZON_Y // 2, SKY)
rect(d, 0, HORIZON_Y // 2, W, HORIZON_Y, SKY_HORIZON)

# --- Clouds ----------------------------------------------------------------
clouds = [
    (70,  28, 180, 32),
    (310, 18, 140, 28),
    (540, 35, 220, 36),
    (820, 22, 160, 30),
    (1060, 38, 170, 28),
]
for cx, cy, cw, ch in clouds:
    rect(d, cx,        cy,        cx + cw,      cy + ch,      CLOUD)
    rect(d, cx + 8,    cy - 10,   cx + cw - 8,  cy,           CLOUD)
    rect(d, cx + cw//4, cy - 16,  cx + 3*cw//4, cy - 10,      CLOUD_DARK)
    rect(d, cx,         cy + ch,  cx + cw,       cy + ch + 2,  CLOUD_DARK)

# --- Treeline silhouette ---------------------------------------------------
# Draw simple chunky pixel trees across the horizon

def draw_tree(d, tx, ty, tw, th):
    # trunk
    trunk_w = max(4, tw // 5)
    trunk_h = th // 3
    tx2 = tx + tw
    mx  = (tx + tx2) // 2
    rect(d, mx - trunk_w//2, ty + th - trunk_h, mx + trunk_w//2, ty + th, TREE_DARK)
    # canopy layers (3 tiers, each wider at bottom)
    for i, frac in enumerate([0.45, 0.65, 0.85]):
        layer_w = int(tw * frac)
        layer_h = (th - trunk_h) // 3
        lx = mx - layer_w // 2
        ly = ty + i * layer_h
        rect(d, lx, ly, lx + layer_w, ly + layer_h + 4, TREE_MID if i % 2 == 0 else TREE_DARK)
    rect(d, tx, ty + th - trunk_h - 4, tx2, ty + th - trunk_h + 2, TREE_LIGHT)

tree_defs = [
    (0,    HORIZON_Y - 48, 50, 50),
    (38,   HORIZON_Y - 62, 44, 62),
    (80,   HORIZON_Y - 40, 48, 42),
    (120,  HORIZON_Y - 55, 54, 56),
    (165,  HORIZON_Y - 42, 46, 44),
    (210,  HORIZON_Y - 68, 52, 68),
    (255,  HORIZON_Y - 38, 40, 40),
    (295,  HORIZON_Y - 50, 48, 52),
    (340,  HORIZON_Y - 60, 56, 62),
    (390,  HORIZON_Y - 44, 44, 46),
    (428,  HORIZON_Y - 54, 50, 55),
    (472,  HORIZON_Y - 48, 46, 50),
    (514,  HORIZON_Y - 65, 55, 65),
    (562,  HORIZON_Y - 42, 42, 44),
    (600,  HORIZON_Y - 58, 52, 60),
    (646,  HORIZON_Y - 48, 48, 50),
    (690,  HORIZON_Y - 55, 54, 57),
    (738,  HORIZON_Y - 40, 44, 42),
    (778,  HORIZON_Y - 62, 50, 63),
    (824,  HORIZON_Y - 50, 48, 52),
    (868,  HORIZON_Y - 44, 46, 46),
    (910,  HORIZON_Y - 58, 52, 60),
    (958,  HORIZON_Y - 42, 44, 44),
    (998,  HORIZON_Y - 54, 50, 56),
    (1044, HORIZON_Y - 66, 56, 67),
    (1094, HORIZON_Y - 46, 46, 48),
    (1136, HORIZON_Y - 52, 50, 54),
    (1182, HORIZON_Y - 40, 44, 42),
    (1222, HORIZON_Y - 58, 52, 59),
    (1266, HORIZON_Y - 50, 48, 51),
]
# Fill treeline base first
rect(d, 0, HORIZON_Y, W, HORIZON_Y + TREELINE_H, TREE_DARK)
for tx, ty, tw, th in tree_defs:
    draw_tree(d, tx, ty, tw, th)

# --- Ground / street -------------------------------------------------------
rect(d, 0, GROUND_Y, W, SILL_Y, GROUND)
# Cobblestone grid
COBBLE_ROW_H = 18
COBBLE_COL_W = 48
for row_i, ry in enumerate(range(GROUND_Y, SILL_Y, COBBLE_ROW_H)):
    offset = (row_i % 2) * (COBBLE_COL_W // 2)
    rect(d, 0, ry, W, ry + 2, COBBLE_DARK)          # horizontal mortar
    for cx in range(-COBBLE_COL_W + offset, W + COBBLE_COL_W, COBBLE_COL_W):
        rect(d, cx, ry + 2, cx + 2, ry + COBBLE_ROW_H - 2, COBBLE_DARK)   # vertical mortar
        # Slight highlight on stone top-left
        if 0 <= cx < W:
            rect(d, cx + 3, ry + 3, min(cx + COBBLE_COL_W - 3, W - 1), ry + 6, COBBLE_MID)

# --- Wooden counter / sill -------------------------------------------------
rect(d, 0, SILL_Y, W, H, WOOD_MID)
# Plank lines (vertical grain joints)
for px_x in range(0, W, 88):
    rect(d, px_x, SILL_Y, px_x + 3, H, WOOD_GRAIN)
# Top highlight strip
rect(d, 0, SILL_Y, W, SILL_Y + 6, WOOD_LIGHT)
# Subtle shadow under highlight
rect(d, 0, SILL_Y + 6, W, SILL_Y + 10, WOOD_DARK)
# Horizontal plank seam
rect(d, 0, FRAME_Y, W, FRAME_Y + 4, WOOD_DARK)
rect(d, 0, FRAME_Y + 4, W, FRAME_Y + 8, WOOD_LIGHT)

# --- Side wooden posts (left and right of the serving window) --------------
for px_x1, px_x2 in [(0, POST_W), (W - POST_W, W)]:
    rect(d, px_x1, 0, px_x2, H, WOOD_MID)
    # Vertical grain lines on post
    step = 10
    for gx in range(px_x1 + 3, px_x2 - 3, step):
        d.line([(gx, 0), (gx + 2, H)], fill=WOOD_GRAIN + (200,))
    # Edge highlights
    rect(d, px_x1, 0, px_x1 + 4, H, WOOD_LIGHT)
    rect(d, px_x2 - 4, 0, px_x2, H, WOOD_DARK)
    # Horizontal banding (wood sections)
    for hy in range(0, H, 80):
        rect(d, px_x1 + 4, hy, px_x2 - 4, hy + 3, WOOD_DARK)

# Knot hole details on left post
rect(d, 18, 80, 38, 100, WOOD_DARK)
rect(d, 22, 84, 34, 96,  WOOD_GRAIN)
# And right post
rect(d, W - 40, 150, W - 18, 170, WOOD_DARK)
rect(d, W - 36, 154, W - 22, 166, WOOD_GRAIN)

bg.save("assets/images/scene/bg.png")
print("Saved assets/images/scene/bg.png")


# ---------------------------------------------------------------------------
# Character sprites  48 x 72
# ---------------------------------------------------------------------------
SW, SH = 48, 72   # sprite dimensions

def make_sprite():
    img = Image.new("RGBA", (SW, SH), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def srect(d, x1, y1, x2, y2, color, a=255):
    d.rectangle([x1, y1, x2, y2], fill=color + (a,))

def spx(d, x, y, color):
    d.point((x, y), fill=color + (255,))


def draw_character(shirt_color, shirt_dark, hat_color, hat_dark, has_beard=False):
    img, d = make_sprite()

    cx = SW // 2   # horizontal center = 24

    # --- Boots (y 62-71) ---
    srect(d, cx - 11, 62, cx - 2, 72, BOOT)
    srect(d, cx + 2, 62, cx + 11, 72, BOOT)
    # toe highlight
    srect(d, cx - 11, 62, cx - 3, 64, (60, 46, 28))
    srect(d, cx + 2, 62, cx + 10, 64, (60, 46, 28))

    # --- Pants (y 50-62) ---
    srect(d, cx - 10, 50, cx - 2, 62, PANTS)
    srect(d, cx + 2, 50, cx + 10, 62, PANTS)
    # Pant seam shading
    srect(d, cx - 10, 50, cx - 8, 62, PANTS_DARK)
    srect(d, cx + 8, 50, cx + 10, 62, PANTS_DARK)

    # --- Belt (y 48-51) ---
    srect(d, cx - 12, 48, cx + 12, 51, BELT)
    # Buckle
    srect(d, cx - 4, 48, cx + 4, 51, (180, 145, 60))

    # --- Torso/shirt (y 30-48) ---
    srect(d, cx - 12, 30, cx + 12, 48, shirt_color)
    # Side shading
    srect(d, cx - 12, 30, cx - 10, 48, shirt_dark)
    srect(d, cx + 10, 30, cx + 12, 48, shirt_dark)
    # Button placket
    for by in range(33, 47, 5):
        srect(d, cx - 1, by, cx + 1, by + 2, (200, 185, 160))

    # --- Arms (y 30-48) ---
    # Left arm
    srect(d, cx - 18, 30, cx - 12, 46, shirt_color)
    srect(d, cx - 18, 30, cx - 16, 46, shirt_dark)
    # Left hand
    srect(d, cx - 19, 44, cx - 12, 50, SKIN)
    # Right arm
    srect(d, cx + 12, 30, cx + 18, 46, shirt_color)
    srect(d, cx + 16, 30, cx + 18, 46, shirt_dark)
    # Right hand
    srect(d, cx + 12, 44, cx + 19, 50, SKIN)

    # --- Neck (y 24-30) ---
    srect(d, cx - 4, 24, cx + 4, 30, SKIN)

    # --- Head (y 12-26) ---
    srect(d, cx - 8, 12, cx + 8, 26, SKIN)
    # Side shading
    srect(d, cx - 8, 12, cx - 6, 26, SKIN_DARK)
    srect(d, cx + 6, 12, cx + 8, 26, SKIN_DARK)
    # Eyes
    srect(d, cx - 5, 17, cx - 3, 19, (30, 22, 15))
    srect(d, cx + 3, 17, cx + 5, 19, (30, 22, 15))
    # Eye shine
    spx(d, cx - 4, 17, (255, 255, 255))
    spx(d, cx + 4, 17, (255, 255, 255))
    # Nose
    spx(d, cx, 21, SKIN_DARK)
    spx(d, cx + 1, 21, SKIN_DARK)
    # Mouth
    srect(d, cx - 3, 23, cx + 3, 24, (160, 100, 80))
    if has_beard:
        # Simple stubble: sparse dark pixels on lower face
        for bx in range(cx - 7, cx + 8, 2):
            for byy in [22, 23, 24]:
                spx(d, bx, byy, (90, 60, 35))
        srect(d, cx - 7, 24, cx + 7, 26, (80, 54, 28))

    # --- Ears (y 14-20) ---
    srect(d, cx - 10, 14, cx - 8, 20, SKIN)
    srect(d, cx + 8, 14, cx + 10, 20, SKIN)

    # --- Hair below hat (y 12-14) ---
    srect(d, cx - 8, 12, cx + 8, 14, HAIR_DARK)

    # --- Hat brim (y 8-12) ---
    srect(d, cx - 14, 8, cx + 14, 12, hat_color)
    # Brim shadow on head
    srect(d, cx - 8, 12, cx + 8, 14, hat_dark)

    # --- Hat crown (y 0-8) ---
    srect(d, cx - 9, 0, cx + 9, 8, hat_color)
    # Crown shading
    srect(d, cx - 9, 0, cx - 7, 8, hat_dark)
    srect(d, cx + 7, 0, cx + 9, 8, hat_dark)
    # Hatband
    srect(d, cx - 9, 6, cx + 9, 8, hat_dark)

    return img


# Customer: blue shirt, brown cowboy hat, stubble
customer = draw_character(SHIRT_BLUE, SHIRT_DARK, HAT_MID, HAT_DARK, has_beard=True)
customer.save("assets/images/customer.png")
print("Saved assets/images/customer.png")

# Merchant: red shirt, darker hat (traveling merchant look)
merchant = draw_character(SHIRT_RED, SHIRT_RDARK, (55, 35, 12), (38, 24, 8), has_beard=False)
merchant.save("assets/images/merchant.png")
print("Saved assets/images/merchant.png")
