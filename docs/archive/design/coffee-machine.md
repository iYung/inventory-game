# Coffee Machine

## Goal

Add a coffee machine appliance that brews black coffee from water and roasted coffee beans, plus the two new ingredient/output items that support it.

## Affected files

- `lua/game/data/item_defs.lua` — three new entries: `coffee_machine`, `roasted_coffee_bean`, `black_coffee`
- `assets/images/items/coffee_machine.png` — new icon
- `assets/images/items/roasted_coffee_bean.png` — new icon
- `assets/images/items/black_coffee.png` — new icon

## What changes

### New items

**`roasted_coffee_bean`**
- 1×1 footprint
- Raw ingredient; no tags (by convention, raw items carry no tags)
- Color: warm dark brown

**`coffee_machine`**
- 2×2 footprint (`{0,0},{1,0},{0,1},{1,1}`)
- Has a 2×2 panel (`panel_cols=2, panel_rows=2`)
- One action: **Run** (duration 3.0 s)
  - `requires = { water = 1, roasted_coffee_bean = 1 }`
  - `produces = { black_coffee = 1 }`

**`black_coffee`**
- 1×1 footprint
- Tags: `{ "Caffeine", "Bitter" }`
- Color: very dark brown / near-black

### New PNG icons

Three 32×32 (or 64×64) PNG icons following the 3-shade rule (lighter highlight, dominant mid, darker shadow — no other colors).

## What stays the same

- No changes to `item.lua`, `item_panel.lua`, `grid.lua`, or any scene file.
- The existing action/recipe system handles the new recipe without modification.
- `water` already exists; no changes needed to it.

## Open questions

_(none — requirements are fully specified)_
