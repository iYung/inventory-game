-- tests/test_item_panel.lua
-- Headless tests for lua/game/item_panel.lua.
--
-- ItemPanel wraps a real Item's `panel` Grid, so these tests use the real
-- Item/Grid classes directly (both already exist as real files, per Wave 1),
-- following the same "place an item into a panel grid" pattern as
-- tests/test_item.lua.

local Item      = require("lua/game/item")
local ItemPanel = require("lua/game/item_panel")
local Grid      = require("lua/game/grid")
local config    = require("lua/game/config")

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

-- Test 3b: is_action_enabled("Cook") is also true for broccoli - the
-- single Cook button matches whichever of its recipes the panel satisfies.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local broccoli = Item.new("broccoli")
    microwave.panel:place(broccoli, 0, 0)

    assert(panel:is_action_enabled("Cook") == true,
        "Cook should be enabled with broccoli in the panel too, not just raw_meat")
    print("PASS: item_panel: is_action_enabled is true for any of Cook's recipes, not just the first")
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
-- x,y fall inside the panel's screen bounds. The microwave's panel is a
-- single cell (1x1), so there's no second in-panel cell to move an item
-- to - this exercises the forwarding itself (start a drag, track it, drop
-- it back on its own only cell) rather than an actual cell-to-cell move.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)

    local px, py = microwave.panel:cell_to_world(0, 0)
    panel:mouse_pressed(px + 1, py + 1)
    assert(microwave.panel.dragging == meat,
        "mouse_pressed inside the panel grid bounds should forward to panel:mouse_pressed and start a drag")

    panel:mouse_moved(px + 2, py + 2)
    panel:mouse_released(px + 2, py + 2)

    assert(microwave.panel.dragging == nil, "mouse_released should clear the panel's drag state")
    assert(meat.cell_col == 0 and meat.cell_row == 0,
        "dropping back on the panel's only cell via ItemPanel forwarding should leave the item there")

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

-- Test 8: the close button sets should_close; other clicks don't. -----------

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    -- A click inside the grid area should not close the panel.
    local px, py = microwave.panel:cell_to_world(0, 0)
    panel:mouse_pressed(px + 1, py + 1)
    assert(panel.should_close == false, "clicking inside the grid should not close the panel")
    panel:mouse_released(px + 1, py + 1)

    -- A click on the close button should.
    local cb = panel.close_button
    panel:mouse_pressed(cb.x + cb.w / 2, cb.y + cb.h / 2)
    assert(panel.should_close == true, "clicking the close button should set should_close")

    print("PASS: item_panel: close button sets should_close, other clicks don't")
end

