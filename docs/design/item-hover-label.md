# Item Hover Label

## Goal
When an item is hovered or being dragged, show its display name as a small label below its sprite. This helps players identify items at a glance without needing to memorize colors.

## Affected files
- `lua/game/item.lua` — expose the item's display name as `self.label`
- `lua/game/grid.lua` — track hover cell; draw labels in `Grid:draw()`

## What changes

### `lua/game/item.lua`
`Item.new()` already reads `def.name` for sprite sizing. Add one line: `self.label = def.name`. This gives Grid a stable, pre-resolved string to render without Grid needing to require item_defs.

### `lua/game/grid.lua`
**Hover tracking:** `Grid:mouse_moved()` currently does nothing unless `self.dragging` is set. Unconditionally update `self._hover_col`, `self._hover_row` from the incoming (x, y) at the top of that method — before the dragging early-return — so Grid always knows which cell the mouse is over.

**Label drawing:** At the end of `Grid:draw()`, after all items and the drag preview are drawn, render a name label for:
1. The hovered item (when nothing is being dragged) — item at `(_hover_col, _hover_row)`, label centred below its sprite.
2. The dragged item (`self.dragging`) — sprite position is already kept current by `_position_dragging_sprite`, so the label just follows it.

Label style: white text with a small semi-transparent dark backing rectangle for legibility against both the dark grid and the lighter stage area. Centred horizontally on the sprite's midpoint, 3 px below the sprite's bottom edge.

## What stays the same
- `kitchen_scene.lua` — no changes; label drawing happens entirely inside `Grid:draw()`
- `item_panel.lua` — no changes; the inner panel's Grid inherits the same hover/draw logic automatically
- `item_defs.lua` — no changes
- All existing drag, placement, and action logic

## Open questions
None — scope is clear and self-contained.
