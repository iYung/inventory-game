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

print("ALL TESTS PASSED")
