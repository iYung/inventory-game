## Goal

Fix drag-and-drop so items stay relative to where the user clicked instead of snapping their center to the cursor.

## Affected files

- `lua/game/grid.lua` — all drag state and positioning logic lives here

## What changes

**Problem:** `Grid:_position_dragging_sprite()` always places the sprite so its center is at the cursor:

```lua
s.x = self.drag_cursor_x - s.width  / 2
s.y = self.drag_cursor_y - s.height / 2
```

This causes items to jump on pickup if the user clicked anywhere other than the center.

**Fix:** Record where within the sprite the user clicked at drag-start, then use that offset throughout the drag.

1. Add `drag_offset_x` / `drag_offset_y` fields to Grid (initialized to nil).
2. In `mouse_pressed`, after identifying the item and before calling `_position_dragging_sprite`, compute:
   ```lua
   self.drag_offset_x = x - self.dragging.sprite.x
   self.drag_offset_y = y - self.dragging.sprite.y
   ```
3. In `_position_dragging_sprite`, replace the center formula:
   ```lua
   s.x = self.drag_cursor_x - self.drag_offset_x
   s.y = self.drag_cursor_y - self.drag_offset_y
   ```
4. In `rotate_dragged`, after `rotate()`, reset the offset to center (`s.width/2`, `s.height/2`) so the item visually rotates around the cursor point.
5. In `mouse_released`, clear both offset fields alongside the other drag state.

## What stays the same

- Drop-target snapping (world_to_cell) is unaffected — only the floating visual position changes.
- Cross-grid drag, preview override, and all other drag events are unaffected.
- No changes to item.lua, item_panel.lua, or any scene file.

## Open questions

None — the scope and fix are clear.
