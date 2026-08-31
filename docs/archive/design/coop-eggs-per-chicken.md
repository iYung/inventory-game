## Goal

The coop currently produces exactly one egg per overnight tick if at least one chicken is present. This feature makes it produce one egg per chicken (space permitting), rewarding the player for stocking the coop with multiple chickens.

## Affected files

- `lua/game/item.lua` — `overnight_tick` loop
- `lua/game/data/item_defs.lua` — coop `overnight_actions` entry
- `tests/test_overnight.lua` — add multi-chicken test cases

## What changes

### `item_defs.lua`

Add a `per_item` key to the coop's overnight action:

```lua
{ requires = { chicken = 1 }, produces = { egg = 1 }, nights = 1, preserve = true, per_item = "chicken" }
```

`per_item = "chicken"` tells the engine: after the nightly condition is met, repeat the production block once per chicken in the panel (up to available space).

### `item.lua` — `overnight_tick`

When `action.per_item` is set, derive a repeat count from `counts[action.per_item]` instead of running the production block once. Each iteration calls `place_first_fit`, which silently no-ops when the panel is full — so space caps production automatically without extra logic.

Current (produces 1 egg regardless of chicken count):
```lua
for type_id, count in pairs(action.produces or {}) do
    for _ = 1, count do
        local new_item = Item.new(type_id)
        place_first_fit(self.panel, new_item, def.panel_cols, def.panel_rows)
    end
end
```

New (repeats once per chicken):
```lua
local repeats = action.per_item and (counts[action.per_item] or 1) or 1
for _ = 1, repeats do
    for type_id, count in pairs(action.produces or {}) do
        for _ = 1, count do
            local new_item = Item.new(type_id)
            place_first_fit(self.panel, new_item, def.panel_cols, def.panel_rows)
        end
    end
end
```

## What stays the same

- Chickens still stay in the coop (`preserve = true` unchanged).
- The existing single-chicken test still passes (1 chicken → 1 egg).
- All other overnight actions (incubator, garden) are unaffected — they don't use `per_item`.
- No changes to the panel size (2×2 = 4 cells). With 2 chickens placed, 2 cells remain, so 2 eggs can spawn; with 3 chickens, only 1 cell free, so 1 egg spawns.

## Open questions

None — behavior is fully determined by chicken count and available space.
