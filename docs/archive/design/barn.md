# Barn

## Goal

Add a `barn` item — a 3×3 structure with a 6×6 inventory panel. Cows stored inside breed overnight: for every 2 cows in the barn, 1 new cow is produced each night.

## Affected files

- `lua/game/data/item_defs.lua` — add `barn` definition
- `lua/game/item.lua` — add `per_item_step` support in `overnight_tick`
- `game/scenes/kitchen_scene.lua` — place barn in the starting layout
- `tests/test_overnight.lua` — add barn breeding tests
- `assets/images/items/barn.png` — new icon (generated via `scripts/gen_icons.py`)

## What changes

### item_defs.lua — new `barn` entry

```lua
barn = {
    name      = "Barn",
    footprint = {
        {0,0},{1,0},{2,0},
        {0,1},{1,1},{2,1},
        {0,2},{1,2},{2,2},
    },
    color     = { 0.65, 0.35, 0.20, 1 },
    has_panel  = true,
    panel_cols = 6,
    panel_rows = 6,
    overnight_actions = {
        {
            requires      = { cow = 2 },
            produces      = { cow = 1 },
            nights        = 1,
            preserve      = true,
            per_item      = "cow",
            per_item_step = 2,
        },
    },
}
```

`preserve = true` keeps all cows in the barn; only new cows are added. `per_item = "cow"` with `per_item_step = 2` computes repeats as `floor(cow_count / 2)`.

### item.lua — `per_item_step` in `overnight_tick`

The current repeats line:
```lua
local repeats = action.per_item and (counts[action.per_item] or 1) or 1
```

Becomes:
```lua
local step = action.per_item_step or 1
local repeats = action.per_item
    and math.floor((counts[action.per_item] or 0) / step)
    or 1
```

This is backward-compatible: all existing `overnight_actions` omit `per_item_step`, so `step` defaults to 1 and floor(n/1) = n — same as before.

### kitchen_scene.lua — initial placement

Place a `barn` in the starting grid. The 3×3 footprint needs 3 rows × 3 cols of free space. Current layout comment in the file drives exact coordinates; the barn goes at a free 3×3 block (to be confirmed against the live grid layout).

### tests/test_overnight.lua — new tests

- 2 cows → 1 new cow (total 3)
- 4 cows → 2 new cows (total 6)
- 1 cow → 0 new cows (requirement of 2 not met)
- 6 cows, panel has only 1 free cell → 1 new cow (space-capped)

## What stays the same

- All existing `overnight_actions` behavior (coop, incubator) is unaffected.
- Barn has no daytime `actions` — it is a passive overnight-only structure.
- Cows in the barn are never consumed by the breeding action.

## Open questions

None — requirements are fully specified.
