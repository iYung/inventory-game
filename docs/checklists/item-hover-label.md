## Item Hover Label Checklist

- [ ] Task A — `lua/game/item.lua` — In `Item.new()`, after `self.tags = def.tags or {}`, add `self.label = def.name or ""` so every item carries its display name as a plain field Grid can render without requiring item_defs.

- [ ] Task B — `lua/game/grid.lua` — In `Grid.new()`, add `self._hover_col = nil` and `self._hover_row = nil` to initialise hover state.

- [ ] Task C — `lua/game/grid.lua` — In `Grid:mouse_moved(x, y)`, unconditionally update `self._hover_col, self._hover_row = self:world_to_cell(x, y)` at the very top of the method, before the `if not self.dragging then return end` guard, so hover is tracked even when nothing is being dragged.

- [ ] Task D — `lua/game/grid.lua` — At the end of `Grid:draw(skip_dragging)`, after all items and the drag-preview outline are drawn, add a local `draw_label(item)` helper that: (1) skips if `item.label` is falsy, (2) reads the current font width/height, (3) draws a dark semi-transparent backing rectangle, (4) draws white text centred horizontally on `item.sprite.x + item.sprite.width / 2`, 3 px below `item.sprite.y + item.sprite.height`. Call it for the hovered item (when `not self.dragging` and `self._hover_col` and `self._hover_row` and an item exists at that cell) and for `self.dragging` (when set).
