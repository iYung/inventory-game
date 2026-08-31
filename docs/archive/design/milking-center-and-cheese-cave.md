# Milking Center & Cheese Cave

## Goal

Add a **Milking Center** building (same footprint as barn, 4×3 inventory) that produces 2 milk per cow overnight. Add **Milk** as a new item with no hover label. Add a **Cheese Cave** room (2×2 footprint and inventory) that converts all milk inside it to cheese overnight. Add **Cheese** as a new item.

---

## Affected files

- `lua/game/data/item_defs.lua` — add `milking_center`, `milk`, `cheese_cave`, `cheese`
- `lua/game/item.lua` — fix `overnight_tick` to compute repeats before removal (needed for cheese cave all-at-once conversion)
- `lua/game/config.lua` — expand `GRID_ROWS` from 9 to 12 to fit new items
- `game/scenes/kitchen_scene.lua` — place `milking_center` and `cheese_cave` in starting layout
- `scripts/gen_icons.py` — add icon generators for `milk`, `cheese`, `milking_center`, `cheese_cave`
- `assets/images/items/milk.png` — new icon
- `assets/images/items/cheese.png` — new icon
- `assets/images/items/milking_center.png` — new icon
- `assets/images/items/cheese_cave.png` — new icon
- `tests/test_overnight.lua` — add tests for milking center and cheese cave overnight behaviors

---

## What changes

### item_defs.lua — four new entries

**milk** — simple 1×1 ingredient item, no food tags:
```lua
milk = {
    name     = "Milk",
    footprint = { { 0, 0 } },
    color    = { 0.92, 0.92, 0.96, 1 },  -- near-white, slight blue tint
}
```

**cheese** — simple 1×1 produced item, no food tags:
```lua
cheese = {
    name     = "Cheese",
    footprint = { { 0, 0 } },
    color    = { 0.95, 0.80, 0.20, 1 },  -- golden yellow
}
```

**milking_center** — 3×3 footprint (same as barn), 4×3 panel, produces 2 milk per cow overnight, cows preserved:
```lua
milking_center = {
    name      = "Milking Center",
    footprint = {
        {0,0},{1,0},{2,0},
        {0,1},{1,1},{2,1},
        {0,2},{1,2},{2,2},
    },
    color     = { 0.60, 0.55, 0.70, 1 },  -- muted purple/blue
    has_panel  = true,
    panel_cols = 4,
    panel_rows = 3,
    overnight_actions = {
        {
            requires = { cow = 1 },
            produces = { milk = 2 },
            nights   = 1,
            preserve = true,
            per_item = "cow",
        },
    },
}
```

`preserve = true` keeps cows in the panel; `per_item = "cow"` repeats production once per cow, so `n` cows → `n × 2` milk.

**cheese_cave** — 2×2 footprint, 2×2 panel, all milk in panel converts to cheese overnight:
```lua
cheese_cave = {
    name      = "Cheese Cave",
    footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
    color     = { 0.55, 0.42, 0.30, 1 },  -- earthy stone brown
    has_panel  = true,
    panel_cols = 2,
    panel_rows = 2,
    overnight_actions = {
        {
            requires = { milk = 1 },
            produces = { cheese = 1 },
            nights   = 1,
            per_item = "milk",
        },
    },
}
```

`per_item = "milk"` repeats once per milk present; no `preserve` so milk is consumed. Every milk in the cave converts to 1 cheese.

### item.lua — fix overnight_tick removal order

The current code removes `action.requires` once *before* computing `repeats`. For cheese cave, this would remove only 1 milk but produce `milk_count` cheeses (wrong).

Fix: compute `repeats` first, then remove `count * repeats` when `preserve` is not set. This is backward-compatible because items without `per_item` have `repeats = 1`, so `count * 1 = count` — same as before.

**Current** (in `overnight_tick`, inside `state.nights_elapsed >= action.nights` block):
```lua
if not action.preserve then
    for type_id, count in pairs(action.requires or {}) do
        remove_matching(self.panel, type_id, count)
    end
end
local step = action.per_item_step or 1
local repeats = action.per_item
    and math.floor((counts[action.per_item] or 0) / step)
    or 1
```

**Fixed**:
```lua
local step = action.per_item_step or 1
local repeats = action.per_item
    and math.floor((counts[action.per_item] or 0) / step)
    or 1
if not action.preserve then
    for type_id, count in pairs(action.requires or {}) do
        remove_matching(self.panel, type_id, count * repeats)
    end
end
```

### config.lua — expand grid

`GRID_ROWS`: 9 → 12. Adds three new rows at the bottom for the new items without displacing any existing layout.

### kitchen_scene.lua — initial placement

Two new items placed in the new rows (9–11):

- **milking_center** at `(0, 9)`: 3×3 footprint, starts empty (player moves cows in manually)
- **cheese_cave** at `(3, 9)`: 2×2 footprint, starts empty

### scripts/gen_icons.py — four new generators

New COLORS entries and `gen_*` functions for `milk`, `cheese`, `milking_center`, `cheese_cave`. Follow the 3-shade rule.

---

## What stays the same

- All existing overnight_action behavior (coop, incubator, barn) is backward-compatible after the fix: `repeats = 1` for actions without `per_item`, so `count * 1 = count` — identical to current.
- No changes to daytime actions, customer system, or item panel rendering.
- Barn and coop are unaffected; cows in the barn still breed. The milking center is a *separate* building the player uses for milk production.

---

## Open questions

None — requirements fully specified.
