# Same-Panel Nested Container Drop Fix

## Goal

Fix a bug where dragging item A onto item B fails when both A and B are already
inside the same parent container's panel (e.g., dragging water into a pot that's
both sitting inside a microwave panel).

## Affected files

- `game/scenes/kitchen_scene.lua` — one-line condition change in `mouse_released`

## What changes

`KitchenScene:mouse_released` (line 700) checks whether the drop target is a
nested container item and, if so, transfers the dragged item into that
container's panel via first-fit placement. The guard currently reads:

```lua
if hover ~= nil and hover ~= self.grid and hover ~= owner then
```

The `hover ~= owner` clause excludes the case where the drag originated from the
same panel grid as the drop target — i.e., both items live inside the same parent
container. In that scenario `hover == owner`, so the check never fires and the
dragged item snaps back to its pre-drag cell instead of entering the nested panel.

The fix removes `hover ~= owner` from the condition. The nested-container path
is safe to run even when `hover == owner`: if the cell under the cursor holds no
item with a panel, `nested.panel` is nil or `nested` is nil, so we fall through
to the normal `owner:mouse_released` path unchanged.

## What stays the same

- Floor-grid container drops (hover == self.grid, handled earlier at line 687) —
  unchanged.
- Cross-panel drops where hover is a completely different panel — unchanged, they
  still pass both `hover ~= self.grid` and now work without the removed guard.
- Normal same-panel moves (item dropped onto an empty cell in the same panel) —
  fall through to `owner:mouse_released` as before, since `nested` or
  `nested.panel` will be nil.
- All transfer helpers (`transfer_drag`, `transfer_drag_first_fit`) — unchanged.

## Open questions

None — root cause is clear and the fix is minimal.
