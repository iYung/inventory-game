## Goal

Fix drag-and-drop so items feel natural: they stay relative to where the user clicked during drag, and snap to the grid cell whose center is closest to the item's center on drop.

## Affected files

- `lua/game/grid.lua` — all drag state and positioning logic lives here
- `tests/test_grid.lua` — updated to match new snap behavior

## What changes

**Visual drag (no jump on pickup):** `mouse_pressed` records the pixel offset from the cursor to the sprite's top-left at click time. `_position_dragging_sprite` applies that offset every frame so the item follows the cursor from wherever it was grabbed.

```lua
self.drag_offset_x = x - item.sprite.x
self.drag_offset_y = y - item.sprite.y
-- ...
s.x = self.drag_cursor_x - self.drag_offset_x
s.y = self.drag_cursor_y - self.drag_offset_y
```

**Center-based grid snap:** `_sprite_anchor` now returns the center of the dragged sprite instead of its top-left. `world_to_cell` is called on this center point for both the drop-preview and the final placement, so the item lands in the cell that its center is over — not the cell its top-left corner is over.

```lua
function Grid:_sprite_anchor()
    local s = self.dragging.sprite
    return s.x + s.width / 2, s.y + s.height / 2
end
```

## What stays the same

- Cross-grid drag, preview override, and all other drag events are unaffected.
- No changes to item.lua, item_panel.lua, or any scene file.

## Open questions

None.
