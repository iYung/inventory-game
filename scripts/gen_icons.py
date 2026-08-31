#!/usr/bin/env python3
"""Generate 32x32 RGBA pixel-art icons.
Each icon uses only shades of its item's primary color (matching item_defs.lua).
"""

import os
import math
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "items")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 32

# Primary colors (R,G,B) matching item_defs.lua values scaled to 0-255.
COLORS = {
    "raw_chicken":      (191, 64,  64),
    "raw_beef":         (166, 38,  38),
    "baked_chicken":    (140, 92,  51),
    "steak":            (140, 64,  31),
    "fried_chicken":    (224, 166, 51),
    "broccoli":         (77,  140, 51),
    "steamed_broccoli": (115, 191, 77),
    "potato":           (217, 191, 140),
    "baked_potato":     (179, 140, 89),
    "water":            (102, 166, 230),
    "fries":            (242, 191, 64),
    "beef_stew":        (153, 102, 64),
    "chicken_soup":     (179, 128, 77),
    "onion":            (230, 191, 102),
    "blooming_onion":   (204, 153, 64),
    "onion_soup":       (191, 140, 64),
    "boiled_egg":       (242, 230, 191),
    "egg":              (242, 235, 204),
    "chicken":          (184, 140, 77),
    "cow":              (115, 71,  38),
    "microwave":        (140, 140, 153),
    "fryer":            (89,  89,  102),
    "pot":              (64,  64,  77),
    "coop":             (140, 107, 64),
    "meat_machine":     (102, 102, 115),
    "incubator":        (166, 191, 153),
    "broccoli_garden":  (51,  128, 38),
    "onion_garden":     (166, 128, 51),
    "customer":         (217, 140, 77),   # DEFAULT_COLOR from customer.lua
    "merchant":         (77,  230, 230),  # bright teal from DF design
}


# ── color helpers ─────────────────────────────────────────────────────────────

def rgba(r, g, b, a=255):
    return (int(min(255, max(0, r))), int(min(255, max(0, g))),
            int(min(255, max(0, b))), int(a))


def darken(c, t):
    """Lerp toward black by t (0=original, 1=black)."""
    r, g, b = c[0], c[1], c[2]
    return rgba(r * (1 - t), g * (1 - t), b * (1 - t))


def lighten(c, t):
    """Lerp toward white by t (0=original, 1=white)."""
    r, g, b = c[0], c[1], c[2]
    return rgba(r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t)


def shades(type_id):
    """Return (base, dark, darkest, light, lightest) tuples for this item."""
    c = COLORS[type_id]
    return (
        rgba(*c),           # base
        darken(c, 0.35),    # dark
        darken(c, 0.62),    # darkest
        lighten(c, 0.35),   # light
        lighten(c, 0.65),   # lightest
    )


# ── canvas helpers ────────────────────────────────────────────────────────────

def new_img():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img, type_id):
    path = os.path.join(OUT_DIR, f"{type_id}.png")
    img.save(path)
    print(f"  wrote {path}")


# ── shared shape helpers ──────────────────────────────────────────────────────

def draw_drumstick(d, base, dk, dkk, lt, ltt):
    """Meat blob top-center, bone stub below — all shades of base."""
    d.ellipse([10, 4, 24, 18], fill=base)
    d.arc([10, 4, 24, 18], 120, 300, fill=dk, width=1)   # shadow edge
    d.rectangle([15, 18, 17, 27], fill=lt)                # bone shaft
    d.ellipse([13, 26, 19, 31], fill=lt)                  # bone knob
    d.point((13, 6), fill=ltt)                            # highlight
    d.point((14, 7), fill=ltt)


def draw_bowl(d, base, dk, dkk, lt):
    """Half-oval bowl in lower half — all shades of base."""
    d.ellipse([4, 14, 28, 31], fill=base)
    d.rectangle([4, 28, 28, 31], fill=dkk)               # dark base
    d.rectangle([4, 14, 28, 16], fill=lt)                 # rim highlight
    d.ellipse([7, 16, 25, 24], fill=lighten(base, 0.12))  # surface sheen


def draw_person(d, base, dk, dkk, lt, ltt):
    """Round head, rect torso, two legs — all shades of base."""
    d.ellipse([12, 3, 20, 11], fill=lt)                   # head (lighter)
    d.rectangle([11, 12, 21, 22], fill=base)              # torso
    d.rectangle([11, 23, 15, 30], fill=dk)                # left leg
    d.rectangle([17, 23, 21, 30], fill=dk)                # right leg
    d.point((15, 6), fill=ltt)                            # face highlight


# ── food ──────────────────────────────────────────────────────────────────────

