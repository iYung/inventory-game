# drag-item-position

## Goal

Drag-and-drop currently determines the drop target cell (and the live drop-preview cell) from the **cursor position**. Because the player can click anywhere on an item — not just its top-left corner — the item snaps into a cell that contains the cursor, not the cell that the item visually occupies. This feels wrong: the item appears to land one or more cells away from where it looks like it is sitting.

The fix is to use the **item's sprite top-left corner** (i.e. the anchor/origin of the sprite) as the reference point when computing which cell the item would land in, for both the live preview and the final drop.

## Affected files

- `lua/game/grid.lua` — `mouse_moved`, `mouse_released`, `preview_override`
- `game/scenes/kitchen_scene.lua` — `mouse_moved` (cross-grid preview), `mouse_released` (hover-grid selection, container detection, `transfer_drag` call), `transfer_drag` helper

## What changes

### 1. `Grid:mouse_moved` — live drop preview

Currently:
```lua
self.drag_preview_col, self.drag_preview_row = self:world_to_cell(x, y)
```
Change to: compute `drag_preview_col/row` from `sprite.x, sprite.y` (the sprite's top-left corner) instead of the cursor. Fall back to cursor when the dragging item has no sprite.

```lua
local sx, sy = self:_sprite_anchor()
self.drag_preview_col, self.drag_preview_row = self:world_to_cell(sx, sy)
```

Add a small private helper `Grid:_sprite_anchor()` that returns `(sprite.x, sprite.y)` when a sprite exists, else the current cursor position — a single place to hold the fallback logic.

### 2. `Grid:mouse_released` — drop cell

Currently:
```lua
local col, row = self:world_to_cell(x, y)
```
Change to use `_sprite_anchor()` the same way. The cursor `x, y` argument is still accepted (it's the raw release position forwarded by the scene) but is only used as the fallback when there's no sprite.

### 3. `KitchenScene:mouse_moved` — cross-grid preview override

When a cross-grid drag's cursor is over a different grid, the scene calls `grid:preview_override(item, x, y)`. Inside `preview_override` the scene passes the cursor's `x, y`, then `world_to_cell` is called on it. Change the call site to pass the sprite anchor instead so the cross-grid preview also snaps to the item's visual position:

```lua
-- was: grid:preview_override(item, x, y)
local sx, sy = item.sprite and item.sprite.x or x, item.sprite and item.sprite.y or y
grid:preview_override(item, sx, sy)
```

### 4. `KitchenScene:mouse_released` — hover-grid and container detection

The scene uses `_hover_grid(x, y)` and `_container_at(x, y)` to decide which grid and which container receives the drop. Change both calls to use the sprite anchor so that the grid and container receiving the item match what the player sees:

```lua
local sx, sy = item.sprite and item.sprite.x or x, item.sprite and item.sprite.y or y
local hover   = self:_hover_grid(sx, sy)
-- ...
local container = self:_container_at(sx, sy)
-- ...
transfer_drag(owner, hover, item, sx, sy)
```

### 5. `transfer_drag` helper — drop cell inside target grid

`transfer_drag` currently calls `to_grid:world_to_cell(x, y)` with the cursor. It now receives the sprite anchor from the caller in step 4, so no internal change to the helper is needed — the `x, y` it receives will already be the sprite anchor.

## What stays the same

- `_position_dragging_sprite()` is unchanged: the sprite continues to follow the cursor with the original click offset, so dragging still feels natural.
- Click hit-testing for panel backgrounds, buttons, and the customer body still uses the raw cursor position — only drop/preview cell resolution changes.
- Snap-back to the original cell on an invalid drop is unchanged.
- `_hover_grid` and `_container_at` themselves are unchanged; only their call sites change.
- Cross-grid panel-title-bar dragging (`_dragging_panel`) is unaffected.

## Open questions

None. The change is self-contained and the fallback (no sprite → use cursor, same as before) covers every edge case.
