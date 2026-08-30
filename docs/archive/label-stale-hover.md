# Label Stale Hover Checklist

- [x] Task A — `lua/game/grid.lua` — Add a `Grid:clear_hover()` method that sets `self._hover_col = nil` and `self._hover_row = nil`. Place it near the other hover/preview helpers (around line 215 where `clear_preview_override` lives).

- [x] Task B — `game/scenes/kitchen_scene.lua` — In `clear_drag` (line ~281), after zeroing the drag fields, call `grid:clear_hover()` on the source grid. In `transfer_drag` (line ~294) and `transfer_drag_first_fit` (line ~311), after calling `clear_drag`, also call `to_grid:clear_hover()` on the destination grid. This ensures both grids have clean hover state at drop time. (Depends on Task A.)

- [x] Task C — `lua/game/item_panel.lua` — In `ItemPanel:mouse_moved` (line ~299), add an `else` branch: when the cursor is outside the panel's grid AND no drag is in progress (`not self.item.panel.dragging`), call `self.item.panel:clear_hover()`. This prevents the sticky-on-leave problem for panel grids during normal (non-drag) mouse movement. (Depends on Task A.)