def gen_raw_chicken():
    img = new_img(); d = ImageDraw.Draw(img)
    draw_drumstick(d, *shades("raw_chicken"))
    save(img, "raw_chicken")


def gen_baked_chicken():
    img = new_img(); d = ImageDraw.Draw(img)
    draw_drumstick(d, *shades("baked_chicken"))
    save(img, "baked_chicken")


def gen_fried_chicken():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("fried_chicken")
    pts = [
        (16,4),(20,5),(23,4),(25,7),(26,10),(25,13),(27,15),
        (25,18),(22,18),(17,18),(13,18),(11,16),(9,13),(10,10),(9,7),(12,5),
    ]
    d.polygon(pts, fill=base)
    d.rectangle([15, 18, 17, 27], fill=lt)   # bone
    d.ellipse([13, 26, 19, 31], fill=lt)
    for pos in [(13,8),(18,6),(22,11),(14,14)]:
        d.point(pos, fill=dk)                # batter texture dots
    save(img, "fried_chicken")


def gen_raw_beef():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("raw_beef")
    pts = [(7,10),(14,8),(25,9),(27,18),(24,23),(10,22),(6,17)]
    d.polygon(pts, fill=base)
    d.line([(10,14),(20,13)], fill=lt, width=1)   # marbling
    d.line([(12,18),(22,17)], fill=lt, width=1)
    d.arc([7,10,27,23], 150, 320, fill=dk, width=1)
    save(img, "raw_beef")


def gen_steak():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("steak")
    d.ellipse([5, 9, 27, 23], fill=base)
    d.line([(10,11),(16,21)], fill=dkk, width=2)  # grill marks
    d.line([(16,11),(22,21)], fill=dkk, width=2)
    d.point((8, 12), fill=lt)
    save(img, "steak")


def gen_broccoli():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("broccoli")
    d.rectangle([14, 20, 18, 27], fill=dk)         # stalk
    d.ellipse([8, 8, 24, 22], fill=dk)             # crown shadow
    d.ellipse([10, 6, 20, 16], fill=base)          # crown main
    d.ellipse([11, 7, 15, 11], fill=lt)            # highlight bump
    save(img, "broccoli")


def gen_steamed_broccoli():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("steamed_broccoli")
    d.rectangle([14, 20, 18, 27], fill=dk)
    d.ellipse([8, 8, 24, 22], fill=dk)
    d.ellipse([10, 6, 20, 16], fill=base)
    d.ellipse([11, 7, 15, 11], fill=lt)
    for x in [12, 16, 20]:                         # steam wisps
        d.point((x, 4), fill=ltt)
        d.point((x, 3), fill=rgba(*ltt[:3], 140))
    save(img, "steamed_broccoli")


def gen_potato():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("potato")
    d.ellipse([6, 9, 26, 23], fill=base)
    d.point((13, 15), fill=dkk)                    # eye dots
    d.point((19, 13), fill=dkk)
    d.point((9, 11), fill=ltt)                     # highlight
    save(img, "potato")


def gen_baked_potato():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("baked_potato")
    d.ellipse([6, 9, 26, 23], fill=base)
    d.line([(10,13),(22,13)], fill=dk, width=1)    # split line
    d.point((20, 11), fill=ltt)
    save(img, "baked_potato")


def gen_water():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("water")
    d.ellipse([9, 13, 23, 27], fill=base)
    d.polygon([(16,4),(9,15),(23,15)], fill=base)  # droplet point
    d.arc([9,13,23,27], 140, 320, fill=dk, width=1)
    d.point((12, 18), fill=ltt)
    save(img, "water")


def gen_fries():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("fries")
    for x in [8, 11, 14, 17, 20]:
        d.rectangle([x, 8, x+2, 26], fill=base)
        d.line([(x+2,8),(x+2,26)], fill=dk, width=1)  # shadow side
    d.rectangle([6, 24, 24, 28], fill=dk)              # basket
    save(img, "fries")


def gen_beef_stew():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("beef_stew")
    draw_bowl(d, base, dk, dkk, lt)
    for y in [19, 22]:
        d.line([(9,y),(12,y-2),(15,y),(18,y-2),(21,y)], fill=dkk, width=1)
    save(img, "beef_stew")


def gen_chicken_soup():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("chicken_soup")
    draw_bowl(d, base, dk, dkk, lt)
    d.ellipse([17, 18, 22, 22], fill=dk)               # floating chunk
    save(img, "chicken_soup")


