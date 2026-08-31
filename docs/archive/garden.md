## Garden Checklist

- [x] Task A — `lua/game/config.lua` — Increase `GRID_ROWS` from 6 to 9 so two 3×3 gardens fit in the new bottom rows (6–8) without displacing any existing item.

- [x] Task B — `lua/game/data/item_defs.lua` — Delete the `broccoli_garden` and `onion_garden` entries. Add a new `garden` entry: 3×3 footprint (all 9 cells), `has_panel = true`, `panel_cols = 3`, `panel_rows = 3`, no `actions`, no `daily_fill`, no `overnight_actions`; add `garden_spread = { "onion", "broccoli" }` field.

- [x] Task C — `lua/game/item.lua` — Handle `garden_spread` in `Item:overnight_tick()`. After the existing `overnight_actions` block, if `def.garden_spread` is set: for each type_id in the list, snapshot which panel cells it occupies, collect their orthogonally-adjacent empty in-bounds neighbors, and place one new item of that type per empty neighbor. New items placed in this pass do not spread again this tick.

- [x] Task D — `game/scenes/kitchen_scene.lua` — Remove the `broccoli_garden` and `onion_garden` placements. Place two `garden` items: first at anchor (0,6), second at anchor (3,6). Both start with empty panels. Update the existing `assert` comments to reflect the new layout.

- [x] Task E — `scripts/gen_icons.py` — Add a `garden` icon entry (3-shade green, matching the item's color `{ 0.25, 0.48, 0.18 }`). Run the script to produce `assets/images/items/garden.png`.

- [x] Task F — `tests/test_overnight.lua` — Add garden spread tests: (1) a single onion in center spreads to all 4 orthogonal neighbors after one tick; (2) a broccoli in a corner spreads only to its 2 in-bounds neighbors; (3) a fully-occupied panel does not error; (4) two different types spread independently without interfering; (5) `overnight_tick` on a garden with an empty panel is a no-op.
