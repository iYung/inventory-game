## Pot-in-Microwave Drop Checklist

- [x] Fix `game/scenes/kitchen_scene.lua` — add nested-container drop check in `mouse_released` before the `transfer_drag` call: when the hover grid is a panel grid and the drop cell holds a `has_panel` item, call `transfer_drag_first_fit` into that item's panel instead of falling through to a failing `can_place`
- [x] Add Test 22 to `tests/test_kitchen_scene.lua` — places a pot in an open microwave panel, drags a floor item onto the pot's cell, asserts the item lands in the pot's panel and is gone from the main grid
