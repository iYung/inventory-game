## Pump Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — add `pump` entry: footprint `{{0,0},{0,1}}`, color `{0.35, 0.55, 0.75, 1}`, `has_panel=true`, `panel_cols=1`, `panel_rows=1`, one action "Pump" (duration 1.0, produces `water=1`, no requires)
- [x] Task B — `scripts/gen_icons.py` — add `"pump": (89, 140, 191)` to COLORS; add `gen_pump()` drawing a pump silhouette with 3-shade rule; register `gen_pump` in the generator list
- [x] Task C — run `python3 scripts/gen_icons.py` to regenerate `assets/images/items/pump.png`
