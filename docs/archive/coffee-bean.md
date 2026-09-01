## Coffee Bean Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `coffee_bean` item def (1×1, dark brown color); add `"coffee_bean"` to `garden.garden_spread`; add microwave recipe `{ requires = { coffee_bean = 1 }, produces = { roasted_coffee_bean = 1 } }`
- [x] Task B — `lua/game/data/program_defs.lua` — In `coffee_machine`, replace extras `{ "roasted_coffee_bean", "roasted_coffee_bean" }` with `{ "coffee_bean", "coffee_bean" }` and replace inputs `{ "roasted_coffee_bean", "water" }` with `{ "coffee_bean", "water" }`
- [x] Task C — `scripts/gen_icons.py` + `assets/images/items/` — Add color entries and generator functions for `coffee_bean` (small oval bean with crease) and `coffee_bean_garden` (soil strip with beans above); run the script to produce the two PNGs
- [x] Task D — `tests/` — Add a test asserting the microwave produces `roasted_coffee_bean` from `coffee_bean`, and a test asserting the restock pool for `coffee_machine` program includes `coffee_bean` and not `roasted_coffee_bean`
