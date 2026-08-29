-- tests/test_item_panel.lua
-- Headless tests for lua/game/item_panel.lua.
--
-- ItemPanel wraps a real Item's `panel` Grid, so these tests use the real
-- Item/Grid classes directly (both already exist as real files, per Wave 1),
-- following the same "place an item into a panel grid" pattern as
-- tests/test_item.lua.

local Item      = require("lua/game/item")
local ItemPanel = require("lua/game/item_panel")

-- Test 1: ItemPanel.new errors if item.panel is nil (not a container). -----

do
    local meat = Item.new("raw_meat")
    local ok, err = pcall(ItemPanel.new, meat)
    assert(ok == false, "ItemPanel.new should error for an item with no panel")
    print("PASS: item_panel: ItemPanel.new errors when item.panel is nil")
end

-- Test 2: is_action_enabled("Cook") is false on a fresh (empty) microwave. --

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    assert(panel.item == microwave, "ItemPanel should store the item")
    assert(panel:is_action_enabled("Cook") == false,
        "Cook should be disabled with an empty panel")
    print("PASS: item_panel: is_action_enabled is false with an empty panel")
end

-- Test 3: is_action_enabled becomes true once a matching raw_meat item is --
-- placed into the panel grid.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local meat = Item.new("raw_meat")
    local placed = microwave.panel:place(meat, 0, 0)

    assert(panel:is_action_enabled("Cook") == true,
        "Cook should be enabled once a matching raw_meat item is in the panel")
    print("PASS: item_panel: is_action_enabled is true once a matching item is placed")
end

-- Test 4: clicking the enabled button (via mouse_pressed at the button's --
-- rect coordinates) starts the timer; is_action_enabled then reports false
-- because the action is running (re-clicking mid-cook shouldn't re-trigger).

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)

    local rect = panel.buttons["Cook"]
    assert(rect, "panel should have a button rect for the Cook action")

    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    panel:mouse_pressed(cx, cy)

    assert(microwave.action_state["Cook"] ~= nil, "clicking the button should start the Cook action")
    assert(microwave.action_state["Cook"].running == true, "action_state['Cook'].running should be true")
    assert(panel:is_action_enabled("Cook") == false,
        "is_action_enabled should be false while the action is already running")

    -- Re-clicking mid-cook should not re-trigger / reset the timer.
    microwave:update(1.0)
    local elapsed_before = microwave.action_state["Cook"].elapsed
    panel:mouse_pressed(cx, cy)
    assert(microwave.action_state["Cook"].elapsed == elapsed_before,
        "re-clicking the button mid-cook should not restart the timer")

    print("PASS: item_panel: clicking an enabled button starts the action timer")
end

-- Test 4b: clicking a disabled button (empty panel) does not start anything.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local rect = panel.buttons["Cook"]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    panel:mouse_pressed(cx, cy)

    assert(microwave.action_state["Cook"] == nil,
        "clicking a disabled button should not start the action")
    print("PASS: item_panel: clicking a disabled button is a no-op")
end

-- Test 5: ticking item:update(dt) past the action's duration completes it, --
-- and the panel's contents change from raw_meat to cooked_meat.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)

    local rect = panel.buttons["Cook"]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
    panel:mouse_pressed(cx, cy)
    assert(microwave.action_state["Cook"].running == true, "Cook should be running after the click")

    -- Advance short of duration (3.0s): should still be running, panel still
    -- holds raw_meat.
    microwave:update(1.0)
    local mid_items = microwave.panel:items()
    assert(#mid_items == 1 and mid_items[1].type_id == "raw_meat",
        "panel should still contain raw_meat before the action completes")

    -- Advance past duration.
    microwave:update(2.5)

    assert(microwave.action_state["Cook"] == nil, "action_state['Cook'] should be cleared after completion")

    local final_items = microwave.panel:items()
    assert(#final_items == 1, "panel should still contain exactly one item after completion")
    assert(final_items[1].type_id == "cooked_meat",
        "panel item should have transformed from raw_meat to cooked_meat, got " .. tostring(final_items[1].type_id))

    assert(panel:is_action_enabled("Cook") == false,
        "Cook should be disabled again once the panel only holds cooked_meat (no raw_meat left)")

    print("PASS: item_panel: update(dt) past duration completes the action and transforms panel contents")
end

-- Test 6: mouse_pressed/moved/released forward into the panel grid when --
-- x,y fall inside the panel's screen bounds (drag an item within the panel).

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)

    local px, py = microwave.panel:cell_to_world(0, 0)
    panel:mouse_pressed(px + 1, py + 1)
    assert(microwave.panel.dragging == meat,
        "mouse_pressed inside the panel grid bounds should forward to panel:mouse_pressed and start a drag")

    local tx, ty = microwave.panel:cell_to_world(1, 0)
    panel:mouse_moved(tx + 1, ty + 1)
    panel:mouse_released(tx + 1, ty + 1)

    assert(microwave.panel.dragging == nil, "mouse_released should clear the panel's drag state")
    assert(meat.cell_col == 1 and meat.cell_row == 0,
        "dragging within the panel via ItemPanel forwarding should move the item to the new cell")

    print("PASS: item_panel: mouse_pressed/moved/released forward into the panel grid")
end

-- Test 7: draw() does not error under the headless love.graphics stub. -----

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)
    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)
    panel:mouse_pressed(panel.buttons["Cook"].x + 1, panel.buttons["Cook"].y + 1)
    panel:draw() -- must not error, including the running-action progress bar branch
    print("PASS: item_panel: draw() does not error under the headless stub")
end

print("ALL TESTS PASSED")
