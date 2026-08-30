# Design: Fix Stale Hover Label After Drag-Into-Panel

## Goal

When an item is dragged from the main grid into a panel (or vice versa), its hover label must not remain visible after the drag ends. Currently, the label often persists indefinitely after a cross-grid drop.

## Affected files

- `lua/game/grid.lua` — `Grid:mouse_moved`, `Grid:draw_labels`, `clear_preview_override`
- `game/scenes/kitchen_scene.lua` — `clear_drag`, `transfer_drag`, `transfer_drag_first_fit`, `KitchenScene:mouse_moved`
- `lua/game/item_panel.lua` — `ItemPanel:mouse_moved`

## Root cause

`Grid._hover_col` / `Grid._hover_row` are written by `Grid:mouse_moved` but are **never reset to `nil`**. They are effectively "last cell moused over on this grid, sticky forever" rather than "cell currently under the cursor."

During a cross-grid drag, `KitchenScene:mouse_moved` (lines 485–522) takes the "owner is set" early path and only updates `preview_override` (a separate set of fields) on the destination grid — it never calls the destination grid's `mouse_moved`, so that grid's `_hover_col/_hover_row` freeze at whatever value they held when the drag began.

When the drop lands via `transfer_drag` or `transfer_drag_first_fit`, `clear_drag` clears the drag bookkeeping on the source grid but touches nothing on the destination grid. If the stale hover cell happens to coincide with the cell the item landed on (very common — e.g. `(0,0)` is both a frequent first-moused-over cell and a common first-fit placement target), `Grid:draw_labels` re-evaluates `item_at(_hover_col, _hover_row)` each frame, finds the just-placed item, and draws its label persistently.

The same staleness applies outside of drags: `ItemPanel:mouse_moved` guards its pass-through with `self:_point_in_grid(x,y)` but has no else-branch to clear hover when the cursor leaves — so once a panel's grid is entered even briefly, its hover state sticks.

## What changes

**Two independent safeguards, both needed:**

### 1. Clear hover on both grids at drop time

In `clear_drag` (kitchen_scene.lua:281) and inside `transfer_drag` / `transfer_drag_first_fit` for the destination grid, nil out `_hover_col` and `_hover_row`:

```lua
grid._hover_col = nil
grid._hover_row = nil
```

This is the primary fix: at the moment of drop, both the source grid (via `clear_drag`) and the destination grid (inside `transfer_drag`/`transfer_drag_first_fit`) have their hover state zeroed. `draw_labels` then finds no hovered cell and draws nothing.

### 2. Add a `Grid:clear_hover()` helper and call it from `ItemPanel:mouse_moved` on leave

Add a small method to `Grid`:

```lua
function Grid:clear_hover()
    self._hover_col = nil
    self._hover_row = nil
end
```

Call it in the `else` branch of `ItemPanel:mouse_moved` when the cursor is outside the panel's grid and no drag is active, so the "sticky hover on mouse-leave" problem is addressed generally.

## What stays the same

- `draw_labels` logic and its per-grid iteration — no structural change.
- `preview_override` and the drop-preview outline system — untouched.
- The hover label behavior during normal (non-drag) hover/unhover on the main grid — still works the same way.
- Single-grid drag behavior — unchanged (source grid's own `mouse_moved` keeps running and keeps hover fresh).

## Open questions

None — root cause is confirmed, both fix sites are identified, the fix is small and localized.
