-- tests/test_kitchen_scene.lua
-- Headless integration test: drives a full "drag raw_meat onto the waiting
-- customer" serve through KitchenScene's public mouse_pressed/moved/released
-- methods (not real love.mouse* events, which aren't available headless).
--
-- CustomerQueue now mixes exactly one random merchant slot into each day's
-- queue (see lua/game/customer_queue.lua), so the on-stage customer that
-- on_enter() happens to queue up first is no longer guaranteed to be a
-- food-order customer. Tests below that need a deterministic food-order
-- customer force one directly via Customer:show(order_cfg(...)) rather than
-- relying on whichever config CustomerQueue randomly drew first — see
-- order_cfg() just below. (The MVP default order config always requests
-- "cooked_meat", but on_enter() only pre-places "raw_meat" on the grid —
-- cooking it requires running the microwave's timed action first — so
-- order_cfg() is overridable per test, e.g. Test 1 below asks for
-- "raw_meat" directly to test the serve/consume mechanism itself without
-- also driving the cook timer; that pipeline is covered separately by
-- tests/test_item.lua / tests/test_item_panel.lua.)

local runner        = require("lua/headless/runner")
local KitchenScene   = require("game/scenes/kitchen_scene")

-- A deterministic food-order (kind == "order", i.e. kind omitted) customer
-- config, with any fields overridden. Mirrors customer_queue.lua's
-- make_default_cfg() shape.
local function order_cfg(overrides)
    local cfg = {
        name            = "Test Customer",
        requested_type  = "cooked_meat",
        messages        = { "Could I get some food?" },
        after_messages  = { "Thanks, that's delicious!" },
        walk_speed      = 80,
    }
    for k, v in pairs(overrides or {}) do
        cfg[k] = v
    end
    return cfg
end

local ctx = runner.setup(function(input, sm)
    return KitchenScene.new()
end)

local scene = ctx.sm.current

-- Force a known food-order config (requesting raw_meat, so the drag-a-raw-
-- meat-item-off-the-floor serve below doesn't need to drive the cook timer)
-- regardless of what CustomerQueue's random merchant-slot pick queued up
-- first for this day.
scene.customer:show(order_cfg({ requested_type = "raw_meat" }))

-- Tick (dt = 1.0 per step) until the first customer has walked in and is
-- waiting.
runner.fast_forward_until(ctx, function()
    return scene.customer:arrived()
end, 0)

assert(scene.customer:arrived(), "customer should be waiting after fast-forwarding")
assert(scene.customer.requested_type == "raw_meat", "sanity check: forced order config should request raw_meat")

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

    scene2.panels = { ItemPanel.new(microwave) }

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

    local panel3 = ItemPanel.new(microwave3)
    scene3.panels = { panel3 }
    local tb = panel3.title_bar

    scene3:mouse_pressed(tb.x + 10, tb.y + tb.h / 2)
    assert(panel3._dragging_panel == true, "pressing the title bar (via the scene) should start dragging the panel")

    scene3:mouse_moved(tb.x + 60, tb.y + 40)
    assert(panel3.grid_x ~= nil, "panel should have re-laid-out after the move")

    scene3:mouse_released(tb.x + 60, tb.y + 40)
    assert(panel3._dragging_panel == false,
        "releasing the mouse (via the scene) should stop the panel drag")

    -- It should really be stopped: further mouse_moved calls (as if the
    -- mouse kept moving after release) must not keep relocating the panel.
    local gx_after_release = panel3.grid_x
    scene3:mouse_moved(tb.x + 500, tb.y + 500)
    assert(panel3.grid_x == gx_after_release,
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

    -- Force a deterministic food-order customer (requesting the default
    -- "cooked_meat") regardless of whatever CustomerQueue's random
    -- merchant-slot pick queued up first for this day.
    scene4.customer:show(order_cfg())

    runner.fast_forward_until(ctx4, function() return scene4.customer:arrived() end, 0)
    assert(scene4.customer.requested_type == "cooked_meat",
        "sanity check: the forced order customer request should be cooked_meat")

    local microwave4
    for _, it in ipairs(scene4.grid:items()) do
        if it.type_id == "microwave" then microwave4 = it end
    end
    assert(microwave4, "on_enter should have placed a microwave")

    scene4.panels = { ItemPanel.new(microwave4) }

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

-- Test 6: full merchant visit - dropping an item on a merchant's body is a
-- no-op (no serve/dismiss, no panel), clicking their body opens their stock
-- panel, dragging a stock item out lands it on the main floor grid, and
-- clicking "Leave" ends the visit (customers_served increments, currency
-- does not - no payment system).

do
    local function merchant_cfg()
        return {
            kind       = "merchant",
            name       = "Merchant",
            messages   = { "Fresh stock, take a look!" },
            stock      = { "raw_meat", "cooked_meat" },
            walk_speed = 1000, -- fast: reach `waiting` almost immediately
        }
    end

    local ctx6 = runner.setup(function() return KitchenScene.new() end)
    local scene6 = ctx6.sm.current

    -- Force a deterministic merchant as the active customer, regardless of
    -- whatever CustomerQueue's random merchant-slot pick queued up first.
    scene6.customer:show(merchant_cfg())
    runner.fast_forward_until(ctx6, function() return scene6.customer:arrived() end, 0)
    assert(scene6.customer:arrived(), "merchant should be waiting after fast-forwarding")
    assert(scene6.customer.kind == "merchant", "sanity check: forced customer should be merchant-kind")

    -- Step 7 (checked early, before opening the panel): dropping a dragged
    -- item directly onto a merchant's body must do nothing special - no
    -- serve/dismiss, no panel opened, the item just falls through to normal
    -- grid-drop handling (and snaps back here since the drop point isn't a
    -- valid cell for it).
    local served_before_drop = scene6.day_state.customers_served

    local meat6
    for _, it in ipairs(scene6.grid:items()) do
        if it.type_id == "raw_meat" then meat6 = it end
    end
    assert(meat6, "on_enter should have placed raw_meat on the main grid")

    local mx6, my6 = scene6.grid:cell_to_world(meat6.cell_col, meat6.cell_row)
    scene6:mouse_pressed(mx6 + 1, my6 + 1)
    assert(scene6.grid.dragging == meat6, "mouse_pressed on the meat's cell should start dragging it")

    local ccx, ccy = scene6.customer.x, scene6.customer.y
    scene6:mouse_moved(ccx, ccy)
    scene6:mouse_released(ccx, ccy)

    assert(scene6.grid.dragging == nil, "drop should clear the grid's drag state either way")
    assert(#scene6.panels == 0, "dropping on a merchant's body should not open a panel")
    assert(scene6.day_state.customers_served == served_before_drop,
        "dropping an item on a merchant's body should not trigger serve/dismiss")
    assert(meat6.grid == scene6.grid, "the dropped item should fall through to normal grid-drop handling")

    -- Steps 1-3: clicking the merchant's body opens their stock panel.
    scene6:mouse_pressed(scene6.customer.x, scene6.customer.y)
    assert(#scene6.panels == 1, "clicking the merchant's body should open their stock panel")
    local merchant_panel6 = scene6.panels[1]
    assert(merchant_panel6.item == scene6.customer, "the panel should wrap the customer itself")

    -- Step 4: drag a stock item out of the merchant's panel onto the main
    -- floor grid, at a cell free per on_enter's starting layout (microwave
    -- occupies (0,0)-(1,1); raw_meat sits at (2,0),(3,0),(4,0); (5,3) is
    -- untouched).
    local stock_item
    for _, it in ipairs(scene6.customer.panel:items()) do
        stock_item = it
        break
    end
    assert(stock_item, "merchant's panel should contain stock items")

    local sx, sy = scene6.customer.panel:cell_to_world(stock_item.cell_col, stock_item.cell_row)
    scene6:mouse_pressed(sx + 1, sy + 1)
    assert(scene6.customer.panel.dragging == stock_item,
        "should be dragging the stock item out of the merchant's panel")

    local gx, gy = scene6.grid:cell_to_world(5, 3)
    scene6:mouse_moved(gx + 1, gy + 1)
    scene6:mouse_released(gx + 1, gy + 1)

    assert(scene6.customer.panel.dragging == nil, "drop should clear the merchant panel's drag state")
    assert(stock_item.grid == scene6.grid, "dragged stock item should now belong to the main grid")
    assert(stock_item.cell_col == 5 and stock_item.cell_row == 3,
        "dragged stock item should land at the dropped cell")

    local in_main_grid = false
    for _, it in ipairs(scene6.grid:items()) do
        if it == stock_item then in_main_grid = true end
    end
    assert(in_main_grid, "dragged stock item should be listed on the main grid")

    local still_in_panel = false
    for _, it in ipairs(scene6.customer.panel:items()) do
        if it == stock_item then still_in_panel = true end
    end
    assert(not still_in_panel, "dragged stock item should no longer be in the merchant's panel")

    -- Step 5: click the panel's "Leave" button.
    local served_before_leave   = scene6.day_state.customers_served
    local currency_before_leave = scene6.day_state.currency

    local leave = merchant_panel6.buttons["Leave"]
    assert(leave, "merchant panel should have a Leave button")
    scene6:mouse_pressed(leave.x + leave.w / 2, leave.y + leave.h / 2)

    assert(#scene6.panels == 0, "clicking Leave should close the panel")
    assert(scene6.customer.state == "walking_out", "clicking Leave should send the merchant into walking_out")
    assert(scene6.day_state.customers_served == served_before_leave + 1,
        "merchant leaving should still increment customers_served")
    assert(scene6.day_state.currency == currency_before_leave,
        "merchant leaving should not change currency (no payment system)")

    -- Step 6: fast-forward until the merchant fully walks off and (per
    -- KitchenScene:update's existing auto-advance) the next queued customer
    -- walks in and arrives - mirrors the pattern the Test 1 continuation
    -- above already uses for a served food customer walking off. (The
    -- merchant transitions walking_out -> idle -> immediately walking_in
    -- again for the next queued customer within a single tick, so polling
    -- for state == "idle" would never observe it; polling for the next
    -- arrival is the same robust signal the rest of this file already
    -- relies on.)
    runner.fast_forward_until(ctx6, function() return scene6.customer:arrived() end, 0)
    assert(scene6.customer:arrived(), "the next queued customer should walk in and become waiting once the merchant fully leaves")

    print("PASS: kitchen_scene: full merchant visit - drop-on-body is a no-op, panel opens, stock drags out, Leave ends the visit")
end

-- Test 7: the drop-preview shown while dragging an item out of an open
-- panel (e.g. a merchant's stock) onto the main floor grid must use the
-- MAIN GRID's coordinate system, not the panel's. Regression test:
-- ItemPanel:mouse_moved forwards to the panel's inner grid whenever it's
-- mid-drag, regardless of where the cursor actually is, so the panel grid
-- kept recomputing (and drawing) a preview using its own origin even while
-- the cursor was hovering over the main grid far away - the preview looked
-- "snapped" to the wrong grid's cell alignment instead of the main grid's.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx7 = runner.setup(function() return KitchenScene.new() end)
    local scene7 = ctx7.sm.current

    local microwave7
    for _, it in ipairs(scene7.grid:items()) do
        if it.type_id == "microwave" then microwave7 = it end
    end
    assert(microwave7, "on_enter should have placed a microwave")

    scene7.panels = { ItemPanel.new(microwave7) }

    -- Move a raw_meat item into the microwave's panel first (same pattern
    -- other tests in this file already use), so there's something in an
    -- open panel to drag back out.
    local meat7
    for _, it in ipairs(scene7.grid:items()) do
        if it.type_id == "raw_meat" then meat7 = it end
    end
    local px7, py7 = microwave7.panel:cell_to_world(0, 0)
    local mx7, my7 = scene7.grid:cell_to_world(meat7.cell_col, meat7.cell_row)
    scene7:mouse_pressed(mx7 + 1, my7 + 1)
    scene7:mouse_moved(px7 + 1, py7 + 1)
    scene7:mouse_released(px7 + 1, py7 + 1)
    assert(meat7.grid == microwave7.panel, "sanity check: meat should now be in the microwave's panel")

    -- Start dragging it back out of the panel...
    scene7:mouse_pressed(px7 + 1, py7 + 1)
    assert(microwave7.panel.dragging == meat7, "should be dragging the item out of the panel")

    -- ...and hover it over a cell on the MAIN grid, well outside the
    -- panel's own bounds.
    local target_col, target_row = 6, 4
    local gx7, gy7 = scene7.grid:cell_to_world(target_col, target_row)
    scene7:mouse_moved(gx7 + 1, gy7 + 1)

    -- The main grid should now show the preview, computed via ITS OWN
    -- world_to_cell - i.e. landing exactly on (target_col, target_row).
    assert(scene7.grid._preview_override_item == meat7,
        "main grid should have a preview override set for the dragged item")
    assert(scene7.grid._preview_override_col == target_col and scene7.grid._preview_override_row == target_row,
        "main grid's preview should snap to ITS OWN coordinate system: expected ("
            .. target_col .. "," .. target_row .. "), got ("
            .. tostring(scene7.grid._preview_override_col) .. "," .. tostring(scene7.grid._preview_override_row) .. ")")

    -- The panel's own grid must NOT still be showing a (wrong, stale)
    -- preview of its own while the cursor is over the main grid.
    assert(microwave7.panel.drag_preview_col == nil and microwave7.panel.drag_preview_row == nil,
        "the panel's own grid should not have a stale preview while the cursor is over the main grid")

    -- The item's sprite must keep following the cursor here too, not just
    -- while hovering the grid it was originally picked up from - the owner
    -- grid still gets a normal mouse_moved() call every time regardless of
    -- hover target, which is what drives Grid:_position_dragging_sprite.
    assert(meat7.sprite.x == (gx7 + 1) - meat7.sprite.width / 2
        and meat7.sprite.y == (gy7 + 1) - meat7.sprite.height / 2,
        "dragged item's sprite should stay centered on the cursor even while hovering a different grid")

    -- Move back over the panel's own grid: the override on the main grid
    -- should clear, and the panel grid should resume tracking normally.
    scene7:mouse_moved(px7 + 1, py7 + 1)
    assert(scene7.grid._preview_override_item == nil,
        "main grid's override should clear once the cursor moves back over the panel")
    assert(microwave7.panel.drag_preview_col == 0 and microwave7.panel.drag_preview_row == 0,
        "the panel grid should resume showing its own preview once the cursor is back over it")

    scene7:mouse_released(px7 + 1, py7 + 1)
    assert(scene7.grid._preview_override_item == nil and microwave7.panel._preview_override_item == nil,
        "both grids' preview overrides should be cleared once the drag ends")

    print("PASS: kitchen_scene: drop-preview for an item dragged out of a panel uses the grid it's actually hovering over")
end

-- Test 8: multiple panels can be open at once. Opening a second doesn't
-- close/replace the first; re-triggering an already-open panel's opener
-- doesn't duplicate it (brings it to front instead); clicking anywhere on
-- an open panel's backdrop brings it to front; closing one panel doesn't
-- affect another that's also open.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx8 = runner.setup(function() return KitchenScene.new() end)
    local scene8 = ctx8.sm.current

    scene8.customer:show({
        kind       = "merchant",
        name       = "Merchant",
        messages   = { "Fresh stock, take a look!" },
        stock      = { "raw_meat" },
        walk_speed = 1000,
    })
    runner.fast_forward_until(ctx8, function() return scene8.customer:arrived() end, 0)

    local microwave8
    for _, it in ipairs(scene8.grid:items()) do
        if it.type_id == "microwave" then microwave8 = it end
    end
    assert(microwave8, "on_enter should have placed a microwave")

    -- Open the merchant's panel first (nothing else open yet, so there's no
    -- risk of an already-open panel's backdrop accidentally covering the
    -- customer's clickable body and absorbing this click instead).
    scene8:mouse_pressed(scene8.customer.x, scene8.customer.y)
    assert(#scene8.panels == 1, "clicking the merchant should open their panel")
    local panelB = scene8.panels[1]
    assert(panelB.item == scene8.customer)

    -- Now double-click the microwave (on the main floor grid, well below
    -- the split line - never overlaps a panel, which always sits above it)
    -- to open a second, different panel alongside the first.
    local mx8, my8 = scene8.grid:cell_to_world(0, 0)
    scene8:mouse_pressed(mx8 + 1, my8 + 1)
    scene8:mouse_released(mx8 + 1, my8 + 1)
    scene8:mouse_pressed(mx8 + 1, my8 + 1)
    scene8:mouse_released(mx8 + 1, my8 + 1)
    assert(#scene8.panels == 2, "opening a second panel should not close the first")
    local panelA = scene8.panels[2]
    assert(panelA.item == microwave8)
    assert(scene8.panels[1] == panelB, "the merchant panel should still be open, now at the back")

    -- Re-double-clicking the microwave must not open a duplicate panel - it
    -- should bring the existing one to front instead. This click is still
    -- on the main grid, unaffected by either panel's screen position.
    scene8:mouse_pressed(mx8 + 1, my8 + 1)
    scene8:mouse_released(mx8 + 1, my8 + 1)
    scene8:mouse_pressed(mx8 + 1, my8 + 1)
    scene8:mouse_released(mx8 + 1, my8 + 1)
    assert(#scene8.panels == 2, "re-opening an already-open panel should not duplicate it")
    assert(scene8.panels[2] == panelA, "re-triggering the microwave panel should keep/bring it to front")
    assert(scene8.panels[1] == panelB)

    -- Move the merchant panel (currently at the back) somewhere guaranteed
    -- clear of the microwave panel's backdrop, so clicking it is
    -- unambiguous regardless of either panel's exact default size/position.
    panelB:_layout(20, 20)
    assert(panelB.bg.x + panelB.bg.w < panelA.bg.x or panelB.bg.y + panelB.bg.h < panelA.bg.y,
        "sanity check: repositioned merchant panel should not overlap the microwave panel's backdrop")

    scene8:mouse_pressed(panelB.title_bar.x + 5, panelB.title_bar.y + 5)
    assert(scene8.panels[2] == panelB, "clicking a panel's backdrop should bring it to front")
    assert(scene8.panels[1] == panelA, "the other panel should now be at the back")

    -- Closing one panel (the microwave's, via its X) must not affect the
    -- other, still-open one.
    scene8:mouse_pressed(panelA.close_button.x + panelA.close_button.w / 2,
        panelA.close_button.y + panelA.close_button.h / 2)
    assert(#scene8.panels == 1, "closing one panel should not close the other")
    assert(scene8.panels[1] == panelB, "the remaining panel should be the merchant's")

    print("PASS: kitchen_scene: multiple panels can be open at once, with dedup and bring-to-front")
end

-- Test 9: dragging an item directly between two open panels (not via the
-- main floor grid at all) works, generalizing the same cross-grid transfer
-- already covered for panel<->main-grid in Test 2.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx9 = runner.setup(function() return KitchenScene.new() end)
    local scene9 = ctx9.sm.current

    scene9.customer:show({
        kind       = "merchant",
        name       = "Merchant",
        messages   = { "Fresh stock, take a look!" },
        stock      = { "raw_meat" },
        walk_speed = 1000,
    })
    runner.fast_forward_until(ctx9, function() return scene9.customer:arrived() end, 0)

    local microwave9
    for _, it in ipairs(scene9.grid:items()) do
        if it.type_id == "microwave" then microwave9 = it end
    end
    assert(microwave9, "on_enter should have placed a microwave")

    local panelA9 = ItemPanel.new(microwave9)
    local panelB9 = ItemPanel.new(scene9.customer)
    -- Explicit, non-overlapping positions so every world position on screen
    -- belongs unambiguously to exactly one of the two panels' grids.
    panelA9:_layout(50, 50)
    panelB9:_layout(800, 50)
    scene9.panels = { panelA9, panelB9 }

    local stock9
    for _, it in ipairs(scene9.customer.panel:items()) do
        stock9 = it
        break
    end
    assert(stock9, "merchant's panel should contain stock")

    -- Drag the merchant's stock item straight into the microwave's panel.
    local sx9, sy9 = scene9.customer.panel:cell_to_world(stock9.cell_col, stock9.cell_row)
    scene9:mouse_pressed(sx9 + 1, sy9 + 1)
    assert(scene9.customer.panel.dragging == stock9, "should be dragging the stock item out of the merchant's panel")

    local tx9, ty9 = microwave9.panel:cell_to_world(0, 0)
    scene9:mouse_moved(tx9 + 1, ty9 + 1)
    scene9:mouse_released(tx9 + 1, ty9 + 1)

    assert(scene9.customer.panel.dragging == nil, "drop should clear the merchant panel's drag state")
    assert(microwave9.panel.dragging == nil, "the microwave panel should not be left mid-drag either")
    assert(stock9.grid == microwave9.panel, "item dragged between two open panels should land in the target panel")

    local still_in_merchant_panel = false
    for _, it in ipairs(scene9.customer.panel:items()) do
        if it == stock9 then still_in_merchant_panel = true end
    end
    assert(not still_in_merchant_panel, "item should no longer be in the merchant's panel")

    local in_microwave_panel = false
    for _, it in ipairs(microwave9.panel:items()) do
        if it == stock9 then in_microwave_panel = true end
    end
    assert(in_microwave_panel, "item should now be listed in the microwave's panel")

    print("PASS: kitchen_scene: dragging an item directly between two open panels transfers it")
end

-- Test 10: the Next Day button must not appear/be clickable until the
-- day's LAST customer has actually left (walked fully off and gone idle) -
-- not merely been served/dismissed. Regression test: DayState:day_complete()
-- flips true the instant the last serve/dismiss is recorded, while that
-- customer is still animating off-screen (talking_after, then walking_out).

do
    local ctx10 = runner.setup(function() return KitchenScene.new() end)
    local scene10 = ctx10.sm.current

    scene10.customer:show(order_cfg({ after_messages = { "Thanks!" } }))
    runner.fast_forward_until(ctx10, function() return scene10.customer:arrived() end, 0)

    -- Simulate being down to the day's last customer without actually
    -- driving two full prior visits: bump the served count directly, and
    -- exhaust the queue to match (on_enter already drew once for this
    -- customer; two more draws brings total draws to CUSTOMERS_PER_DAY, so
    -- has_next() is false and KitchenScene:update won't auto-spawn a
    -- replacement once this customer goes idle).
    scene10.day_state.customers_served = scene10.day_state.customers_total - 1
    scene10.queue:next()
    scene10.queue:next()
    assert(not scene10.queue:has_next(), "sanity check: queue should be fully drained")

    scene10.customer:serve() -- enters talking_after (after_messages present)
    scene10.day_state:record_serve()

    assert(scene10.day_state:day_complete(), "sanity check: day should now be complete by count")
    assert(scene10.customer:active(), "sanity check: the served customer should still be on stage (talking_after)")
    assert(not scene10:_next_day_ready(),
        "Next Day should not be ready while the day's last customer is still talking_after")

    -- Advance through their thank-you message into walking_out.
    scene10.customer:skip_reveal()
    scene10.customer:advance_after()
    assert(scene10.customer.state == "walking_out", "sanity check: should now be walking out")
    assert(not scene10:_next_day_ready(),
        "Next Day should not be ready while the day's last customer is still walking_out")

    -- Let them actually leave (no next customer queued, so this reaches
    -- idle and stays idle).
    runner.fast_forward_until(ctx10, function() return not scene10.customer:active() end, 0)
    assert(scene10:_next_day_ready(), "Next Day should be ready once the day's last customer has fully left")

    -- The click handler itself must honor the same gating, not just the
    -- drawn button's visibility. Replicates kitchen_scene.lua's private
    -- NEXT_DAY_BTN rect (not exported) since it's not exposed on the scene.
    local config = require("lua/game/config")
    local next_day_btn = { x = config.SCREEN_W - 170, y = config.SPLIT_Y - 56, w = 150, h = 40 }
    local day_before = scene10.day_state.day
    scene10:mouse_pressed(next_day_btn.x + 10, next_day_btn.y + 10)
    assert(scene10.day_state.day == day_before + 1, "clicking Next Day once ready should advance the day")

    print("PASS: kitchen_scene: Next Day is not ready until the day's last customer has actually left")
end

-- Test 11: dropping the WRONG item on a customer must actually be rejected
-- (not served), and now shows a clear rejection message before they walk
-- out - not just silently leave indistinguishably from a successful serve.

do
    local ctx11 = runner.setup(function() return KitchenScene.new() end)
    local scene11 = ctx11.sm.current

    scene11.customer:show(order_cfg()) -- default request: cooked_meat
    runner.fast_forward_until(ctx11, function() return scene11.customer:arrived() end, 0)
    assert(scene11.customer.requested_type == "cooked_meat", "sanity check: forced customer wants cooked_meat")

    local meat11
    for _, it in ipairs(scene11.grid:items()) do
        if it.type_id == "raw_meat" then meat11 = it end
    end
    assert(meat11, "on_enter should have placed raw_meat")

    local currency_before = scene11.day_state.currency
    local served_before   = scene11.day_state.customers_served

    local mx11, my11 = scene11.grid:cell_to_world(meat11.cell_col, meat11.cell_row)
    scene11:mouse_pressed(mx11 + 1, my11 + 1)
    scene11:mouse_moved(scene11.customer.x, scene11.customer.y)
    scene11:mouse_released(scene11.customer.x, scene11.customer.y)

    -- Rejected, not served: no currency, but the visit still counts toward
    -- the day (matches the existing dismiss-on-mismatch behavior).
    assert(scene11.day_state.currency == currency_before,
        "dropping the wrong item must not award currency")
    assert(scene11.day_state.customers_served == served_before + 1,
        "dropping the wrong item should still count as this customer's visit")
    assert(scene11.customer.dismissed, "customer should be marked dismissed")

    -- And now, unlike before, this must be visibly a rejection: a message
    -- showing via talking_after, not a silent walking_out.
    assert(scene11.customer.state == "talking_after",
        "a wrong-item drop should show a rejection message (talking_after), got " .. scene11.customer.state)
    assert(scene11.customer:bubble_visible(), "the rejection message's bubble should be visible")
    assert(#scene11.customer._full_text > 0, "the rejection message should be non-empty")

    -- Click through it like any other dialogue, same as a served customer.
    scene11:mouse_pressed(scene11.customer.x, scene11.customer.y) -- completes the reveal
    assert(scene11.customer.state == "talking_after", "first click should only complete the reveal")
    scene11:mouse_pressed(scene11.customer.x, scene11.customer.y) -- advances past it
    assert(scene11.customer.state == "walking_out", "second click should send the customer into walking_out")

    print("PASS: kitchen_scene: dropping the wrong item is rejected with a visible message, not silently accepted")
end

-- Test 12: the microwave itself still occupies a 2x2 area on the main
-- floor grid, but its own internal cooking panel is a single cell (not
-- 2x1) - the item's footprint and its inner inventory size are unrelated.

do
    local Item = require("lua/game/item")

    local ctx12 = runner.setup(function() return KitchenScene.new() end)
    local scene12 = ctx12.sm.current

    local microwave12
    for _, it in ipairs(scene12.grid:items()) do
        if it.type_id == "microwave" then microwave12 = it end
    end
    assert(microwave12, "on_enter should have placed a microwave")

    assert(#microwave12:footprint() == 4, "microwave footprint should be 2x2 (4 cells), got " .. #microwave12:footprint())
    assert(microwave12.cell_col == 0 and microwave12.cell_row == 0, "microwave should start at (0,0)")

    -- (1,0)/(0,1)/(1,1) are still part of the microwave's 2x2 footprint on
    -- the main grid, so nothing else should be placeable there.
    local probe = Item.new("raw_meat")
    assert(not scene12.grid:can_place(probe, 1, 0), "(1,0) should still be occupied by the microwave's footprint")

    -- Its own cooking panel, though, is a single cell.
    assert(microwave12.panel.cols == 1 and microwave12.panel.rows == 1,
        "microwave's internal panel should be 1x1, got " .. microwave12.panel.cols .. "x" .. microwave12.panel.rows)

    print("PASS: kitchen_scene: the microwave is 2x2 on the floor grid but has a 1x1 internal panel")
end

print("ALL TESTS PASSED")
