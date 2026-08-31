## Goal

Change the steamed broccoli recipe so it requires water + broccoli in a pot, microwaved — matching real-world steaming where water in a covered vessel creates steam.

## Affected files

- `lua/game/data/item_defs.lua` — the microwave's recipe list

## What changes

The microwave's Cook action currently turns `broccoli` directly into `steamed_broccoli` (no water, no container). The recipe becomes a container recipe using the existing `pot` item, requiring `water = 1` and `broccoli = 1` inside the pot.

Before:
```lua
{ requires = { broccoli = 1 }, produces = { steamed_broccoli = 1 } },
```

After:
```lua
{ container = "pot", requires = { water = 1, broccoli = 1 }, produces = { steamed_broccoli = 1 } },
```

## What stays the same

- The `pot` item definition is unchanged.
- All other microwave recipes are unchanged.
- `steamed_broccoli` item definition is unchanged.
- No new items or containers are added.

## Open questions

None.