def gen_onion():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("onion")
    d.ellipse([7, 8, 25, 24], fill=base)
    d.arc([9,10,23,22], 0, 360, fill=dk, width=1)      # rings
    d.arc([12,13,20,21], 0, 360, fill=dk, width=1)
    d.rectangle([15, 5, 17, 9], fill=dkk)              # stem
    d.point((10, 11), fill=ltt)
    save(img, "onion")


def gen_onion_soup():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("onion_soup")
    draw_bowl(d, base, dk, dkk, lt)
    d.arc([12,18,20,24], 0, 360, fill=lt, width=1)     # onion ring float
    save(img, "onion_soup")


def gen_blooming_onion():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("blooming_onion")
    cx, cy = 16, 16
    for i in range(8):
        angle = math.radians(i * 45)
        px = cx + int(9 * math.cos(angle))
        py = cy + int(9 * math.sin(angle))
        d.ellipse([px-3, py-3, px+3, py+3], fill=base)
        d.line([(cx,cy),(px,py)], fill=dk, width=1)
    d.ellipse([13, 13, 19, 19], fill=lt)               # center brighter
    save(img, "blooming_onion")


def gen_boiled_egg():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("boiled_egg")
    d.ellipse([8, 6, 24, 26], fill=ltt)                # white (lightest)
    d.ellipse([12, 12, 20, 20], fill=base)             # yolk (base)
    d.arc([12,12,20,20], 120, 300, fill=dk, width=1)
    save(img, "boiled_egg")


def gen_egg():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("egg")
    d.ellipse([9, 7, 23, 25], fill=base)
    d.arc([9,7,23,25], 120, 300, fill=dk, width=1)
    d.point((12, 10), fill=ltt)
    save(img, "egg")


# ── animals ───────────────────────────────────────────────────────────────────

def gen_chicken():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("chicken")
    d.ellipse([7, 12, 23, 24], fill=base)              # body
    d.ellipse([19, 7, 27, 15], fill=base)              # head
    d.polygon([(27,10),(30,11),(27,12)], fill=lt)      # beak (lighter)
    d.polygon([(21,7),(23,4),(25,7)], fill=dkk)        # comb (darkest)
    d.polygon([(7,14),(2,10),(3,16),(2,20),(7,18)], fill=dk)  # tail
    for leg in [((13,24),(11,29)), ((17,24),(15,29))]:
        d.line(leg, fill=dkk, width=1)
    for foot in [((11,29),(9,30)),((11,29),(12,31)),((15,29),(13,30)),((15,29),(16,31))]:
        d.line(foot, fill=dkk, width=1)
    d.point((12, 15), fill=lt)
    save(img, "chicken")


def gen_cow():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("cow")
    d.rectangle([5, 12, 25, 24], fill=lt)              # body (lighter)
    d.ellipse([6, 12, 14, 19], fill=dkk)              # dark patches
    d.ellipse([18, 15, 25, 22], fill=dkk)
    d.rectangle([23, 10, 30, 18], fill=lt)             # head
    d.ellipse([28, 13, 31, 16], fill=base)             # snout
    d.line([(24,10),(22,7)], fill=dk, width=1)         # horns
    d.line([(28,10),(30,7)], fill=dk, width=1)
    for x in [7, 11, 17, 21]:
        d.rectangle([x, 24, x+2, 30], fill=dkk)       # legs
    d.line([(5,14),(2,11)], fill=dkk, width=1)         # tail
    save(img, "cow")


# ── machines ──────────────────────────────────────────────────────────────────

def gen_microwave():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("microwave")
    d.rectangle([3, 9, 29, 25], fill=dk)              # outer shell
    d.rectangle([4, 10, 28, 24], fill=base)           # face panel
    d.rectangle([5, 12, 15, 22], fill=dkk)            # window surround
    d.rectangle([6, 13, 14, 21], fill=darken(COLORS["microwave"], 0.82))  # dark interior
    for r in range(3):                                 # buttons
        for c in range(2):
            d.ellipse([18+c*5, 13+r*3, 20+c*5, 15+r*3], fill=dk)
    d.point((25, 11), fill=ltt)                       # indicator
    save(img, "microwave")


def gen_fryer():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("fryer")
    d.polygon([(8,8),(24,8),(28,26),(4,26)], fill=dk)
    d.polygon([(9,9),(23,9),(27,25),(5,25)], fill=base)
    for x in [11, 15, 19]:
        d.ellipse([x,10,x+3,13], fill=lt)             # oil bubbles
    d.rectangle([13, 5, 19, 9], fill=dkk)             # handle
    save(img, "fryer")


