## Goal

Revert the `GRID_ROWS` expansion (9 → 12) introduced in `feat/milking-center-and-cheese-cave`, then re-home the milking center and cheese cave inside the existing container's panel rather than on the main grid.

## Affected files

- `lua/game/config.lua` — revert `GRID_ROWS` from 12 back to 9
- `game/scenes/kitchen_scene.lua` — remove main-grid placements at rows 9; place both items inside the container's panel instead

## What changes

1. `config.lua`: `GRID_ROWS = 12` → `GRID_ROWS = 9`
2. `kitchen_scene.lua`: Remove the two `self.grid:place` calls for `milking_center` (at col 0, row 9) and `cheese_cave` (at col 3, row 9), plus their `can_place` assertions.
3. `kitchen_scene.lua`: After the existing container is placed, add two `container.panel:place` calls:
   - `milking_center` at (0, 0) — occupies cols 0–2, rows 0–2 in the 6×6 panel
   - `cheese_cave` at (3, 0) — occupies cols 3–4, rows 0–1

## What stays the same

- All milking center and cheese cave item definitions (`item_defs.lua`) — unchanged
- The `item.lua` overnight-tick fix (consume-count bug) — kept as-is; it is correct and unrelated to the grid size
- All other grid placements, panel sizes, and game logic

## Open questions

None — all decisions confirmed with user.
