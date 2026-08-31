## Lock Panel While Processing Checklist

- [ ] Task A — `lua/game/item_panel.lua` — Add `any_action_running(item)` local helper and a guard in `ItemPanel:mouse_pressed`'s `_point_in_grid` branch: if any action on `self.item` is running, return `true` without forwarding to `self.item.panel:mouse_pressed` (consume the click but do not start a drag).

- [ ] Task B — `tests/test_item_panel.lua` — Add tests verifying that clicking in the panel grid while an action is running does NOT set `panel.item.panel.dragging` (drag is blocked), and that clicking in the same grid while no action is running still initiates a drag normally.
