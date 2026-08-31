## Milking Center & Cheese Cave Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `milk` (name="Milk", no tags, 1×1, near-white color `{0.92,0.92,0.96,1}`), `cheese` (name="Cheese", no tags, 1×1, golden yellow `{0.95,0.80,0.20,1}`), `milking_center` (name="Milking Center", 3×3 footprint same as barn, has_panel, panel_cols=4, panel_rows=3, overnight_actions: preserve=true, per_item="cow", requires={cow=1}, produces={milk=2}, nights=1), `cheese_cave` (name="Cheese Cave", 2×2 footprint, has_panel, panel_cols=2, panel_rows=2, overnight_actions: per_item="milk", requires={milk=1}, produces={cheese=1}, nights=1)

- [x] Task B — `lua/game/item.lua` — In `overnight_tick`, inside the `state.nights_elapsed >= action.nights` block: move the `repeats` computation to BEFORE the removal block, and change `remove_matching(self.panel, type_id, count)` to `remove_matching(self.panel, type_id, count * repeats)`. This ensures all milk converts to cheese (not just 1). Backward-compatible: actions without `per_item` get repeats=1, so count*1=count.

- [x] Task C — `lua/game/config.lua` — Change `GRID_ROWS` from 9 to 12

- [x] Task D — `game/scenes/kitchen_scene.lua` — Place `milking_center` at (0,9) and `cheese_cave` at (3,9) in `on_enter`, both starting empty

- [x] Task E — `scripts/gen_icons.py` — Add `milk`, `cheese`, `milking_center`, `cheese_cave` to the COLORS table and write `gen_milk`, `gen_cheese`, `gen_milking_center`, `gen_cheese_cave` generator functions; add them to GENERATORS list; run the script to produce the four PNG files in `assets/images/items/`

- [x] Task F — `tests/test_overnight.lua` — Add tests: (1) milking_center with 1 cow produces 2 milk overnight; (2) milking_center with 3 cows produces 6 milk overnight; (3) milking_center cow is preserved after tick; (4) cheese_cave with 1 milk converts to 1 cheese overnight; (5) cheese_cave with 4 milks converts all 4 to cheese overnight; (6) cheese_cave milk is consumed after tick
