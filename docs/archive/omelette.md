## Omelette Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — add `omelette` item def (footprint 1×1, color ~yellow-orange `{ 0.90, 0.80, 0.40, 1 }`, tags `{ "Protein", "Healthy" }`)
- [x] Task B — `lua/game/data/item_defs.lua` — add container recipe to microwave's Cook action: `{ container = "pot", requires = { egg = 1, broccoli = 1 }, produces = { omelette = 1 } }` (alongside the existing pot recipes)
- [x] Task C — `scripts/gen_icons.py` — add `"omelette": (230, 204, 102)` to COLORS, add `gen_omelette()` function, register it in GENERATORS; then run the script to produce `assets/images/items/omelette.png`
- [x] Task D — `tests/test_item.lua` — add test: pot with egg + broccoli in microwave cooks into omelette; add test: omelette has Protein and Healthy tags
