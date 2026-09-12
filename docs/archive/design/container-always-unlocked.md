## Goal

Make the `container` item always available to the player from day one by registering it as a pre-owned program. Currently the container has a `buy_price` in `item_defs` but no `program_defs` entry, so it never surfaces in the program merchant and can never be purchased.

## Affected files

- `lua/game/data/program_defs.lua` — add `container` entry (no machines to complete, just the container item as a purchasable slot)
- `lua/game/program_state.lua` — allow `ProgramState.new` to accept a list of starting program IDs instead of a single string
- `game/scenes/kitchen_scene.lua` — pass `{ "fryer", "container" }` as starting programs
- `tests/test_program_state.lua` — cover multiple starting IDs

## What changes

### `program_defs.lua`
Add a `container` entry:
```lua
container = {
    id            = "container",
    name          = "Container",
    machines      = { "container" },
    extras        = {},
    inputs        = {},
    tags_unlocked = {},
    requires      = {},
},
```
`requires = {}` means it has no prerequisites. It will never appear in the "new programs" list in the merchant because the player starts with it owned — it will only ever appear as a repurchasable entry.

### `program_state.lua`
Change `ProgramState.new(starting_id)` to accept either a string or a list of strings:
```lua
function ProgramState.new(starting)
    -- starting: string id OR list of string ids
```
This keeps existing call-sites that pass a single string working.

### `kitchen_scene.lua`
Change `ProgramState.new("fryer")` → `ProgramState.new({ "fryer", "container" })`.

## What stays the same

- The merchant logic (`MerchantGen.offer`) is unchanged — owned programs naturally land in the `repurchasable` bucket, so containers will appear for repurchase.
- `RestockGen` and `OrderGen` are unaffected (container has no `inputs` or `tags_unlocked`).
- All other program defs and game logic are unchanged.

## Open questions

None.
