# Garden

## Goal

Replace the separate `broccoli_garden` and `onion_garden` (2×2, static daily refill) with a single unified `garden` item (3×3) whose onion and broccoli contents spread overnight into adjacent empty cells, giving the player an organic, position-dependent growth mechanic instead of a reset-on-new-day refill.

## Affected files

- `lua/game/data/item_defs.lua` — remove `broccoli_garden` / `onion_garden`, add `garden`
- `lua/game/item.lua` — add `Item:garden_tick()` (spread logic) called from overnight path
- `game/scenes/kitchen_scene.lua` — remove old garden placements, place one `garden` with a seed onion and a seed broccoli inside
- `tests/test_overnight.lua` — add spread tests
- `scripts/gen_icons.py` — add garden icon
- `assets/images/items/garden.png` — generated icon

## What changes

### New item: `garden`

```lua
garden = {
    name      = "Garden",
    footprint = { {0,0},{1,0},{2,0}, {0,1},{1,1},{2,1}, {0,2},{1,2},{2,2} },
    color     = { 0.25, 0.48, 0.18, 1 },
    has_panel  = true,
    panel_cols = 3,
    panel_rows = 3,
    -- no actions, no daily_fill, no overnight_actions
    garden_spread = { "onion", "broccoli" },
}
```

### Spread mechanic (`garden_spread`)

Triggered by `Item:overnight_tick()` when `def.garden_spread` is set, after the existing `overnight_actions` block. For each spreadable type in `garden_spread`:

1. Snapshot which (col, row) cells are occupied by that type.
2. For each such cell, collect orthogonal neighbors (up/down/left/right) that are in-bounds and empty.
3. Place one new item of that type in each empty neighbor (capped to the panel's free space).

Spreading is symmetric and simultaneous — a new item placed this tick does not itself spread until the next tick.

### Starting layout

The kitchen scene places two `garden` items at suitable free cells (to be determined in the checklist). Both start empty — the player seeds them by dragging onions and/or broccoli into the panels.

### Old gardens removed

`broccoli_garden` and `onion_garden` definitions are deleted from `item_defs.lua`. Their placements in `kitchen_scene.lua` are replaced by the single `garden` placement. Any test that references `broccoli_garden` or `onion_garden` by name is removed or updated.

## What stays the same

- `daily_fill` on non-garden items (coop, incubator) — untouched
- `overnight_actions` — untouched; `garden_spread` is a separate block in the same `overnight_tick` pass
- Drag, drop, and panel interaction — the garden's panel is a normal Grid; items can be placed in and removed from it freely

## Open questions

None — proceeding to checklist.