def gen_pot():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("pot")
    d.ellipse([7, 10, 25, 26], fill=dk)
    d.ellipse([8, 11, 24, 25], fill=base)
    d.rectangle([7, 10, 25, 14], fill=dkk)            # rim
    d.rectangle([3, 12, 7, 16], fill=dk)              # handles
    d.rectangle([25, 12, 29, 16], fill=dk)
    d.ellipse([8, 7, 24, 13], fill=base)              # lid
    d.ellipse([14, 5, 18, 9], fill=dk)               # knob
    d.point((10, 14), fill=lt)
    save(img, "pot")


def gen_coop():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("coop")
    d.rectangle([5, 15, 27, 28], fill=base)           # walls
    d.polygon([(3,15),(16,5),(29,15)], fill=dk)       # roof
    d.rectangle([13, 20, 19, 28], fill=dkk)           # door
    d.ellipse([13, 18, 19, 23], fill=dkk)             # door arch
    d.line([(5,20),(27,20)], fill=dk, width=1)        # planks
    d.line([(5,25),(27,25)], fill=dk, width=1)
    d.point((7, 17), fill=lt)
    save(img, "coop")


def gen_meat_machine():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("meat_machine")
    d.rectangle([4, 14, 28, 27], fill=base)
    d.polygon([(12,5),(20,5),(23,14),(9,14)], fill=dk)     # funnel
    d.rectangle([26, 18, 30, 24], fill=dk)                 # chute
    d.rectangle([28, 20, 32, 26], fill=dkk)
    for pos in [(6,16),(6,24),(26,16),(26,24)]:
        d.ellipse([pos[0],pos[1],pos[0]+2,pos[1]+2], fill=dkk)  # rivets
    d.point((6, 15), fill=lt)
    save(img, "meat_machine")


def gen_incubator():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("incubator")
    d.rectangle([4, 8, 28, 27], fill=dk)
    d.rectangle([5, 9, 27, 26], fill=base)
    d.ellipse([9, 12, 23, 23], fill=dkk)              # window surround
    d.ellipse([11, 14, 21, 21], fill=lt)              # glow
    d.ellipse([13, 15, 19, 20], fill=ltt)             # inner glow
    d.ellipse([25, 10, 27, 12], fill=lt)              # indicator
    save(img, "incubator")


# ── gardens ───────────────────────────────────────────────────────────────────

def gen_broccoli_garden():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("broccoli_garden")
    d.rectangle([2, 23, 30, 30], fill=dkk)            # soil
    for (cx, cy) in [(9,14),(23,14),(9,22),(23,22)]:
        d.rectangle([cx-1, cy, cx+1, cy+4], fill=dk)
        d.ellipse([cx-4, cy-6, cx+4, cy+1], fill=base)
    save(img, "broccoli_garden")


def gen_onion_garden():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("onion_garden")
    d.rectangle([2, 22, 30, 30], fill=dkk)            # soil
    for x in [5, 10, 15, 20, 25]:
        d.ellipse([x-2, 21, x+2, 25], fill=base)      # bulb
        d.line([(x,21),(x-1,13)], fill=lt, width=1)
        d.line([(x,21),(x+1,11)], fill=ltt, width=1)  # shoots
    save(img, "onion_garden")


# ── people ────────────────────────────────────────────────────────────────────

def gen_customer():
    img = new_img(); d = ImageDraw.Draw(img)
    draw_person(d, *shades("customer"))
    save(img, "customer")


def gen_merchant():
    img = new_img(); d = ImageDraw.Draw(img)
    base, dk, dkk, lt, ltt = shades("merchant")
    draw_person(d, base, dk, dkk, lt, ltt)
    d.rectangle([10, 2, 22, 5], fill=dkk)             # hat brim
    d.rectangle([12, 0, 20, 3], fill=dk)              # hat crown
    d.ellipse([22, 18, 26, 22], fill=lt)              # coin bag
    save(img, "merchant")


# ── main ──────────────────────────────────────────────────────────────────────

GENERATORS = [
    gen_raw_chicken, gen_baked_chicken, gen_fried_chicken,
    gen_raw_beef, gen_steak,
    gen_broccoli, gen_steamed_broccoli,
    gen_potato, gen_baked_potato,
    gen_water, gen_fries,
    gen_beef_stew, gen_chicken_soup,
    gen_onion, gen_onion_soup, gen_blooming_onion,
    gen_boiled_egg, gen_egg,
    gen_chicken, gen_cow,
    gen_microwave, gen_fryer, gen_pot, gen_coop, gen_meat_machine, gen_incubator,
    gen_broccoli_garden, gen_onion_garden,
    gen_customer, gen_merchant,
]

if __name__ == "__main__":
    print(f"Generating {len(GENERATORS)} icons into {os.path.abspath(OUT_DIR)}/")
    for fn in GENERATORS:
        fn()
    print("Done.")
