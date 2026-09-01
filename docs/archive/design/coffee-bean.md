## Goal

Add `coffee_bean` as a raw 1×1 ingredient that:
1. Can be cooked in the microwave to produce `roasted_coffee_bean`
2. Can grow in the garden (spreading like `onion` and `potato`)
3. Appears as an extra item in the `coffee_machine` program

## Affected files

- `lua/game/data/item_defs.lua` — add `coffee_bean` item def; add garden_spread entry; add microwave recipe
- `lua/game/data/program_defs.lua` — add `coffee_bean` to `coffee_machine` extras and inputs
- `scripts/gen_icons.py` — add color entry and generator functions for `coffee_bean` and `coffee_bean_garden`
- `assets/images/items/coffee_bean.png` — generated icon
- `assets/images/items/coffee_bean_garden.png` — generated garden icon
- `tests/test_item.lua` or `tests/test_restock_gen.lua` — cover new item and restock behavior

## What changes

### item_defs.lua

Add `coffee_bean`:
```lua
coffee_bean = {
    name     = "Coffee Bean",
    footprint = { { 0, 0 } },
    color    = { 0.28, 0.20, 0.10, 1 },
},
```

Extend `garden.garden_spread` to include `"coffee_bean"`:
```lua
garden_spread = { "onion", "broccoli", "potato", "coffee_bean" },
```

Add a microwave recipe for coffee_bean → roasted_coffee_bean:
```lua
{ requires = { coffee_bean = 1 }, produces = { roasted_coffee_bean = 1 } },
```

### program_defs.lua

In `coffee_machine`, replace `roasted_coffee_bean` with `coffee_bean` in both extras and inputs — players roast their own beans via the microwave:
```lua
extras = { "coffee_bean", "coffee_bean" },
inputs = { "coffee_bean", "water" },
```

### gen_icons.py

Add color entry:
```python
"coffee_bean":        (71, 51, 26),
"coffee_bean_garden": (56, 36, 15),
```

Add `gen_coffee_bean()` — small oval bean shape with a crease line.
Add `gen_coffee_bean_garden()` — soil strip with small oval beans above it, similar to `onion_garden`.

## What stays the same

- `roasted_coffee_bean` and `black_coffee` item defs are unchanged
- `coffee_machine` equipment def is unchanged
- The overall coffee workflow (coffee_bean → roasted_coffee_bean → black_coffee) is unchanged
- Garden mechanics (spreading logic in `item.lua`) require no code changes — only the `garden_spread` list needs updating

## Open questions

None — the design is self-contained.
