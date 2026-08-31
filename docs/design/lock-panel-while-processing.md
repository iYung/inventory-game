## Goal

Prevent players from clicking and dragging items inside a container's panel
(microwave, meat_machine, etc.) while that container has a running action. Items
should be locked in place during processing — rearranging ingredients mid-cook
makes no sense and causes confusing state.

## Affected files

- `lua/game/item_panel.lua` — `ItemPanel:mouse_pressed` is the sole entry-point
  for grid interaction inside a panel; the fix lives here.

## What changes

Add a guard at the top of the `_point_in_grid` branch in `ItemPanel:mouse_pressed`.
Before forwarding the click to `self.item.panel:mouse_pressed(x, y)`, check
whether `self.item` has any running action:

```lua
-- Returns true iff any action on item is currently running.
local function any_action_running(item)
    for _, state in pairs(item.action_state or {}) do
        if state.running then return true end
    end
    return false
end
```

If `any_action_running(self.item)` is true, the grid branch still returns `true`
(the click is consumed — it must not fall through to whatever is behind the panel)
but does NOT call `self.item.panel:mouse_pressed`, so no drag is initiated.

The double-click-to-open guard in `KitchenScene:mouse_pressed` (which calls
`self:_try_double_click_open(panel.item.panel, x, y)` before forwarding to
`panel:mouse_pressed`) doesn't need changing — opening the panel to inspect it
while processing is fine; only dragging items inside is blocked.

## What stays the same

- The panel can still be opened and closed while processing.
- Buttons are already visually disabled when an action is running (grey color)
  and `start_action` returns false if already running — no change there.
- Items inside the panel are still visible; they just can't be dragged.
- All other grids (main floor, other panels) are unaffected.

## Open questions

None — the fix is localised to a single guard in one method.
