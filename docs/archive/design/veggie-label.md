## Goal

Add the `"Veggie"` tag to `steamed_broccoli` and `onion_soup`.

## Affected files

- `lua/game/data/item_defs.lua`

## What changes

- `steamed_broccoli` tags: `{ "Healthy" }` → `{ "Healthy", "Veggie" }`
- `onion_soup` tags: `{ "Hearty" }` → `{ "Hearty", "Veggie" }`

## What stays the same

- Raw `broccoli` and raw `onion` remain tag-free (raw ingredients are never tagged).
- All other item tags are unchanged.
- No changes to recipe logic, customer order matching, or any other system.

## Open questions

None.
