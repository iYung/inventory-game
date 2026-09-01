# Panel Snap Hint Consistency

## Goal

Make the drag snap hint (drop-preview outline) behave the same way whether you are dragging within the main inventory grid, within an open item panel, or across those two grids. Currently the hint rounds inconsistently when crossing grid boundaries.

## Root cause

There are two separate code paths for computing a snap cell, and they use different formulas:

| Situation | Function | Formula |
|-----------|----------|---------|
| Dragging within any one grid (main or panel) | `Grid:_snap_cell()` | `floor((sprite.x − origin_x) / cell_size + 0.5)` — rounds based on sprite position, offset-corrected |
| Hovering a cross-grid drag over another grid | `Grid:preview_override(item, x, y)` → `world_to_cell(x, y)` | `floor((cursor_x − origin_x) / cell_size)` — floors raw cursor, no offset |
| Dropping cross-grid (`transfer_drag`) | `to_grid:world_to_cell(x, y)` | Same floor-cursor formula as preview_override |

The hint and the actual drop agree with each other for cross-grid transfers (both floor the cursor), but neither accounts for where within the item the user clicked. When you pick up an item from its right half, the cursor is a half-cell to the right of the sprite top-left; floor-on-cursor therefore snaps one cell to the right of what round-on-sprite would show — and of what the user expects from in-grid dragging.

## What changes

### 1. Extract the snap formula into a shared `Grid` helper

Add `Grid:_snap_cell_for(item)` that takes any item (not just `self.dragging`) and uses its sprite position:

```lua
function Grid:_snap_cell_for(item)
    if item and item.sprite then
        local s = item.sprite
        return math.floor((s.x - self.origin_x) / self.cell_size + 0.5),
               math.floor((s.y - self.origin_y) / self.cell_size + 0.5)
    end
    -- fallback: no sprite (shouldn't happen during a real drag)
    return self:world_to_cell(self.drag_cursor_x, self.drag_cursor_y)
end
```

Rewrite the existing `_snap_cell()` to call this:

```lua
function Grid:_snap_cell()
    return self:_snap_cell_for(self.dragging)
end
```

### 2. Fix `Grid:preview_override` to use sprite-based rounding

```lua
function Grid:preview_override(item, x, y)
    self._preview_override_item = item
    self._preview_override_col, self._preview_override_row = self:_snap_cell_for(item)
end
```

The `x, y` parameter is kept in the signature for backward compatibility but is no longer needed once the sprite path is used (the sprite is already positioned by `_position_dragging_sprite` before `preview_override` is called).

### 3. Fix `transfer_drag` to use sprite-based rounding

In `kitchen_scene.lua`, replace:

```lua
local col, row = to_grid:world_to_cell(x, y)
```

with:

```lua
local col, row = to_grid:_snap_cell_for(item)
```

This makes the actual drop land where the hint shows, using the same rounding as an in-grid release.

## What stays the same

- `world_to_cell` itself is unchanged — it's still used for hit-testing (double-click detection, hover labeling, container-at detection) where cursor position matters, not sprite position.
- `transfer_drag_first_fit` is unchanged — it drops into the first available cell rather than a cursor-targeted one, so snap rounding is irrelevant.
- Panel layout, item panel open/close, action buttons — all untouched.
- The `x, y` parameter on `preview_override` is kept (removing it would require a signature change at every call site in kitchen_scene.lua for no real gain).

## Open questions

None — the investigation was conclusive. The fix is mechanical and limited to three sites.

## Affected files

- `lua/game/grid.lua` — add `_snap_cell_for`, rewrite `_snap_cell`, fix `preview_override`
- `game/scenes/kitchen_scene.lua` — fix `transfer_drag`
