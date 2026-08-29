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

print("ALL TESTS PASSED")
