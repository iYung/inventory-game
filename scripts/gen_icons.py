#!/usr/bin/env python3
"""Generate 32x32 RGBA pixel-art icons for every item type in the inventory game."""

import os
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "items")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 32


def new_img():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img, type_id):
    path = os.path.join(OUT_DIR, f"{type_id}.png")
    img.save(path)
    print(f"  wrote {path}")


# ── helpers ───────────────────────────────────────────────────────────────────

def draw_drumstick(draw, color_meat, color_bone, highlight=None):
    """Drumstick silhouette.  Meat blob top-center, bone stub below."""
    # meat blob (circle)
    draw.ellipse([10, 4, 24, 18], fill=color_meat)
    # bone shaft
    draw.rectangle([15, 18, 17, 27], fill=color_bone)
    # bone tip knob
    draw.ellipse([13, 26, 19, 31], fill=color_bone)
    if highlight:
        draw.point((13, 6), fill=highlight)
        draw.point((14, 7), fill=highlight)


def draw_bowl(draw, liquid_color, surface_color=None):
    """Half-oval bowl sitting in lower half of canvas."""
    # bowl rim / body
    draw.ellipse([4, 14, 28, 31], fill=liquid_color)
    # cut off bottom overflow with a dark base line
    draw.rectangle([4, 28, 28, 31], fill=(50, 35, 20, 255))
    # rim highlight strip
    draw.rectangle([4, 14, 28, 16], fill=(200, 190, 175, 255))
    if surface_color:
        draw.ellipse([7, 16, 25, 24], fill=surface_color)


def draw_person(draw, skin, shirt):
    """Generic person: round head, rect torso, two legs."""
    # head
    draw.ellipse([12, 3, 20, 11], fill=skin)
    # torso
    draw.rectangle([11, 12, 21, 22], fill=shirt)
    # legs
    draw.rectangle([11, 23, 15, 30], fill=(60, 60, 80, 255))
    draw.rectangle([17, 23, 21, 30], fill=(60, 60, 80, 255))


# ── food items ────────────────────────────────────────────────────────────────

def gen_raw_chicken():
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_drumstick(d, (210, 110, 100, 255), (230, 210, 190, 255))
    save(img, "raw_chicken")


def gen_baked_chicken():
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_drumstick(d, (180, 120, 50, 255), (220, 195, 150, 255),
                   highlight=(240, 230, 180, 255))
    save(img, "baked_chicken")


def gen_fried_chicken():
    img = new_img()
    d = ImageDraw.Draw(img)
    # bumpy outline — draw polygon instead of ellipse for jagged batter
    pts = [
        (16, 4), (20, 5), (23, 4), (25, 7), (26, 10),
        (25, 13), (27, 15), (25, 18), (22, 18),
        (17, 18), (13, 18), (11, 16), (9, 13),
        (10, 10), (9, 7), (12, 5),
    ]
    d.polygon(pts, fill=(220, 170, 40, 255))
    # bone
    d.rectangle([15, 18, 17, 27], fill=(230, 210, 180, 255))
    d.ellipse([13, 26, 19, 31], fill=(230, 210, 180, 255))
    save(img, "fried_chicken")


def gen_raw_beef():
    img = new_img()
    d = ImageDraw.Draw(img)
    pts = [(7, 10), (14, 8), (25, 9), (27, 18), (24, 23), (10, 22), (6, 17)]
    d.polygon(pts, fill=(160, 40, 40, 255))
    # marbling lines
    d.line([(10, 14), (20, 13)], fill=(200, 120, 120, 255), width=1)
    d.line([(12, 18), (22, 17)], fill=(200, 120, 120, 255), width=1)
    save(img, "raw_beef")


def gen_steak():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([5, 9, 27, 23], fill=(110, 55, 20, 255))
    # grill marks
    d.line([(10, 11), (16, 21)], fill=(70, 30, 10, 255), width=2)
    d.line([(16, 11), (22, 21)], fill=(70, 30, 10, 255), width=2)
    save(img, "steak")


def gen_broccoli():
    img = new_img()
    d = ImageDraw.Draw(img)
    # stalk
    d.rectangle([14, 20, 18, 27], fill=(160, 140, 80, 255))
    # crown
    d.ellipse([8, 8, 24, 22], fill=(30, 120, 30, 255))
    d.ellipse([10, 6, 20, 16], fill=(40, 140, 40, 255))
    save(img, "broccoli")


def gen_steamed_broccoli():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.rectangle([14, 20, 18, 27], fill=(160, 140, 80, 255))
    d.ellipse([8, 8, 24, 22], fill=(50, 180, 50, 255))
    d.ellipse([10, 6, 20, 16], fill=(70, 200, 70, 255))
    # steam dots
    for x in [12, 16, 20]:
        d.point((x, 4), fill=(255, 255, 255, 200))
        d.point((x, 3), fill=(255, 255, 255, 120))
    save(img, "steamed_broccoli")


