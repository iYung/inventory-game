## Fix Failing Tests Checklist

- [x] Task A — `lua/headless/stubs.lua` — add `love = love or {}` as the first executable line so the stub works when `love` is nil (luajit headless); add `love.timer` stub
- [x] Task B — `lua/game/merchant_gen.lua` — change `MIN_NEW = 1 → 2`, `MAX_NEW = 2 → 3`, `MAX_SLOTS = 3 → 4` to match design comment and test assertions
- [x] Task C — `tests/test_item.lua` — add `require("lua/headless/stubs")` as the first line before any game require
- [x] Task D — `tests/test_item_panel.lua` — add `require("lua/headless/stubs")` as the first line
- [x] Task E — `tests/test_customer.lua` — add `require("lua/headless/stubs")` as the first line; fix test 4b kind assertion (`"merchant"` → `"restock"`); add `ProgramState` arg to `CustomerQueue.new`; compute `total_qty` from entry quantities
- [x] Task F — `tests/test_overnight.lua` — add `require("lua/headless/stubs")` as the first line
- [x] Task G — `tests/test_basics.lua` — add `require("lua/headless/stubs")` as the first line
- [x] Task H — `tests/test_kitchen_scene.lua` — add `require("lua/headless/stubs")` as the first line; update `order_cfg()` helper with new format and defaults; fix baked_chicken placement col for test 1; drain full queue with while loop in test 10; add order_rules override in test 15; move merchant panel out of drop-target area in test 6
- [x] Task I — `tests/test_same_panel_nested_drop.lua` — add `require("lua/headless/stubs")` as the first line; place container manually at (10,0) instead of relying on pre-placed item
- [x] Task J — `lua/game/customer.lua` — store `loved_tags`/`liked_tags`/`disliked_tags` in `show()`; add `"merchant"` kind handler
- [x] Task K — `game/scenes/kitchen_scene.lua` — restore microwave at (0,0) + fryer at (0,2) in `on_enter()`; add broccoli (5,0), potato (6,0), coffee_machine (6,2), container (4,4) pre-stocked with roasted_coffee_bean×2/milking_center/cheese_cave, garden (0,4); add `"merchant"` to click handler
