# Cow & Beef Feature Design

## Goal

Add a beef production chain: cow item processed in the meat machine yields raw
beef; raw beef microwaved produces steak (Protein). Restore the original beef
stew pot recipe (water + potato + raw_beef → beef_stew). Rename `soup` →
`chicken_soup` to distinguish it from the new beef chain.

---

## Affected files

- `lua/game/data/item_defs.lua` — add `cow`, `raw_beef`, `steak`; add meat
  machine recipe cow → raw_beef; add microwave recipe raw_beef → steak; rename
  `soup` → `chicken_soup`; update `produces = { soup = 1 }` → `chicken_soup`;
  add pot recipe `water + potato + raw_beef → beef_stew`
- `tests/test_item.lua` — rename `"soup"` → `"chicken_soup"` in the one test
  that references it; update comment

---

## What changes

### New items

| type_id    | Size | Tags      | Notes                                              |
|------------|------|-----------|----------------------------------------------------|
| `cow`      | 2×2  | none      | Dark brown; placed in meat machine                 |
| `raw_beef` | 1×1  | none      | Dark red; microwaved into steak                    |
| `steak`    | 1×1  | "Protein" | Rich brown; end product of the beef chain          |

### Meat machine changes

- Footprint grows from 2×2 → **3×2** to visually accommodate the larger animal
- Panel grows from 2×1 → **2×2** so a 2×2 cow fits (filling all 4 cells, naturally limiting to 1 cow at a time)
- A 1×1 chicken still fits (1 cell), and the recipe consumes exactly 1 per press

### Updated production amounts

- **1 cow → 4 raw_beef** (recipe: `requires = { cow = 1 }, produces = { raw_beef = 4 }`)
- **1 chicken → 2 raw_chicken** (recipe: `requires = { chicken = 1 }, produces = { raw_chicken = 2 }`)

### New recipes

- **Meat machine Process:** `cow → 4× raw_beef` (alongside updated `chicken → 2× raw_chicken`)
- **Microwave Cook:** `raw_beef → steak` (flat recipe, same pattern as `raw_chicken → baked_chicken`)
- **Microwave Cook (pot):** `water + potato + raw_beef → beef_stew` (restores the original 3-ingredient beef stew recipe that was removed in an earlier session)

### Rename

`soup` → `chicken_soup` ("Chicken Soup") everywhere. Tags (Protein, Hearty)
and color are unchanged.

---

## What stays the same

- `water + raw_chicken → chicken_soup` pot recipe (just renamed output)
- All other items, recipes, and mechanics unchanged
- `beef_stew` item def (already exists with "Filling" + "Protein" tags) gains
  its recipe but is otherwise untouched

---

## Open questions

None — proceeding to checklist.
