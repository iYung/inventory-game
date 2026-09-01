# Panel Snap Hint Consistency Checklist

- [x] Task A — `lua/game/grid.lua` — Add `Grid:_snap_cell_for(item)` that computes the snap cell from the item's sprite position using `floor(... + 0.5)` rounding, then rewrite `Grid:_snap_cell()` to delegate to it, and fix `Grid:preview_override` to call `self:_snap_cell_for(item)` instead of `self:world_to_cell(x, y)`
- [x] Task B — `game/scenes/kitchen_scene.lua` — In `transfer_drag`, replace `local col, row = to_grid:world_to_cell(x, y)` with `local col, row = to_grid:_snap_cell_for(item)` so the actual cross-grid drop lands on the same cell the hint showed
