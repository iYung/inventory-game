# Chicken Rename Feature Design

## Goal

Rename `raw_meat` → `raw_chicken` and `cooked_meat` → `baked_chicken` to
reflect that the meat in this game is now clearly chicken (consistent with the
new chicken/coop items). Add a `fried_chicken` item produced by frying raw
chicken, tagged "Greasy" and "Protein".

---

## Affected files

- `lua/game/data/item_defs.lua` — rename defs and all recipe references;
  add `fried_chicken`; add fryer recipe; meat_machine produces `raw_chicken`
- `game/scenes/kitchen_scene.lua` — rename starting layout `Item.new` calls
- `lua/game/customer_queue.lua` — rename merchant stock entry
- `tests/test_item.lua` — mechanical rename of all string literals and comments
- `tests/test_item_panel.lua` — mechanical rename of all string literals and comments
- `tests/test_customer.lua` — mechanical rename of all string literals and comments
- `tests/test_day_loop.lua` — mechanical rename of all string literals and comments
- `tests/test_kitchen_scene.lua` — mechanical rename of all string literals and comments
- `tests/test_overnight.lua` — rename `raw_meat` reference in meat_machine test

---

## What changes

### Renames

| Old type_id    | New type_id      | Old name       | New name         | Tags unchanged |
|----------------|------------------|----------------|------------------|----------------|
| `raw_meat`     | `raw_chicken`    | "Raw Meat"     | "Raw Chicken"    | none           |
| `cooked_meat`  | `baked_chicken`  | "Cooked Meat"  | "Baked Chicken"  | "Protein"      |

All recipe `requires`/`produces` references to these type_ids update in lockstep:
- Microwave Cook: `raw_chicken → baked_chicken`
- Microwave Cook pot recipe: `water + raw_chicken → soup` (soup name/tags unchanged)
- Meat machine Process: `chicken → raw_chicken`

### New item

`fried_chicken` (1×1, warm golden color ~(0.88, 0.65, 0.20, 1), tags =
{"Greasy", "Protein"})

### New fryer recipe

Added to fryer's Fry action:
`{ requires = { raw_chicken = 1 }, produces = { fried_chicken = 1 } }`

### Test files

Pure mechanical find-and-replace of `raw_meat` → `raw_chicken` and
`cooked_meat` → `baked_chicken` in type_id string literals and comments.
Logic and assertions are unchanged.

---

## What stays the same

- All other items, tags, recipes, and mechanics are unchanged.
- `soup` and `onion_soup` names and tags are unchanged (just the ingredient
  type_id for soup changes from `raw_meat` to `raw_chicken`).
- No new UI or mechanics beyond the new fryer recipe.

---

## Open questions

None — proceeding to checklist.
