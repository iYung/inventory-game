## Goal

Rename the "Dutch Oven" item to "Pot" and introduce a "Soup" recipe: microwaving a Pot that contains water and raw meat produces Soup (tagged Protein + Hearty).

## Affected files

- `lua/game/data/item_defs.lua` — rename type key + display name; update microwave container recipe; add `soup` def
- `game/scenes/kitchen_scene.lua` — update variable name and `Item.new` call
- `tests/test_item.lua` — rename variables, strings, comments for pot/soup
- `tests/test_item_panel.lua` — same
- `tests/test_kitchen_scene.lua` — same

## What changes

### 1. Rename dutch_oven → pot

- Type id `dutch_oven` renamed to `pot` everywhere (item_defs key, `container =` field, `Item.new(...)` calls, variable names in kitchen_scene and all test files).
- Display name `"Dutch Oven"` → `"Pot"`.

### 2. Swap container recipe: beef_stew → soup

The microwave's one container recipe currently produces beef_stew from potato + water + raw_meat. It is replaced by a soup recipe that requires only water + raw_meat.

Why a full replacement rather than an addition? Soup's requires `{water, raw_meat}` is a strict subset of beef_stew's `{potato, water, raw_meat}`. The `matching_recipes` function checks container recipes independently without deducting from the container's running counts, so if both recipes coexisted, a pot loaded with potato + water + raw_meat would simultaneously match both, fire both actions, and land in a broken state (soup placed, ingredients partially consumed, then beef_stew placed into a panel with insufficient room or wrong contents). Replacing rather than adding is the only safe approach without changing the matching engine.

New recipe:
```
container = "pot",
requires  = { water = 1, raw_meat = 1 },
produces  = { soup = 1 },
```

### 3. Add `soup` item def

```lua
soup = {
    name     = "Soup",
    footprint = { { 0, 0 } },
    color    = { 0.70, 0.50, 0.30, 1 },
    tags     = { "Protein", "Hearty" },
},
```

### 4. beef_stew item def stays

The `beef_stew` entry remains in item_defs (no longer reachable in normal play, but removing it is unnecessary churn and could break any future use).

## What stays the same

- Pot's footprint (2×1), panel size (3 cols × 1 row), color, and behavior as a passive container are unchanged.
- All other microwave recipes (raw_meat → cooked_meat, broccoli → steamed_broccoli, potato → baked_potato) are unchanged.
- Fryer, customer, day-loop logic — untouched.
- `matching_recipes` implementation — no changes needed.

## Open questions

None — scope is fully determined by the user's request and the constraint analysis above.
