## Goal

Add an **Omelette** recipe: microwaving a Pot containing one Egg and one Broccoli produces an Omelette tagged `Protein` and `Healthy`. Reuses the existing `pot` container — no new container item needed.

## Affected files

- `lua/game/data/item_defs.lua` — add `omelette` def; add pot-based container recipe to microwave
- `assets/images/items/omelette.png` — new icon (generated via `scripts/gen_icons.py`)
- `scripts/gen_icons.py` — add `gen_omelette()` and register it
- `tests/test_item.lua` — add tests for the new recipe and omelette tags

## What changes

### 1. Add `omelette` item def

```lua
omelette = {
    name     = "Omelette",
    footprint = { { 0, 0 } },
    color    = { 0.90, 0.80, 0.40, 1 },
    tags     = { "Protein", "Healthy" },
},
```

### 2. Add microwave container recipe (pot-based)

A new entry in the microwave's `Cook` action `recipes` list alongside the existing pot recipes:

```lua
{
    container = "pot",
    requires  = { egg = 1, broccoli = 1 },
    produces  = { omelette = 1 },
},
```

The pot has `panel_cols = 3`, so it can hold both egg and broccoli with a free slot.

### 3. Icon

One new PNG icon (32×32, matching the existing art style):
- `assets/images/items/omelette.png`

Generated via `scripts/gen_icons.py` using the 3-shade color rule (lighter highlight, primary fill, darker shadow).

## What stays the same

- `pot` def is untouched — no structural changes.
- All existing microwave and pot recipes (chicken, beef, stew, etc.) are untouched.
- No `pan` item is introduced.
- `matching_recipes` implementation unchanged.
- No changes to fryer, customer, day-loop, or any other system.

## Open questions

None.
