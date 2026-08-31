# Pump — Design Doc

## Goal

Add a **Pump** item: a 1-wide × 2-tall machine with a 1×1 panel and a single "Pump" action that produces one Water per use.

## Affected files

- `lua/game/data/item_defs.lua` — new `pump` entry
- `scripts/gen_icons.py` — pump color + `gen_pump()` + generator registration
- `assets/images/items/pump.png` — generated icon (run gen_icons.py)

## What changes

### item_defs.lua

New entry:

```lua
pump = {
    name      = "Pump",
    footprint = { {0,0}, {0,1} },   -- 1 wide, 2 tall
    color     = { 0.35, 0.55, 0.75, 1 },
    has_panel  = true,
    panel_cols = 1,
    panel_rows = 1,
    actions = {
        {
            name     = "Pump",
            duration = 1.0,
            produces = { water = 1 },
            -- no requires: always fires; panel fills with one Water per click
        },
    },
},
```

`requires` is intentionally absent. `satisfies(nil, ...)` returns true unconditionally, so the action always matches. If the panel is already full, `place_first_fit` silently no-ops — expected behaviour.

### gen_icons.py

- Add `"pump": (89, 140, 191)` to `COLORS` (a steel-blue shade of the item's color).
- Add `gen_pump()`: draws a simple pump silhouette (pipe body + handle) using the 3-shade rule.
- Register `gen_pump` in the generator list.

## What stays the same

- All existing items and recipes are untouched.
- Panel, action, and recipe execution logic in `item.lua` needs no changes.
- No new Lua modules; no schema changes.

## Open questions

None — footprint, panel size, action name, and output are all specified.
