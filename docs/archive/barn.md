# Barn Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `barn` entry: 3×3 footprint, 6×6 panel, overnight_action that uses `preserve = true`, `per_item = "cow"`, `per_item_step = 2` to produce 1 cow per 2 cows per night

- [x] Task B — `lua/game/item.lua` — Add `per_item_step` support in `overnight_tick`: replace the repeats line with `local step = action.per_item_step or 1` and `local repeats = action.per_item and math.floor((counts[action.per_item] or 0) / step) or 1`

- [x] Task C — `game/scenes/kitchen_scene.lua` — Place barn at grid cell (6, 6) (cols 6–8, rows 6–8 are the only free 3×3 block); add 2 starting cows inside the barn's panel

- [x] Task D — `tests/test_overnight.lua` — Add barn breeding tests: 2 cows → 1 new cow; 4 cows → 2 new cows; 1 cow → 0 new cows (requirement not met); 6 cows with only 1 free cell → 1 new cow (space-capped)

- [x] Task E — `assets/images/items/barn.png` — Generate barn icon using `scripts/gen_icons.py` (3-shade rule: light warm brown highlight, mid warm brown dominant, dark brown shadow)
