-- tests/test_kitchen_scene.lua
-- Headless integration test: drives a full "drag raw_meat onto the waiting
-- customer" serve through KitchenScene's public mouse_pressed/moved/released
-- methods (not real love.mouse* events, which aren't available headless).
--
-- The MVP CustomerQueue always requests "cooked_meat", but on_enter() only
-- pre-places "raw_meat" on the grid (cooking it requires running the
-- microwave's timed action first). To test the serve/consume mechanism
-- itself without also driving the cook timer, this test overrides the
-- on-stage customer's requested_type to "raw_meat" right before the drag —
-- a direct field poke that's fine for a test exercising the drop-to-serve
-- wiring rather than the cooking pipeline (covered separately by
-- tests/test_item.lua / tests/test_item_panel.lua).

local runner        = require("lua/headless/runner")
local KitchenScene   = require("game/scenes/kitchen_scene")

local ctx = runner.setup(function(input, sm)
    return KitchenScene.new()
end)

local scene = ctx.sm.current

-- Tick (dt = 1.0 per step) until the first customer has walked in and is
-- waiting.
runner.fast_forward_until(ctx, function()
    return scene.customer:arrived()
end, 0)

assert(scene.customer:arrived(), "customer should be waiting after fast-forwarding")

-- Force a matching request so the drop below counts as a serve.
scene.customer.requested_type = "raw_meat"

-- Find the raw_meat item placed at on_enter and its world position.
local meat
for _, it in ipairs(scene.grid:items()) do
    if it.type_id == "raw_meat" then
        meat = it
        break
    end
end
assert(meat, "on_enter should have placed a raw_meat item on the grid")

local mx, my = scene.grid:cell_to_world(meat.cell_col, meat.cell_row)
mx, my = mx + 1, my + 1 -- a point safely inside the item's cell

local currency_before = scene.day_state.currency
local served_before   = scene.day_state.customers_served

-- Start the drag on the raw_meat item.
scene:mouse_pressed(mx, my)
assert(scene.grid.dragging == meat, "mouse_pressed on the meat's cell should start dragging it")

-- Drag it onto the customer (customer.x/y is the sprite's center point, so
-- it's guaranteed to land inside the customer's clickable body).
local cx, cy = scene.customer.x, scene.customer.y
scene:mouse_moved(cx, cy)
scene:mouse_released(cx, cy)

assert(scene.grid.dragging == nil, "dropping onto the customer should clear the grid's drag state")
assert(scene.day_state.currency == currency_before + 10,
    "currency should increase by 10 on a matching-item serve, got " .. tostring(scene.day_state.currency))
assert(scene.day_state.customers_served == served_before + 1,
    "customers_served should increment by 1")

local still_on_grid = false
for _, it in ipairs(scene.grid:items()) do
    if it == meat then still_on_grid = true end
end
assert(not still_on_grid, "the served raw_meat item should be removed from the grid")
assert(meat.grid == nil, "the served item's grid reference should be cleared")

print("PASS: kitchen_scene: dragging a matching item onto the waiting customer serves them and consumes the item")

-- Regression test: a served customer must actually be able to move on.
-- Customer:serve() enters "talking_after" to show the thank-you message;
-- only Customer:advance_after() (wired to a plain click on the customer)
-- takes it from there to "walking_out". Without that wiring the customer
-- gets stuck showing the same line forever and the fast_forward_until
-- below would hit its iteration cap.

assert(scene.customer.state == "talking_after",
    "serving with after_messages configured should enter talking_after, got " .. scene.customer.state)

-- First click just completes the typewriter reveal of the (only)
-- after-message; second click advances past it into walking_out.
scene:mouse_pressed(cx, cy)
assert(scene.customer.state == "talking_after",
    "clicking mid-reveal should only complete the reveal, not leave yet")

scene:mouse_pressed(cx, cy)
assert(scene.customer.state == "walking_out",
    "clicking after the after-message is fully revealed should send the customer into walking_out")

runner.fast_forward_until(ctx, function() return scene.customer:arrived() end, 0)
assert(scene.customer:arrived(), "the next customer should walk in and become waiting once the served one leaves")
assert(scene.day_state.customers_served == served_before + 1,
    "customers_served should still be exactly 1 after the first customer fully walks off")

print("PASS: kitchen_scene: clicking a served customer advances them through to walking_out and the next customer arrives")

-- Test 2: main-grid items stay draggable while a panel is open, and dragging
-- one onto the open panel's grid transfers it there (and back out again).

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx2 = runner.setup(function() return KitchenScene.new() end)
    local scene2 = ctx2.sm.current

    local microwave, meat2
    for _, it in ipairs(scene2.grid:items()) do
        if it.type_id == "microwave" then microwave = it end
        if it.type_id == "raw_meat" and not meat2 then meat2 = it end
    end
    assert(microwave and meat2, "on_enter should have placed a microwave and raw_meat")

    scene2.panel = ItemPanel.new(microwave)

    -- Start dragging the meat straight from the main grid while the panel
    -- is open; this must work exactly like it would with no panel open.
    local mx, my = scene2.grid:cell_to_world(meat2.cell_col, meat2.cell_row)
    mx, my = mx + 1, my + 1
    scene2:mouse_pressed(mx, my)
    assert(scene2.grid.dragging == meat2,
        "main-grid items should still be draggable while a panel is open")

    -- Drop it onto the open panel's inner grid: should transfer there.
    local px, py = microwave.panel:cell_to_world(0, 0)
    scene2:mouse_moved(px + 1, py + 1)
    scene2:mouse_released(px + 1, py + 1)

    assert(scene2.grid.dragging == nil, "drop should clear the main grid's drag state")
    assert(meat2.grid == microwave.panel, "item dropped on the panel grid should now belong to it")

    local still_on_main_grid = false
    for _, it in ipairs(scene2.grid:items()) do
        if it == meat2 then still_on_main_grid = true end
    end
    assert(not still_on_main_grid, "transferred item should be gone from the main grid")

    local in_panel = false
    for _, it in ipairs(microwave.panel:items()) do
        if it == meat2 then in_panel = true end
    end
    assert(in_panel, "transferred item should be listed in the panel's grid")

    -- Drag it back out onto the main floor grid.
    scene2:mouse_pressed(px + 1, py + 1)
    assert(microwave.panel.dragging == meat2, "should be able to pick the item back up from the panel")

    local ox, oy = scene2.grid:cell_to_world(3, 3)
    scene2:mouse_moved(ox + 1, oy + 1)
    scene2:mouse_released(ox + 1, oy + 1)

    assert(microwave.panel.dragging == nil, "drop should clear the panel grid's drag state")
    assert(meat2.grid == scene2.grid, "item dragged back out should belong to the main grid again")
    assert(meat2.cell_col == 3 and meat2.cell_row == 3, "item should land at the dropped cell on the main grid")

    print("PASS: kitchen_scene: dragging items between the main grid and an open panel transfers them")
end

-- Test 3: dragging the open panel by its title bar, through KitchenScene's
-- own mouse_pressed/moved/released, actually stops when the mouse is
-- released. Regression test: KitchenScene:mouse_released used to reach past
-- ItemPanel straight into the inner panel Grid, so ItemPanel._dragging_panel
-- (set on title-bar press) was never cleared and the panel followed the
-- cursor forever.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx3 = runner.setup(function() return KitchenScene.new() end)
    local scene3 = ctx3.sm.current

    local microwave3
    for _, it in ipairs(scene3.grid:items()) do
        if it.type_id == "microwave" then microwave3 = it end
    end
    assert(microwave3, "on_enter should have placed a microwave")

    scene3.panel = ItemPanel.new(microwave3)
    local tb = scene3.panel.title_bar

    scene3:mouse_pressed(tb.x + 10, tb.y + tb.h / 2)
    assert(scene3.panel._dragging_panel == true, "pressing the title bar (via the scene) should start dragging the panel")

    scene3:mouse_moved(tb.x + 60, tb.y + 40)
    assert(scene3.panel.grid_x ~= nil, "panel should have re-laid-out after the move")

    scene3:mouse_released(tb.x + 60, tb.y + 40)
    assert(scene3.panel._dragging_panel == false,
        "releasing the mouse (via the scene) should stop the panel drag")

    -- It should really be stopped: further mouse_moved calls (as if the
    -- mouse kept moving after release) must not keep relocating the panel.
    local gx_after_release = scene3.panel.grid_x
    scene3:mouse_moved(tb.x + 500, tb.y + 500)
    assert(scene3.panel.grid_x == gx_after_release,
        "the panel must not keep following the cursor after mouse_released")

    print("PASS: kitchen_scene: dragging the panel by its title bar actually stops on mouse_released")
end

-- Test 4: dragging an item straight out of an open panel onto the customer
-- serves them, without having to drop it back on the main grid first.
-- Regression test: mouse_released's serve/dismiss check used to only look
-- at self.grid.dragging, so an item mid-drag from a panel's inner grid was
-- never recognized as droppable-on-the-customer at all.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx4 = runner.setup(function() return KitchenScene.new() end)
    local scene4 = ctx4.sm.current

    runner.fast_forward_until(ctx4, function() return scene4.customer:arrived() end, 0)
    -- MVP customers request "cooked_meat" by default - no override needed
    -- here, unlike Test 1 (which tests raw_meat straight from the floor).
    assert(scene4.customer.requested_type == "cooked_meat",
        "sanity check: the default customer request should be cooked_meat")

    local microwave4
    for _, it in ipairs(scene4.grid:items()) do
        if it.type_id == "microwave" then microwave4 = it end
    end
    assert(microwave4, "on_enter should have placed a microwave")

    scene4.panel = ItemPanel.new(microwave4)

    -- Move a raw_meat item from the floor into the panel and cook it, the
    -- same way Test 2 already covers the transfer itself.
    local meat4
    for _, it in ipairs(scene4.grid:items()) do
        if it.type_id == "raw_meat" then meat4 = it end
    end
    assert(meat4, "on_enter should have placed raw_meat")

    local mx, my = scene4.grid:cell_to_world(meat4.cell_col, meat4.cell_row)
    scene4:mouse_pressed(mx + 1, my + 1)
    local px, py = microwave4.panel:cell_to_world(0, 0)
    scene4:mouse_moved(px + 1, py + 1)
    scene4:mouse_released(px + 1, py + 1)
    assert(meat4.grid == microwave4.panel, "sanity check: meat should now be in the panel")

    assert(microwave4:start_action("Cook"), "should be able to start cooking with meat in the panel")
    microwave4:update(3.5) -- past the 3.0s Cook duration

    -- Cooking replaces the raw_meat item with a brand new cooked_meat Item
    -- in the freed cell (see lua/game/item.lua's complete_action) rather
    -- than mutating meat4 in place, so look the result up fresh.
    local cooked4
    for _, it in ipairs(microwave4.panel:items()) do
        if it.type_id == "cooked_meat" then cooked4 = it end
    end
    assert(cooked4, "sanity check: panel should contain a cooked_meat item after cooking")

    local currency_before = scene4.day_state.currency
    local served_before   = scene4.day_state.customers_served

    -- Drag the now-cooked item straight from the panel onto the customer.
    local cmx, cmy = microwave4.panel:cell_to_world(cooked4.cell_col, cooked4.cell_row)
    scene4:mouse_pressed(cmx + 1, cmy + 1)
    assert(microwave4.panel.dragging == cooked4, "should be dragging the cooked item out of the panel")

    local cx4, cy4 = scene4.customer.x, scene4.customer.y
    scene4:mouse_moved(cx4, cy4)
    scene4:mouse_released(cx4, cy4)

    assert(microwave4.panel.dragging == nil, "dropping onto the customer should clear the panel grid's drag state")
    assert(scene4.day_state.currency == currency_before + 10,
        "currency should increase by 10 when serving directly from the panel")
    assert(scene4.day_state.customers_served == served_before + 1,
        "customers_served should increment when serving directly from the panel")

    local still_in_panel = false
    for _, it in ipairs(microwave4.panel:items()) do
        if it == cooked4 then still_in_panel = true end
    end
    assert(not still_in_panel, "the served item should be removed from the panel")

    print("PASS: kitchen_scene: dragging an item straight out of an open panel onto the customer serves them")
end

-- Test 5: customers enter from off-screen on the left and walk in moving
-- rightward, matching ../wip's convention (rather than entering from the
-- right and walking leftward).

do
    local ctx5 = runner.setup(function() return KitchenScene.new() end)
    local scene5 = ctx5.sm.current
    local c = scene5.customer

    assert(c.state == "walking_in", "sanity check: the first customer should be walking in on_enter")
    assert(c.exit_x < 0, "exit_x should be off-screen to the left (negative)")
    assert(c.x < c.target_x, "customer should start left of its target position")

    local prev_x = c.x
    c:update(1 / 60)
    assert(c.x > prev_x, "walking_in should move the customer rightward (increasing x), left-to-right entry")

    print("PASS: kitchen_scene: customers walk in left-to-right, entering from off-screen on the left")
end

print("ALL TESTS PASSED")
