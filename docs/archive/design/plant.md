## Goal

Add two **Plant** items to the kitchen floor — one for Broccoli, one for Onions — each a passive 3×1 supplier whose panel refills to 3 of its ingredient at the start of each new day. Also add two new cooked items that use Onion: **Blooming Onion** (fried) and **Onion Soup** (pot + microwave).

## Affected files

- `lua/game/data/item_defs.lua` — add `plant`, `onion_plant`, `onion`, `blooming_onion`, `onion_soup`; extend fryer and microwave recipes
- `lua/game/item.lua` — initial panel fill on `Item.new`; new `Item:refill_daily()` method
- `game/scenes/kitchen_scene.lua` — place both plants in starting layout; call `refill_daily` on all floor items at "Next Day"
- `tests/test_item.lua` — tests for `daily_fill` initial fill and `refill_daily`
- `tests/test_kitchen_scene.lua` — test that plants refill on new day

## What changes

### `item_defs.lua`

**New ingredient:**
```lua
onion = {
    name  = "Onion",
    footprint = { {0,0} },
    color = { 0.90, 0.75, 0.40, 1 },
},
```

**New cooked outputs:**
```lua
blooming_onion = {
    name  = "Blooming Onion",
    footprint = { {0,0} },
    color = { 0.80, 0.60, 0.25, 1 },
    tags  = { "Greasy" },
},

onion_soup = {
    name  = "Onion Soup",
    footprint = { {0,0} },
    color = { 0.75, 0.55, 0.25, 1 },
    tags  = { "Hearty" },
},
```

**New plant items:**
```lua
plant = {
    name      = "Plant",
    footprint = { {0,0}, {1,0}, {2,0} },
    color     = { 0.20, 0.50, 0.15, 1 },
    has_panel  = true,
    panel_cols = 3,
    panel_rows = 1,
    daily_fill = { broccoli = 3 },
},

onion_plant = {
    name      = "Onion Plant",
    footprint = { {0,0}, {1,0}, {2,0} },
    color     = { 0.65, 0.50, 0.20, 1 },
    has_panel  = true,
    panel_cols = 3,
    panel_rows = 1,
    daily_fill = { onion = 3 },
},
```

**Extended fryer** — add onion recipe alongside the existing potato one:
```lua
{ name = "Fry", duration = 3.0, requires = { onion = 1 }, produces = { blooming_onion = 1 } },
```
(The fryer's `actions` list will use `recipes` so both fry-potato and fry-onion share the "Fry" button, same pattern as the microwave's "Cook".)

**Extended microwave** — add onion soup as a container recipe in the pot, alongside the existing soup (meat + water) recipe:
```lua
{
    container = "pot",
    requires  = { water = 1, onion = 1 },
    produces  = { onion_soup = 1 },
},
```

### `item.lua`
**`Item.new`**: after the panel is created, if `def.daily_fill` exists, call a shared helper that places the specified items into the fresh panel (same `place_first_fit` scan used elsewhere).

**`Item:refill_daily()`**: new public method.
1. Remove every item currently in the panel.
2. Re-fill using `def.daily_fill` (same helper as above).
Only applicable when `self.panel` and `def.daily_fill` are both set; no-ops otherwise.

### `kitchen_scene.lua`
**Starting layout**: place one `plant` and one `onion_plant` at cells that don't overlap existing items.

**"Next Day" handler** (in `mouse_pressed`, where `advance_day` / `start_day` are called): after rebuilding the queue, iterate `self.grid:items()` and call `:refill_daily()` on each.

## What stays the same

- All existing items (microwave, fryer, pot, raw meat, broccoli, potatoes, etc.) are unchanged except the fryer's actions list and microwave's recipes list growing by one entry each.
- `daily_fill` is purely opt-in; items without it are never touched by `refill_daily`.
- Broccoli and Onion dragged out of their plants behave exactly like any other item of that type.
- No new customer orders or tags are introduced beyond `blooming_onion` ("Greasy") and `onion_soup` ("Hearty") — customers who already request "Greasy" or "Hearty" will accept these automatically.

## Open questions

_(none)_
