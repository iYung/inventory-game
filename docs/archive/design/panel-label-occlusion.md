# Panel Label Occlusion Fix

## Goal

Item labels (the name/tag tooltip shown when hovering or dragging an item) must not render
on top of an open ItemPanel that is positioned over that item. This applies to any occluded
grid — the main floor grid and any panel's inner grid — regardless of how many panels are
stacked on top of each other.

## Affected files

- `game/scenes/kitchen_scene.lua` — the only place that wires `mouse_moved` and the label
  draw loop together; the fix lives entirely here.

## What changes

### Root cause

`KitchenScene:mouse_moved` (no-drag branch) forwards to `self.grid:mouse_moved(x, y)` and
then `panel:mouse_moved(x, y)` for every open panel. `ItemPanel:mouse_moved` calls
`self.item.panel:mouse_moved(x, y)` only when the cursor is geometrically inside that
panel's grid rect, but this check is purely geometric — it does not know whether a
*higher-z* panel is visually occluding that same screen area.

As a result, a panel's inner grid (or the floor grid) can end up with `_hover_col/_hover_row`
set to a cell that is completely hidden behind a panel drawn on top of it. Since
`draw_labels()` is called for all grids last (after all panels are drawn), the label
renders on top of the covering panel's backdrop.

This applies to all stacking combinations:
- Floor item label visible through a panel covering the floor.
- Panel A's inner item label visible through panel B stacked on top of panel A.

### Fix

In `KitchenScene:mouse_moved`, no-drag branch, after all the existing `mouse_moved`
forwards (kept intact so title-bar panel dragging still works):

1. Walk `self.panels` back-to-front to find the **topmost panel whose backdrop covers
   (x,y)** — call it `top_cover`.
2. If `top_cover` exists, call `self.grid:clear_hover()` and, for every panel whose index
   is less than `top_cover`'s index (i.e. drawn below it), call
   `panel.item.panel:clear_hover()`.

`top_cover` itself is left alone — `ItemPanel:mouse_moved` already manages its inner
grid's hover correctly, and it is the topmost thing at the cursor so its label is
legitimate.

The drag case is intentionally untouched. A dragged item's label uses `self.dragging`, not
`_hover_col/_hover_row`, and appearing above a panel while dragging is correct UX.

### Concrete change (pseudo-code)

```lua
-- existing forwards (unchanged)
self.grid:mouse_moved(x, y)
for _, panel in ipairs(self.panels) do panel:mouse_moved(x, y) end

-- new: suppress hover for every grid occluded by a higher-z panel
local top_cover = nil
for i = #self.panels, 1, -1 do
    if self.panels[i]:_point_in_bg(x, y) then
        top_cover = self.panels[i]
        break
    end
end
if top_cover then
    self.grid:clear_hover()
    for _, panel in ipairs(self.panels) do
        if panel ~= top_cover then
            panel.item.panel:clear_hover()
        end
    end
end
```

## What stays the same

- All existing drag, drop, cross-grid transfer, and panel interaction logic is untouched.
- Title-bar panel dragging (`_dragging_panel`) still works — `panel:mouse_moved` is still
  called for all panels before the hover correction.
- Labels for items inside the topmost panel's own inner grid still work normally.
- Labels while dragging still appear above everything (correct behavior).

## Open questions

None.
