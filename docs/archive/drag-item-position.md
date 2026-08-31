# drag-item-position Checklist

- [x] Task A — `lua/game/grid.lua` — Add private helper `Grid:_sprite_anchor()` that returns `(sprite.x, sprite.y)` when `self.dragging` has a sprite, else `(self.drag_cursor_x, self.drag_cursor_y)`. Then change `mouse_moved` to compute `drag_preview_col/row` via `_sprite_anchor()` instead of the raw cursor `(x, y)`. Change `mouse_released` to compute the drop `col/row` via `_sprite_anchor()` instead of the raw release `(x, y)`.

- [x] Task B — `game/scenes/kitchen_scene.lua` — In `mouse_moved`: change the `grid:preview_override(item, x, y)` call to pass `(item.sprite and item.sprite.x or x, item.sprite and item.sprite.y or y)` instead of `(x, y)`. In `mouse_released`: before the hover/container/transfer logic, compute `sx, sy` as the sprite anchor (`item.sprite and item.sprite.x or x`, same for y), then replace every `x, y` in `_hover_grid`, `_container_at`, and `transfer_drag` calls with `sx, sy`.
