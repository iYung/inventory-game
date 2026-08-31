## Same-Panel Nested Container Drop Fix Checklist

- [x] Fix — `game/scenes/kitchen_scene.lua` — remove `hover ~= owner` from the
  nested-container guard in `mouse_released` (line ~700) so a dragged item can
  be dropped onto a has_panel item that lives in the same parent panel as the
  dragged item

- [x] Test — `tests/test_same_panel_nested_drop.lua` — add a test that drags an
  item onto a nested container when both are inside the same parent panel,
  asserting the item ends up in the nested panel (not snapped back to its
  original cell)
