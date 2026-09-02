## Goal

Add a "Container" item: a 2×2 placeable grid item with a 6×6 internal panel used purely for storing other items. No actions, no overnight behavior — it is a large passive storage box.

## Affected files

- `lua/game/data/item_defs.lua` — add the `container` entry
- `assets/images/items/container.png` — icon (optional; falls back to color swatch)

## What changes

- A new item type `container` is added to `item_defs`:
  - `footprint`: 2×2 (4 cells: `{0,0},{1,0},{0,1},{1,1}`) — same shape as the microwave, coop, fryer
  - `has_panel = true`, `panel_cols = 6`, `panel_rows = 6`
  - `color`: a neutral storage-crate tone (e.g. `{ 0.60, 0.50, 0.35, 1 }`)
  - No `actions`, no `overnight_actions`, no `garden_spread`, no `tags`

## What stays the same

- No changes to `item.lua`, `grid.lua`, `item_panel.lua`, or any scene logic — the existing `has_panel` path already handles arbitrary panel sizes.
- The existing use of `container` as a **recipe field name** in `item_defs.lua` is unaffected; that field references a type_id string at runtime, and looking up `item_defs["container"]` is unambiguous.
- No new actions, recipes, or overnight behavior needed.

## Open questions

None — the feature is fully specified and requires only a single data-layer addition.
