## Coffee Machine Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `roasted_coffee_bean` entry: 1×1 footprint `{{0,0}}`, color `{0.35, 0.22, 0.10, 1}`, no tags
- [x] Task B — `lua/game/data/item_defs.lua` — Add `black_coffee` entry: 1×1 footprint `{{0,0}}`, color `{0.12, 0.08, 0.05, 1}`, tags `{"Caffeine", "Bitter"}`
- [x] Task C — `lua/game/data/item_defs.lua` — Add `coffee_machine` entry: 2×2 footprint `{{0,0},{1,0},{0,1},{1,1}}`, color `{0.25, 0.22, 0.20, 1}`, `has_panel=true`, `panel_cols=2`, `panel_rows=2`, one action named `"Run"` with `duration=3.0`, `requires={water=1, roasted_coffee_bean=1}`, `produces={black_coffee=1}`
- [x] Task D — `assets/images/items/roasted_coffee_bean.png` — Draw a 32×32 PNG icon using exactly 3 shades: light warm tan highlight, dominant medium brown, dark espresso shadow. Bean oval shape.
- [x] Task E — `assets/images/items/coffee_machine.png` — Draw a 32×32 PNG icon using exactly 3 shades: light silver highlight, dominant dark grey body, near-black shadow. Machine silhouette with spout.
- [x] Task F — `assets/images/items/black_coffee.png` — Draw a 32×32 PNG icon using exactly 3 shades: light cream/off-white rim highlight, dominant very dark brown liquid, black shadow at base. Cup shape.