-- Test 9: the panel is draggable by its title bar, and everything (grid, --
-- buttons, close button, the real panel Grid's origin) moves with it.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local start_grid_x, start_grid_y = panel.grid_x, panel.grid_y
    local tb = panel.title_bar

    -- Press somewhere in the title bar away from the close button.
    local px, py = tb.x + 10, tb.y + tb.h / 2
    panel:mouse_pressed(px, py)
    assert(panel._dragging_panel == true, "pressing the title bar should start dragging the panel")
    assert(panel.should_close == false, "dragging the title bar should not close the panel")

    panel:mouse_moved(px + 40, py + 25)
    assert(panel.grid_x == start_grid_x + 40 and panel.grid_y == start_grid_y + 25,
        "dragging the title bar should move the grid position by the same delta")
    assert(microwave.panel.origin_x == panel.grid_x and microwave.panel.origin_y == panel.grid_y,
        "the real panel Grid's origin should track the panel's new position")

    panel:mouse_released(px + 40, py + 25)
    assert(panel._dragging_panel == false, "mouse_released should stop the panel drag")

    -- A press inside the grid should not be mistaken for a title-bar drag.
    local gx, gy = microwave.panel:cell_to_world(0, 0)
    panel:mouse_pressed(gx + 1, gy + 1)
    assert(panel._dragging_panel == false, "pressing inside the grid should not start a panel drag")

    print("PASS: item_panel: the panel is draggable by its title bar")
end

-- Merchant-kind fake item ----------------------------------------------------
-- Customer (a parallel task) isn't guaranteed to have its kind/panel/type_id
-- fields yet, so these tests use a small fake table instead of require-ing
-- lua/game/customer.lua - just the fields ItemPanel actually reads off
-- `item`: .panel (a real Grid), .type_id (def/title lookup), .kind (merchant
-- detection), .action_state (read defensively for is_action_enabled/draw,
-- matching what an item with zero actions needs - an empty table is enough
-- since a merchant's def has no `actions` to iterate).

local function make_fake_merchant()
    return {
        kind         = "merchant",
        type_id      = "merchant",
        panel        = Grid.new(config.MERCHANT_PANEL_COLS, config.MERCHANT_PANEL_ROWS, config.U, 0, 0),
        action_state = {},
    }
end

-- Test 10: a merchant-kind item's panel has a valid "Leave" button rect. ----

do
    local merchant = make_fake_merchant()
    local panel = ItemPanel.new(merchant)

    local rect = panel.buttons["Leave"]
    assert(rect, "merchant-kind item's panel should have a Leave button")
    assert(type(rect.x) == "number" and type(rect.y) == "number"
       and type(rect.w) == "number" and type(rect.h) == "number",
        "Leave button rect should have numeric x/y/w/h")
    assert(rect.w > 0 and rect.h > 0, "Leave button rect should have positive size")

    print("PASS: item_panel: merchant-kind item's panel has a Leave button")
end

-- Test 11: clicking the Leave button sets both should_close and ------------
-- should_leave.

do
    local merchant = make_fake_merchant()
    local panel = ItemPanel.new(merchant)

    local rect = panel.buttons["Leave"]
    local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2

    assert(panel.should_close == false, "should_close should start false")
    assert(panel.should_leave == false, "should_leave should start false")

    local handled = panel:mouse_pressed(cx, cy)
    assert(handled == true, "clicking the Leave button should be handled (consumed) by the panel")
    assert(panel.should_close == true, "clicking Leave should set should_close")
    assert(panel.should_leave == true, "clicking Leave should set should_leave")

    print("PASS: item_panel: clicking Leave sets both should_close and should_leave")
end

-- Test 12: a non-merchant item's panel (the microwave) has NO Leave button, -
-- and clicking where a Leave button would sit for a merchant does nothing.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    assert(panel.buttons["Leave"] == nil,
        "non-merchant item's panel should have no Leave button")

    -- Compute where a Leave button would sit if this panel were merchant-kind
    -- (the next slot in the same button row, after the existing Cook
    -- button), and click there anyway - should be a no-op, not an error.
    local cook = panel.buttons["Cook"]
    local BUTTON_GAP = 8 -- matches item_panel.lua's internal BUTTON_GAP
    local leave_x = cook.x + cook.w + BUTTON_GAP + cook.w / 2
    local leave_y = cook.y + cook.h / 2

    local handled = panel:mouse_pressed(leave_x, leave_y)
    assert(panel.should_leave == false,
        "clicking where Leave would be on a non-merchant panel should not set should_leave")

    print("PASS: item_panel: non-merchant panel has no Leave button; clicking its would-be spot is a no-op")
end

-- Test 13: draw() does not error for a merchant-kind panel, including the --
-- Leave button drawing path.

do
    local merchant = make_fake_merchant()
    local panel = ItemPanel.new(merchant)
    panel:draw() -- must not error, including the Leave button branch
    print("PASS: item_panel: draw() does not error for a merchant-kind panel")
end

-- Test 14: _point_in_bg covers the whole backdrop, including dead space --
-- that isn't the title bar, grid, or any button - used by KitchenScene so a
-- click anywhere on a panel is claimed by it (panels are opaque windows).

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    assert(panel:_point_in_bg(panel.bg.x + 2, panel.bg.y + 2),
        "a point just inside the backdrop's top-left corner should count as in-bg")
    assert(panel:_point_in_bg(panel.bg.x + panel.bg.w - 2, panel.bg.y + panel.bg.h - 2),
        "a point just inside the backdrop's bottom-right corner should count as in-bg")
    assert(not panel:_point_in_bg(panel.bg.x - 5, panel.bg.y - 5),
        "a point outside the backdrop entirely should not count as in-bg")
    -- The title bar sits inside the backdrop, so a point on it is in-bg too.
    assert(panel:_point_in_bg(panel.title_bar.x + 5, panel.title_bar.y + 5),
        "a point on the title bar should also count as in-bg (it's part of the backdrop)")

    print("PASS: item_panel: _point_in_bg covers the whole backdrop")
end

-- Test 15: a fully-loaded dutch oven sitting inside the microwave's own -----
-- panel enables Cook, via the container-recipe path in Item.matching_recipes.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local dutch_oven = Item.new("dutch_oven")
    assert(microwave.panel:can_place(dutch_oven, 0, 0),
        "dutch oven (2x1) should fit in the microwave's 2-col panel")
    microwave.panel:place(dutch_oven, 0, 0)

    local potato   = Item.new("potato")
    local water    = Item.new("water")
    local raw_meat = Item.new("raw_meat")
    dutch_oven.panel:place(potato, 0, 0)
    dutch_oven.panel:place(water, 1, 0)
    dutch_oven.panel:place(raw_meat, 2, 0)

    assert(panel:is_action_enabled("Cook") == true,
        "Cook should be enabled when a fully-loaded dutch oven sits in the microwave's panel")

    print("PASS: item_panel: is_action_enabled is true for a fully-loaded dutch oven in the microwave")
end

-- Test 16: a partially-loaded dutch oven (missing raw_meat) in the ----------
-- microwave's panel does not enable Cook.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local dutch_oven = Item.new("dutch_oven")
    assert(microwave.panel:can_place(dutch_oven, 0, 0), "dutch oven should fit in the microwave's panel")
    microwave.panel:place(dutch_oven, 0, 0)

    local potato = Item.new("potato")
    local water  = Item.new("water")
    dutch_oven.panel:place(potato, 0, 0)
    dutch_oven.panel:place(water, 1, 0)
    -- No raw_meat placed - the dutch oven is only partially loaded.

    assert(panel:is_action_enabled("Cook") == false,
        "Cook should stay disabled when the dutch oven is missing an ingredient")

    print("PASS: item_panel: is_action_enabled is false for a partially-loaded dutch oven")
end

-- Test 17: a fully-loaded dutch oven sitting loose on the main floor grid --
-- (not inside the microwave's own panel) does not enable the microwave's
-- Cook button - the container must actually be present in the microwave's
-- panel, not just exist somewhere satisfying its own requires.

do
    local floor_grid = Grid.new(config.GRID_COLS, config.GRID_ROWS, config.U, 0, 0)

    local dutch_oven = Item.new("dutch_oven")
    assert(floor_grid:can_place(dutch_oven, 0, 0), "dutch oven should fit on the main floor grid")
    floor_grid:place(dutch_oven, 0, 0)

    local potato   = Item.new("potato")
    local water    = Item.new("water")
    local raw_meat = Item.new("raw_meat")
    dutch_oven.panel:place(potato, 0, 0)
    dutch_oven.panel:place(water, 1, 0)
    dutch_oven.panel:place(raw_meat, 2, 0)

    -- A fresh microwave, with nothing in its own panel - the fully-loaded
    -- dutch oven above is not sitting inside it.
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    assert(panel:is_action_enabled("Cook") == false,
        "Cook should stay disabled when a loaded dutch oven exists but isn't inside the microwave's panel")

    print("PASS: item_panel: is_action_enabled is false when the dutch oven isn't inside the microwave's panel")
end

-- Test 18: sanity check that the new plain potato -> baked_potato recipe ---
-- still enables Cook through the Item.matching_recipes-backed is_action_enabled.

do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)

    local potato = Item.new("potato")
    microwave.panel:place(potato, 0, 0)

    assert(panel:is_action_enabled("Cook") == true,
        "Cook should be enabled with a lone potato in the panel (potato -> baked_potato)")

    print("PASS: item_panel: is_action_enabled is true for the plain potato recipe")
end

print("ALL TESTS PASSED")
