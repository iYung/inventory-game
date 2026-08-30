# Boiled Egg Feature Design

## Goal

Add a boiled egg recipe: water + egg microwaved inside a pot produces a
boiled egg tagged "Protein".

---

## Affected files

- `lua/game/data/item_defs.lua` — add `boiled_egg` item definition and a new
  `container = "pot"` recipe on the microwave's Cook action

---

## What changes

### New item

| type_id      | Size | Tags      | Notes                        |
|--------------|------|-----------|------------------------------|
| `boiled_egg` | 1×1  | "Protein" | Pale yellow-white color      |

### New microwave recipe

Added to the microwave's existing `Cook` action recipes list:

```lua
{
    container = "pot",
    requires  = { water = 1, egg = 1 },
    produces  = { boiled_egg = 1 },
},
```

This follows the identical pattern as the existing `soup` and `onion_soup`
container recipes — water and egg go into the pot, pot goes into the
microwave panel, press Cook.

---

## What stays the same

- The pot item is unchanged.
- All existing microwave recipes are unchanged.
- The `container` recipe engine in `lua/game/item.lua` is unchanged.
- No new UI, no new mechanics.

---

## Open questions

None — proceeding to checklist.