def gen_potato():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([6, 9, 26, 23], fill=(180, 150, 90, 255))
    # eye dots
    d.point((13, 15), fill=(80, 60, 30, 255))
    d.point((19, 13), fill=(80, 60, 30, 255))
    save(img, "potato")


def gen_baked_potato():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([6, 9, 26, 23], fill=(160, 110, 50, 255))
    # split line
    d.line([(10, 13), (22, 13)], fill=(120, 80, 30, 255), width=1)
    # white highlight
    d.point((20, 11), fill=(255, 240, 200, 255))
    save(img, "baked_potato")


def gen_water():
    img = new_img()
    d = ImageDraw.Draw(img)
    # teardrop: circle body + triangle tip pointing up
    d.ellipse([9, 13, 23, 27], fill=(60, 140, 240, 255))
    d.polygon([(16, 4), (9, 15), (23, 15)], fill=(60, 140, 240, 255))
    # highlight
    d.point((12, 18), fill=(160, 210, 255, 255))
    save(img, "water")


def gen_fries():
    img = new_img()
    d = ImageDraw.Draw(img)
    # 5 vertical sticks
    xs = [8, 11, 14, 17, 20]
    for x in xs:
        d.rectangle([x, 8, x + 2, 26], fill=(240, 200, 50, 255))
    # basket hint at bottom
    d.rectangle([6, 24, 24, 28], fill=(180, 100, 50, 255))
    save(img, "fries")


def gen_beef_stew():
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_bowl(d, (100, 55, 20, 255), (130, 75, 30, 255))
    # wavy lines on surface
    for y in [19, 22]:
        d.line([(9, y), (12, y - 2), (15, y), (18, y - 2), (21, y)], fill=(80, 40, 10, 255), width=1)
    save(img, "beef_stew")


def gen_chicken_soup():
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_bowl(d, (210, 180, 80, 255), (230, 200, 100, 255))
    # small floating chunk
    d.ellipse([17, 18, 22, 22], fill=(200, 150, 70, 255))
    save(img, "chicken_soup")


def gen_onion():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([7, 8, 25, 24], fill=(220, 190, 220, 255))
    # concentric ring lines
    d.arc([9, 10, 23, 22], 0, 360, fill=(150, 100, 160, 255), width=1)
    d.arc([12, 13, 20, 21], 0, 360, fill=(150, 100, 160, 255), width=1)
    # green stem
    d.rectangle([15, 5, 17, 9], fill=(60, 160, 60, 255))
    save(img, "onion")


def gen_onion_soup():
    img = new_img()
    d = ImageDraw.Draw(img)
    draw_bowl(d, (180, 130, 40, 255), (200, 150, 60, 255))
    # small onion ring shape
    d.arc([12, 18, 20, 24], 0, 360, fill=(240, 220, 180, 255), width=1)
    save(img, "onion_soup")


def gen_blooming_onion():
    img = new_img()
    d = ImageDraw.Draw(img)
    import math
    cx, cy = 16, 16
    color = (200, 150, 50, 255)
    dark = (140, 90, 20, 255)
    # center
    d.ellipse([13, 13, 19, 19], fill=color)
    # petals
    for i in range(8):
        angle = math.radians(i * 45)
        px = cx + int(9 * math.cos(angle))
        py = cy + int(9 * math.sin(angle))
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=color)
        # petal line
        d.line([(cx, cy), (px, py)], fill=dark, width=1)
    save(img, "blooming_onion")


def gen_boiled_egg():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([8, 6, 24, 26], fill=(240, 240, 235, 255))
    # yolk
    d.ellipse([12, 12, 20, 20], fill=(240, 200, 50, 255))
    save(img, "boiled_egg")


def gen_egg():
    img = new_img()
    d = ImageDraw.Draw(img)
    d.ellipse([9, 7, 23, 25], fill=(240, 230, 210, 255))
    save(img, "egg")


# ── animals ───────────────────────────────────────────────────────────────────

