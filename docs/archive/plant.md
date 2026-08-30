## Plant & Onion Feature Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `onion`, `blooming_onion`, `onion_soup`, `plant`, and `onion_plant` defs. Convert the fryer's single flat action to a `recipes` list so both `{ potato → fries }` and `{ onion → blooming_onion }` share the "Fry" button (same pattern as the microwave's "Cook"). Add `{ container = "pot", requires = { water=1, onion=1 }, produces = { onion_soup=1 } }` to the microwave's recipe list.

- [x] Task B — `lua/game/item.lua` — After the panel is created in `Item.new`, if `def.daily_fill` exists call a local helper `fill_panel(panel, daily_fill, cols, rows)` that places the specified items (type_id → count) using `place_first_fit`. Add `Item:refill_daily()`: clears every item from the panel via `panel:remove`, then re-fills using the same helper. No-ops when `self.panel` or `def.daily_fill` is absent.

- [x] Task C — `game/scenes/kitchen_scene.lua` — Place one `plant` and one `onion_plant` in `on_enter` at cells that don't overlap existing items (microwave 0,0–1,1; meat 2,0–4,0; broccoli 2,1–3,1; fryer 6,0–7,1; pot 8,0–9,0; potatoes 2,2–3,2). In the "Next Day" handler in `mouse_pressed`, after `self.queue = CustomerQueue.new(...)`, iterate `self.grid:items()` and call `item:refill_daily()` on each.

- [x] Task D — `tests/test_item.lua` — Add tests: (1) a newly created `plant` has its panel pre-filled with 3 broccoli; (2) dragging one broccoli out and calling `refill_daily()` restores the panel to 3 broccoli; (3) `refill_daily()` on an item without `daily_fill` (e.g. `raw_meat`) is a no-op and doesn't error.

- [x] Task E — `tests/test_kitchen_scene.lua` — Add a test: after a full day cycle (`advance_day` + `start_day` triggered via the "Next Day" button path), the plant on the floor has 3 broccoli in its panel and the onion_plant has 3 onions.
