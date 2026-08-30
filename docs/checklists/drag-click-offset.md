## Drag Click-Offset Checklist

- [x] Task A — `lua/game/grid.lua` — Add `drag_offset_x` and `drag_offset_y` fields (set to nil) in `Grid:new()`
- [x] Task B — `lua/game/grid.lua` — In `mouse_pressed`, after setting `self.dragging`, record `self.drag_offset_x = x - self.dragging.sprite.x` and `self.drag_offset_y = y - self.dragging.sprite.y`
- [x] Task C — `lua/game/grid.lua` — In `_position_dragging_sprite`, replace center-based formula with `s.x = self.drag_cursor_x - self.drag_offset_x` and `s.y = self.drag_cursor_y - self.drag_offset_y`; guard on `self.drag_offset_x` instead of (or in addition to) `self.drag_cursor_x`
- [x] Task D — `lua/game/grid.lua` — In `rotate_dragged`, after `self.dragging:rotate()`, reset offset to the new sprite's center: `self.drag_offset_x = s.width / 2` and `self.drag_offset_y = s.height / 2`
- [x] Task E — `lua/game/grid.lua` — In `mouse_released`, nil out `self.drag_offset_x` and `self.drag_offset_y` alongside the other drag state fields
