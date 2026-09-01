## Merchant Panel Purchase Guards Checklist

- [x] Task A — `game/scenes/kitchen_scene.lua` — Add `_is_merchant_grid(grid)` helper: returns true when `self.customer` is active, kind is `"restock"` or `"program"`, and `grid == self.customer.panel`.

- [x] Task B — `game/scenes/kitchen_scene.lua` — Add `_can_afford_merchant_item(x, y)` helper: looks up the item at (x,y) in `self.customer.panel` and returns true if the player can afford it (restock/extra → `RESTOCK_ITEM_COST`; program machine unowned/unpaid → `prog.cost`; already owned or already paid this visit → free).

- [x] Task C — `game/scenes/kitchen_scene.lua` — In `_try_double_click_open`, after the `ancestor_processing` guard, add: if `_is_merchant_grid(grid)` return false (skip the open without recording the click).

- [x] Task D — `game/scenes/kitchen_scene.lua` — In `_open_container_at`, after the `ancestor_processing` guard, add: if `_is_merchant_grid(grid)` return.

- [x] Task E — `game/scenes/kitchen_scene.lua` — In `mouse_pressed`, inside the panel loop where `panel:_point_in_grid(x, y)` is true (after the `_try_double_click_open` check), add: if `_is_merchant_grid(panel.item.panel)` and `not _can_afford_merchant_item(x, y)`, return early before `panel:mouse_pressed`.

- [x] Task F — `game/scenes/kitchen_scene.lua` — In `mouse_released`, inside the cross-grid transfer block (`hover ~= nil and hover ~= owner`), add a guard at the top: if `_is_merchant_grid(hover)`, call `owner:mouse_released(x, y)` to snap back and return.
