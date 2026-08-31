## Goal

Fix: dragging an item from the main floor grid and dropping it onto a pot that
is sitting inside an open microwave panel should insert the item into the pot's
own sub-inventory, not snap back.

## Affected files

- `game/scenes/kitchen_scene.lua` — `mouse_released` only
- `tests/test_kitchen_scene.lua` — new Test 22

## What changes

### Root cause

`mouse_released` in `kitchen_scene.lua` had a "drop onto a container" fast
path only for the **main floor grid** (`hover == self.grid`):

```lua
if hover == self.grid then
    local container = self:_container_at(x, y)   -- only checks self.grid
    if container and container ~= item and container.panel ~= owner then
        transfer_drag_first_fit(owner, container.panel, item)
        return
    end
end
```

When the cursor was over an open **panel** grid instead (e.g. the microwave's
inner grid), the code fell through to `transfer_drag`, which calls
`can_place` at the drop cell. The pot occupies those cells, so `can_place`
returned false and the item snapped back.

### Fix

Add an equivalent check just before the existing `transfer_drag` call, for the
case where `hover` is a non-floor panel grid:

```lua
if hover ~= nil and hover ~= self.grid and hover ~= owner then
    local col, row = hover:world_to_cell(x, y)
    local nested = hover:item_at(col, row)
    if nested and nested ~= item and nested.panel and not ancestor_processing(nested) then
        transfer_drag_first_fit(owner, nested.panel, item)
        return
    end
end
```

`ancestor_processing(nested)` walks up the ownership chain — if the microwave
is currently running a Cook action the drop is blocked, matching the
existing lock behavior for other panel interactions.

## What stays the same

- Dragging items directly onto the microwave's main-floor footprint (no panel
  open) still works via the existing `_container_at` path.
- All existing cross-grid drag mechanics (panel ↔ main floor, panel ↔ panel)
  are unchanged.
- The lock logic (no interaction while an ancestor is processing) is applied
  consistently using the existing `ancestor_processing` helper.

## Open questions

None — the bug is deterministic and the fix is localized to three new guard
lines in `mouse_released`.
