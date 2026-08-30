## Drop Preview Validity Checklist

- [x] Task A — `lua/game/grid.lua` — Add `Grid:_point_in_bounds(x, y)` method that
  returns true iff (x, y) is within the grid's cell area
  (`x >= origin_x and x < origin_x + cols * cell_size`, same for y).
  Insert it in the "Coordinate conversion" section (after `world_to_cell`).

- [x] Task B — `lua/game/grid.lua` — In `Grid:draw`, gate the drop-preview rectangle
  on `self:can_place(preview_item, preview_col, preview_row)`. Change the condition
  from `if preview_item and colors.grid_line then` to
  `if preview_item and colors.grid_line and self:can_place(preview_item, preview_col, preview_row) then`.

- [x] Task C — `game/scenes/kitchen_scene.lua` — In `KitchenScene:_hover_grid(x, y)`,
  replace the unconditional `return self.grid` fallback with a bounds-checked version:
  only return `self.grid` when `self.grid:_point_in_bounds(x, y)` is true, otherwise
  return nil.

- [x] Task D — `game/scenes/kitchen_scene.lua` — In `KitchenScene:mouse_released(x, y)`,
  guard against `hover` being nil (cursor released outside all grids). When `hover` is nil,
  snap the dragged item back to its origin by calling `owner:mouse_released` — or
  equivalently place it back at `drag_orig_col`/`drag_orig_row` then clear drag state.
  The simplest safe approach: if `hover == nil`, treat it the same as `hover == owner`
  (fall through to `owner:mouse_released(x, y)` which already handles can_place failure
  with snap-back).

- [x] Task E — `tests/test_kitchen_scene.lua` — Add tests covering:
  1. Drop preview is nil/not drawn when cursor is outside the main grid bounds
     (verify `_hover_grid` returns nil for a point above SPLIT_Y on the stage).
  2. Drop preview is not set when cursor is inside the grid but over an occupied cell
     (verify `can_place` gates the preview correctly).
  3. Releasing a drag outside all grids snaps the item back to its origin cell.
