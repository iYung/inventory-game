## Coop Eggs Per Chicken Checklist

- [x] Task A — `lua/game/item.lua` — in `overnight_tick`, after `state.nights_elapsed >= action.nights` check, derive `repeats = action.per_item and (counts[action.per_item] or 1) or 1` and wrap the produces block in a `for _ = 1, repeats do` loop
- [x] Task B — `lua/game/data/item_defs.lua` — add `per_item = "chicken"` to the coop's overnight action entry
- [x] Task C — `tests/test_overnight.lua` — add tests: 2 chickens → 2 eggs, 3 chickens (1 free cell) → 1 egg (space-capped), 0 chickens → 0 eggs
