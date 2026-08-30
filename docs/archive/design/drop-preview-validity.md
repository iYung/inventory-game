# Drop Preview Validity

## Goal
Only show the drop-preview outline (the "shadow") while dragging an item when the cursor is
over a valid drop location — either a panel's inner grid or the main floor grid — AND the item
could actually land there (can_place returns true). When the cursor is outside all grids (customer
area, HUD, empty space) or over a cell that is occupied/out-of-bounds, no outline is drawn.

## Affected files
- `lua/game/grid.lua` — add `_point_in_bounds`, gate preview draw on `can_place`
- `game/scenes/kitchen_scene.lua` — make `_hover_grid` return nil when not over any real grid
- `tests/test_kitchen_scene.lua` — add coverage for the nil-hover and invalid-cell cases

## What changes

### `lua/game/grid.lua`

**New method `Grid:_point_in_bounds(x, y)`**
Returns true iff world-space (x, y) falls within this grid's cell area:
```
x >= origin_x and x < origin_x + cols * cell_size
y >= origin_y and y < origin_y + rows * cell_size
```

**`Grid:draw` preview guard**
Before drawing the preview rectangle, add a `can_place` check:
```lua
if preview_item and colors.grid_line
   and self:can_place(preview_item, preview_col, preview_row) then
```
The dragged item is already un-listed from `_items` before draw, so `can_place` won't
reject its own origin cells — it only rejects genuinely occupied or out-of-bounds cells.

### `game/scenes/kitchen_scene.lua`

**`KitchenScene:_hover_grid(x, y)`**
Currently falls back to `self.grid` unconditionally. Change to only return `self.grid`
when the cursor is actually over the main floor grid:
```lua
if self.grid:_point_in_bounds(x, y) then
    return self.grid
end
return nil
```
The existing `mouse_moved` loop already handles `hover == nil` correctly: it clears
`drag_preview_col/row` on the owning grid (condition `grid ~= hover` is true when hover
is nil) and calls `clear_preview_override()` on every other grid. No changes needed there.

## What stays the same
- The dragged item's **sprite** continues to follow the cursor everywhere (this is standard
  drag UX; only the drop hint disappears outside valid areas).
- `mouse_released` logic is unchanged — drops outside valid grids still snap back as before
  (the `_hover_grid` in mouse_released path uses the same updated helper, so it now returns
  nil when appropriate, but `transfer_drag` already handles the snap-back for out-of-bounds
  cells, and the `if hover ~= owner` branch gracefully handles a nil hover).

  Wait — actually `mouse_released` calls `transfer_drag(owner, hover, item, x, y)` where
  hover could now be nil. `transfer_drag` calls `to_grid:world_to_cell` on a nil grid.
  **Fix**: `mouse_released` must guard against nil hover and snap back in that case.

## Open questions
None — the approach is fully determined by the existing architecture.