def gen_chicken():
    img = new_img()
    d = ImageDraw.Draw(img)
    # body
    d.ellipse([7, 12, 23, 24], fill=(200, 130, 50, 255))
    # head
    d.ellipse([19, 7, 27, 15], fill=(200, 130, 50, 255))
    # beak
    d.polygon([(27, 10), (30, 11), (27, 12)], fill=(240, 180, 40, 255))
    # comb
    d.polygon([(21, 7), (23, 4), (25, 7)], fill=(220, 50, 50, 255))
    # tail fan
    d.polygon([(7, 14), (2, 10), (3, 16), (2, 20), (7, 18)], fill=(180, 110, 40, 255))
    # legs
    d.line([(13, 24), (11, 29)], fill=(240, 180, 40, 255), width=1)
    d.line([(17, 24), (15, 29)], fill=(240, 180, 40, 255), width=1)
    # feet
    d.line([(11, 29), (9, 30)], fill=(240, 180, 40, 255), width=1)
    d.line([(11, 29), (12, 31)], fill=(240, 180, 40, 255), width=1)
    d.line([(15, 29), (13, 30)], fill=(240, 180, 40, 255), width=1)
    d.line([(15, 29), (16, 31)], fill=(240, 180, 40, 255), width=1)
    save(img, "chicken")


def gen_cow():
    img = new_img()
    d = ImageDraw.Draw(img)
    # body — white base
    d.rectangle([5, 12, 25, 24], fill=(240, 240, 240, 255))
    # black patches
    d.ellipse([6, 12, 14, 19], fill=(40, 40, 40, 255))
    d.ellipse([18, 15, 25, 22], fill=(40, 40, 40, 255))
    # head
    d.rectangle([23, 10, 30, 18], fill=(240, 240, 240, 255))
    d.ellipse([28, 13, 31, 16], fill=(200, 160, 160, 255))  # snout
    # horns
    d.line([(24, 10), (22, 7)], fill=(200, 170, 100, 255), width=1)
    d.line([(28, 10), (30, 7)], fill=(200, 170, 100, 255), width=1)
    # legs (4)
    for x in [7, 11, 17, 21]:
        d.rectangle([x, 24, x + 2, 30], fill=(40, 40, 40, 255))
    # tail
    d.line([(5, 14), (2, 11)], fill=(40, 40, 40, 255), width=1)
    save(img, "cow")


# ── machines ──────────────────────────────────────────────────────────────────

def gen_microwave():
    img = new_img()
    d = ImageDraw.Draw(img)
    # body
    d.rectangle([3, 9, 29, 25], fill=(160, 160, 165, 255))
    d.rectangle([4, 10, 28, 24], fill=(140, 140, 145, 255))
    # window (left)
    d.rectangle([5, 12, 15, 22], fill=(30, 30, 35, 255))
    d.rectangle([6, 13, 14, 21], fill=(20, 60, 20, 200))
    # buttons (right)
    for r in range(3):
        for c in range(2):
            d.ellipse([18 + c * 5, 13 + r * 3, 20 + c * 5, 15 + r * 3],
                      fill=(80, 80, 90, 255))
    save(img, "microwave")


def gen_fryer():
    img = new_img()
    d = ImageDraw.Draw(img)
    # trapezoid wider at bottom
    d.polygon([(8, 8), (24, 8), (28, 26), (4, 26)], fill=(70, 70, 75, 255))
    d.polygon([(9, 9), (23, 9), (27, 25), (5, 25)], fill=(90, 90, 95, 255))
    # oil bubble dots at top
    for x in [11, 15, 19]:
        d.ellipse([x, 10, x + 3, 13], fill=(200, 170, 50, 200))
    # handle
    d.rectangle([13, 5, 19, 9], fill=(100, 100, 105, 255))
    save(img, "fryer")


def gen_pot():
    img = new_img()
    d = ImageDraw.Draw(img)
    # pot body
    d.ellipse([7, 10, 25, 26], fill=(130, 130, 140, 255))
    d.ellipse([8, 11, 24, 25], fill=(150, 150, 160, 255))
    # rim
    d.rectangle([7, 10, 25, 14], fill=(110, 110, 120, 255))
    # handles
    d.rectangle([3, 12, 7, 16], fill=(110, 110, 120, 255))
    d.rectangle([25, 12, 29, 16], fill=(110, 110, 120, 255))
    # lid
    d.ellipse([8, 7, 24, 13], fill=(120, 120, 130, 255))
    d.ellipse([14, 5, 18, 9], fill=(100, 100, 110, 255))
    save(img, "pot")


def gen_coop():
    img = new_img()
    d = ImageDraw.Draw(img)
    # walls
    d.rectangle([5, 15, 27, 28], fill=(160, 110, 60, 255))
    # roof (peaked)
    d.polygon([(3, 15), (16, 5), (29, 15)], fill=(120, 70, 30, 255))
    # door
    d.rectangle([13, 20, 19, 28], fill=(60, 35, 15, 255))
    # door arch top
    d.ellipse([13, 18, 19, 23], fill=(60, 35, 15, 255))
    # wood plank lines
    d.line([(5, 20), (27, 20)], fill=(130, 85, 45, 255), width=1)
    d.line([(5, 25), (27, 25)], fill=(130, 85, 45, 255), width=1)
    save(img, "coop")


