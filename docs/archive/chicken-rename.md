## Chicken Rename Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Rename the `raw_meat` key to
  `raw_chicken` (name: "Raw Chicken") and the `cooked_meat` key to
  `baked_chicken` (name: "Baked Chicken"). Update all recipe references inside
  item_defs: microwave Cook `raw_chicken → baked_chicken`; microwave pot recipe
  `water + raw_chicken → soup`; meat_machine Process `chicken → raw_chicken`.
  Add `fried_chicken` def (1×1, color {0.88, 0.65, 0.20, 1}, tags =
  {"Greasy", "Protein"}). Add fryer Fry recipe `{ requires = { raw_chicken = 1 },
  produces = { fried_chicken = 1 } }`. No other files change in this task.

- [x] Task B — `game/scenes/kitchen_scene.lua` and `lua/game/customer_queue.lua`
  — In kitchen_scene.lua, rename `Item.new("raw_meat")` → `Item.new("raw_chicken")`
  and update the assert message string. In customer_queue.lua, rename `"raw_meat"`
  → `"raw_chicken"` in the merchant stock table. No logic changes.

- [x] Task C — `tests/test_item.lua` and `tests/test_item_panel.lua` — Mechanical
  find-and-replace: `raw_meat` → `raw_chicken`, `cooked_meat` → `baked_chicken`,
  "Raw Meat" → "Raw Chicken", "Cooked Meat" → "Baked Chicken" in all string
  literals and comments. No logic changes.

- [x] Task D — `tests/test_customer.lua`, `tests/test_day_loop.lua`,
  `tests/test_kitchen_scene.lua`, and `tests/test_overnight.lua` — Same
  mechanical find-and-replace as Task C: `raw_meat` → `raw_chicken`,
  `cooked_meat` → `baked_chicken`, "Raw Meat" → "Raw Chicken", "Cooked Meat"
  → "Baked Chicken" in all string literals and comments. No logic changes.