def gen_meat_machine():
    img = new_img()
    d = ImageDraw.Draw(img)
    # main body
    d.rectangle([4, 14, 28, 27], fill=(140, 140, 145, 255))
    # funnel on top
    d.polygon([(12, 5), (20, 5), (23, 14), (9, 14)], fill=(120, 120, 125, 255))
    # chute on right side
    d.rectangle([26, 18, 30, 24], fill=(110, 110, 115, 255))
    d.rectangle([28, 20, 32, 26], fill=(100, 100, 105, 255))
    # rivets
    for pos in [(6, 16), (6, 24), (26, 16), (26, 24)]:
        d.ellipse([pos[0], pos[1], pos[0] + 2, pos[1] + 2], fill=(100, 100, 105, 255))
    save(img, "meat_machine")


def gen_incubator():
    img = new_img()
    d = ImageDraw.Draw(img)
    # casing
    d.rectangle([4, 8, 28, 27], fill=(50, 160, 160, 255))
    d.rectangle([5, 9, 27, 26], fill=(60, 180, 180, 255))
    # oval window
    d.ellipse([9, 12, 23, 23], fill=(40, 40, 40, 255))
    # warm glow inside window
    d.ellipse([11, 14, 21, 21], fill=(240, 160, 40, 200))
    d.ellipse([13, 15, 19, 20], fill=(255, 220, 120, 255))
    # indicator light
    d.ellipse([25, 10, 27, 12], fill=(50, 255, 50, 255))
    save(img, "incubator")


# ── gardens ───────────────────────────────────────────────────────────────────

def gen_broccoli_garden():
    img = new_img()
    d = ImageDraw.Draw(img)
    # soil strip
    d.rectangle([2, 23, 30, 30], fill=(90, 60, 30, 255))
    # 4 mini broccoli in 2x2
    for (cx, cy) in [(9, 14), (23, 14), (9, 22), (23, 22)]:
        # stalk
        d.rectangle([cx - 1, cy, cx + 1, cy + 4], fill=(150, 130, 70, 255))
        # crown
        d.ellipse([cx - 4, cy - 6, cx + 4, cy + 1], fill=(30, 120, 30, 255))
    save(img, "broccoli_garden")


def gen_onion_garden():
    img = new_img()
    d = ImageDraw.Draw(img)
    # soil strip
    d.rectangle([2, 22, 30, 30], fill=(90, 60, 30, 255))
    # 5 onion shoots
    for x in [5, 10, 15, 20, 25]:
        # bulb hint
        d.ellipse([x - 2, 21, x + 2, 25], fill=(200, 170, 200, 255))
        # green shoot
        d.line([(x, 21), (x - 1, 13)], fill=(60, 160, 60, 255), width=1)
        d.line([(x, 21), (x + 1, 11)], fill=(80, 190, 80, 255), width=1)
    save(img, "onion_garden")


# ── people ────────────────────────────────────────────────────────────────────

def gen_customer():
    img = new_img()
    d = ImageDraw.Draw(img)
    skin = (220, 180, 140, 255)
    shirt = (100, 130, 200, 255)
    draw_person(d, skin, shirt)
    save(img, "customer")


def gen_merchant():
    img = new_img()
    d = ImageDraw.Draw(img)
    skin = (220, 180, 140, 255)
    shirt = (30, 180, 180, 255)
    draw_person(d, skin, shirt)
    # hat (flat brim + crown)
    d.rectangle([10, 2, 22, 5], fill=(20, 120, 120, 255))  # brim
    d.rectangle([12, 0, 20, 3], fill=(20, 120, 120, 255))  # crown
    # coin bag dot at side
    d.ellipse([22, 18, 26, 22], fill=(220, 180, 40, 255))
    save(img, "merchant")


# ── main ──────────────────────────────────────────────────────────────────────

GENERATORS = [
    gen_raw_chicken,
    gen_baked_chicken,
    gen_fried_chicken,
    gen_raw_beef,
    gen_steak,
    gen_broccoli,
    gen_steamed_broccoli,
    gen_potato,
    gen_baked_potato,
    gen_water,
    gen_fries,
    gen_beef_stew,
    gen_chicken_soup,
    gen_onion,
    gen_onion_soup,
    gen_blooming_onion,
    gen_boiled_egg,
    gen_egg,
    gen_chicken,
    gen_cow,
    gen_microwave,
    gen_fryer,
    gen_pot,
    gen_coop,
    gen_meat_machine,
    gen_incubator,
    gen_broccoli_garden,
    gen_onion_garden,
    gen_customer,
    gen_merchant,
]

if __name__ == "__main__":
    print(f"Generating {len(GENERATORS)} icons into {os.path.abspath(OUT_DIR)}/")
    for fn in GENERATORS:
        fn()
    print("Done.")
