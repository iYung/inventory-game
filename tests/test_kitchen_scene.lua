-- tests/test_kitchen_scene.lua
-- Headless integration test: drives a full "click an order customer to open
-- their order panel, drag the requested item into it, click Serve/Skip" flow
-- through KitchenScene's public mouse_pressed/moved/released methods (not
-- real love.mouse* events, which aren't available headless).
--
-- CustomerQueue now mixes exactly one random merchant slot into each day's
-- queue (see lua/game/customer_queue.lua), so the on-stage customer that
-- on_enter() happens to queue up first is no longer guaranteed to be a
-- food-order customer. Tests below that need a deterministic food-order
-- customer force one directly via Customer:show(order_cfg(...)) rather than
-- relying on whichever config CustomerQueue randomly drew first — see
-- order_cfg() just below. (The default order config now requests the
-- "Protein" tag, which only "cooked_meat" carries — raw items carry no tags
-- at all and can never satisfy any tag request, by design; see
-- lua/game/data/item_defs.lua. on_enter() only pre-places raw ingredients
-- on the grid, so a test that wants a Protein-tagged item without driving
-- the microwave's cook timer places a fresh cooked_meat Item directly on
-- the grid instead — see the first test below. The cook-it-yourself
-- pipeline through this scene is covered by Test 4 further down; the
-- Item/ItemPanel action-timer mechanism itself is covered separately by
-- tests/test_item.lua / tests/test_item_panel.lua.)

local runner        = require("lua/headless/runner")
local KitchenScene   = require("game/scenes/kitchen_scene")
local Item           = require("lua/game/item")

-- A deterministic food-order (kind == "order", i.e. kind omitted) customer
-- config, with any fields overridden. Mirrors customer_queue.lua's
-- make_default_cfg() shape. Defaults to requesting the "Protein" tag (the
-- tag "cooked_meat" carries) since that's the tag this file's tests most
-- often want; individual tests override requested_tag as needed.
local function order_cfg(overrides)
    local cfg = {
        name            = "Test Customer",
        requested_tag   = "Protein",
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

-- Force a known food-order config (default order_cfg() now requests the
-- "Protein" tag) regardless of what CustomerQueue's random merchant-slot
-- pick queued up first for this day.
scene.customer:show(order_cfg())

-- Tick (dt = 1.0 per step) until the first customer has walked in and is
-- waiting.
runner.fast_forward_until(ctx, function()
    return scene.customer:arrived()
end, 0)

assert(scene.customer:arrived(), "customer should be waiting after fast-forwarding")
assert(scene.customer.requested_tag == "Protein", "sanity check: forced order config should request Protein")

-- Place a fresh cooked_meat item (tagged "Protein", see item_defs.lua)
-- directly on a free grid cell, rather than driving the microwave's cook
-- timer here - that pipeline is exercised end-to-end through this scene by
-- Test 4 below, and the Item-level timer mechanism itself is covered by
-- tests/test_item.lua / tests/test_item_panel.lua.
local cooked = Item.new("cooked_meat")
assert(scene.grid:can_place(cooked, 5, 0), "(5,0) should be free for the test's cooked_meat item")
scene.grid:place(cooked, 5, 0)

local mx, my = scene.grid:cell_to_world(cooked.cell_col, cooked.cell_row)
mx, my = mx + 1, my + 1 -- a point safely inside the item's cell

local currency_before = scene.day_state.currency
local served_before   = scene.day_state.customers_served

-- Click through the greeting to open the order panel: fast_forward_until
-- above ticks with dt = 1.0, which is enough for the single short greeting
-- message's typewriter reveal to already be fully played out by the time
-- arrived() flips true. One click advances done_talking to true AND
-- immediately opens the order panel in the same event (no dead "standing
-- there" click between dialogue and panel). customer.x/y is the sprite's
-- center point, so it's guaranteed to land inside the customer's clickable body.
local cx, cy = scene.customer.x, scene.customer.y
assert(not scene.customer.done_talking, "sanity check: done_talking should still be false right after arriving")

scene:mouse_pressed(cx, cy)
assert(scene.customer.done_talking, "clicking through the (already fully revealed) greeting should flip done_talking true")
assert(#scene.panels == 1, "the same click that finishes the greeting should immediately open the order panel")
local order_panel = scene.panels[1]
assert(order_panel.item == scene.customer, "the order panel should wrap the customer itself")

-- Drag the cooked_meat item into the order panel's grid, the same way Test 4
-- further down drags an item into the microwave's panel.
scene:mouse_pressed(mx, my)
assert(scene.grid.dragging == cooked, "mouse_pressed on the cooked_meat's cell should start dragging it")

local px, py = order_panel.item.panel:cell_to_world(0, 0)
scene:mouse_moved(px + 1, py + 1)
scene:mouse_released(px + 1, py + 1)

assert(scene.grid.dragging == nil, "dropping into the order panel should clear the main grid's drag state")
assert(cooked.grid == order_panel.item.panel, "the cooked_meat item should now be in the order panel's grid")

-- Click the panel's Serve button.
assert(order_panel:_serve_enabled(),
    "Serve should be enabled with exactly one matching-tag item in the panel")
local serve = order_panel.buttons["Serve"]
assert(serve, "order panel should have a Serve button")
scene:mouse_pressed(serve.x + serve.w / 2, serve.y + serve.h / 2)

assert(#scene.panels == 0, "clicking Serve should close the order panel")
assert(scene.day_state.currency == currency_before + 10,
    "currency should increase by 10 on a matching-tag serve, got " .. tostring(scene.day_state.currency))
assert(scene.day_state.customers_served == served_before + 1,
    "customers_served should increment by 1")

local still_on_grid = false
for _, it in ipairs(scene.grid:items()) do
    if it == cooked then still_on_grid = true end
end
assert(not still_on_grid, "the served cooked_meat item should be removed from the grid")

local still_in_panel = false
for _, it in ipairs(order_panel.item.panel:items()) do
    if it == cooked then still_in_panel = true end
end
assert(not still_in_panel, "the served cooked_meat item should be removed from the order panel's grid")
assert(cooked.grid == nil, "the served item's grid reference should be cleared")

print("PASS: kitchen_scene: dragging an item carrying the requested tag into the order panel and clicking Serve serves the customer and consumes the item")

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

-- Test 4: dragging an item straight out of an open panel into the order
-- panel's own grid, then clicking Serve, serves the customer - without
-- having to drop it back on the main grid first. Rewritten (Task 8): the
-- old gesture this test used to exercise (dropping a dragged item directly
-- on the customer's sprite body) was deleted from kitchen_scene.lua along
-- with the drag-onto-customer serve path - servin now goes exclusively
-- through the order panel's Serve button (see Test 1's now-working
-- click-to-open + Serve pattern, and Test 9's cross-panel drag mechanics,
-- both reused here).

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx4 = runner.setup(function() return KitchenScene.new() end)
    local scene4 = ctx4.sm.current

    -- Force a deterministic food-order customer (requesting the default
    -- "Protein" tag, which only cooked_meat carries) regardless of whatever
    -- CustomerQueue's random merchant-slot pick queued up first for this
    -- day.
    scene4.customer:show(order_cfg())

    runner.fast_forward_until(ctx4, function() return scene4.customer:arrived() end, 0)
    assert(scene4.customer.requested_tag == "Protein",
        "sanity check: the forced order customer request should be Protein")

    local microwave4
    for _, it in ipairs(scene4.grid:items()) do
        if it.type_id == "microwave" then microwave4 = it end
    end
    assert(microwave4, "on_enter should have placed a microwave")

    scene4.panels = { ItemPanel.new(microwave4) }
    local microwave_panel4 = scene4.panels[1]

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

    -- Click through the greeting to open the order panel: one click finishes
    -- the greeting and immediately opens the panel. customer.x/y is outside
    -- the microwave panel's default bounds (see Test 9's layout reasoning
    -- below), so this click can't be swallowed by it.
    local cx4, cy4 = scene4.customer.x, scene4.customer.y
    scene4:mouse_pressed(cx4, cy4)
    assert(scene4.customer.done_talking, "sanity check: done_talking should be true after one click")
    assert(#scene4.panels == 2, "the same click that finishes the greeting should open the order panel alongside the microwave's")
    local order_panel4 = scene4.panels[2]
    assert(order_panel4.item == scene4.customer, "the order panel should wrap the customer itself")

    -- The order panel's default (cascaded) position fully overlaps the
    -- microwave panel's default position, so explicitly reposition both to
    -- non-overlapping spots first - the same defensive pattern Test 9 uses
    -- for its two open panels - so every subsequent click below
    -- unambiguously targets the panel it's meant to.
    microwave_panel4:_layout(50, 50)
    order_panel4:_layout(800, 50)

    -- Drag the now-cooked item directly from the microwave's open panel into
    -- the order panel's own grid (cross-panel drag, same mechanics Test 9
    -- already covers between two open panels).
    local cmx, cmy = microwave4.panel:cell_to_world(cooked4.cell_col, cooked4.cell_row)
    scene4:mouse_pressed(cmx + 1, cmy + 1)
    assert(microwave4.panel.dragging == cooked4, "should be dragging the cooked item out of the microwave's panel")

    local opx, opy = order_panel4.item.panel:cell_to_world(0, 0)
    scene4:mouse_moved(opx + 1, opy + 1)
    scene4:mouse_released(opx + 1, opy + 1)

    assert(microwave4.panel.dragging == nil, "dropping into the order panel should clear the microwave panel's drag state")
    assert(cooked4.grid == order_panel4.item.panel, "the cooked item should now be in the order panel's grid")

    -- Click the order panel's Serve button.
    assert(order_panel4:_serve_enabled(),
        "Serve should be enabled with exactly one matching-tag item in the order panel")
    local serve4 = order_panel4.buttons["Serve"]
    assert(serve4, "order panel should have a Serve button")
    scene4:mouse_pressed(serve4.x + serve4.w / 2, serve4.y + serve4.h / 2)

    assert(#scene4.panels == 1, "clicking Serve should close the order panel, leaving the microwave's open")
    assert(scene4.day_state.currency == currency_before + 10,
        "currency should increase by 10 when serving directly from the panel")
    assert(scene4.day_state.customers_served == served_before + 1,
        "customers_served should increment when serving directly from the panel")

    local still_in_panel = false
    for _, it in ipairs(microwave4.panel:items()) do
        if it == cooked4 then still_in_panel = true end
    end
    assert(not still_in_panel, "the served item should be removed from the microwave's panel")

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

-- Test 11: dropping the WRONG item in the order panel must actually be
-- rejected (Serve stays disabled; Skip must be used instead), and shows a
-- clear rejection message before the customer walks out - not just silently
-- leave indistinguishably from a successful serve.

do
    local ctx11 = runner.setup(function() return KitchenScene.new() end)
    local scene11 = ctx11.sm.current

    scene11.customer:show(order_cfg()) -- default request: Protein
    runner.fast_forward_until(ctx11, function() return scene11.customer:arrived() end, 0)
    assert(scene11.customer.requested_tag == "Protein", "sanity check: forced customer wants Protein")

    local meat11
    for _, it in ipairs(scene11.grid:items()) do
        if it.type_id == "raw_meat" then meat11 = it end
    end
    assert(meat11, "on_enter should have placed raw_meat")

    local currency_before = scene11.day_state.currency
    local served_before   = scene11.day_state.customers_served

    -- Click through the greeting to open the order panel: one click finishes
    -- the greeting and immediately opens the panel. The short greeting
    -- message's typewriter reveal is already fully played out by the time
    -- fast_forward_until (dt = 1.0 per step) observes arrived().
    local cx11, cy11 = scene11.customer.x, scene11.customer.y
    scene11:mouse_pressed(cx11, cy11)
    assert(scene11.customer.done_talking, "sanity check: done_talking should be true after one click")
    assert(#scene11.panels == 1, "the same click that finishes the greeting should immediately open the order panel")
    local order_panel11 = scene11.panels[1]
    assert(order_panel11.item == scene11.customer, "the order panel should wrap the customer itself")

    -- Drag the wrong item (raw_meat, untagged) into the order panel's grid.
    local mx11, my11 = scene11.grid:cell_to_world(meat11.cell_col, meat11.cell_row)
    scene11:mouse_pressed(mx11 + 1, my11 + 1)
    assert(scene11.grid.dragging == meat11, "mouse_pressed on the raw_meat's cell should start dragging it")

    local px11, py11 = order_panel11.item.panel:cell_to_world(0, 0)
    scene11:mouse_moved(px11 + 1, py11 + 1)
    scene11:mouse_released(px11 + 1, py11 + 1)

    assert(scene11.grid.dragging == nil, "dropping into the order panel should clear the main grid's drag state")
    assert(meat11.grid == order_panel11.item.panel, "the raw_meat item should now be in the order panel's grid")

    -- Serve must be disabled: raw_meat carries no tags at all, so it can
    -- never satisfy the requested "Protein" tag.
    assert(not order_panel11:_serve_enabled(),
        "Serve should be disabled with a non-matching item in the panel")

    -- Clicking the (disabled) Serve button must be a no-op: panel stays
    -- open, nothing is awarded.
    local serve11 = order_panel11.buttons["Serve"]
    assert(serve11, "order panel should have a Serve button")
    scene11:mouse_pressed(serve11.x + serve11.w / 2, serve11.y + serve11.h / 2)
    assert(#scene11.panels == 1, "clicking a disabled Serve button should be a no-op, panel stays open")
    assert(scene11.day_state.currency == currency_before,
        "a no-op click on a disabled Serve button must not award currency")

    -- Click Skip instead.
    local skip11 = order_panel11.buttons["Skip"]
    assert(skip11, "order panel should have a Skip button")
    scene11:mouse_pressed(skip11.x + skip11.w / 2, skip11.y + skip11.h / 2)

    assert(#scene11.panels == 0, "clicking Skip should close the order panel")
    assert(meat11.grid == scene11.grid, "the skipped item should be returned to the main floor grid")

    local back_on_grid = false
    for _, it in ipairs(scene11.grid:items()) do
        if it == meat11 then back_on_grid = true end
    end
    assert(back_on_grid, "the skipped item should be listed on the main floor grid")

    -- Rejected, not served: no currency, but the visit still counts toward
    -- the day (matches the existing dismiss-on-mismatch behavior).
    assert(scene11.day_state.currency == currency_before,
        "skipping the wrong item must not award currency")
    assert(scene11.day_state.customers_served == served_before + 1,
        "skipping should still count as this customer's visit")
    assert(scene11.customer.dismissed, "customer should be marked dismissed")

    -- And now, unlike before, this must be visibly a rejection: a message
    -- showing via talking_after, not a silent walking_out.
    assert(scene11.customer.state == "talking_after",
        "skipping should show a rejection message (talking_after), got " .. scene11.customer.state)
    assert(scene11.customer:bubble_visible(), "the rejection message's bubble should be visible")
    assert(#scene11.customer._full_text > 0, "the rejection message should be non-empty")

    -- Click through it like any other dialogue, same as a served customer.
    scene11:mouse_pressed(cx11, cy11) -- completes the reveal
    assert(scene11.customer.state == "talking_after", "first click should only complete the reveal")
    scene11:mouse_pressed(cx11, cy11) -- advances past it
    assert(scene11.customer.state == "walking_out", "second click should send the customer into walking_out")

    print("PASS: kitchen_scene: dragging the wrong item into the order panel keeps Serve disabled; Skip rejects with a visible message, not silently")
end

-- Test 12: the microwave itself still occupies a 2x2 area on the main
-- floor grid, but its own internal cooking panel is a separate 2x1 shape
-- (grown from 1x1 to fit the pot's 2x1 footprint) - the item's
-- footprint and its inner inventory size are unrelated.

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

    -- Its own cooking panel, though, is 2x1 (grown from 1x1 so the pot's
    -- 2x1 footprint fits inside it).
    assert(microwave12.panel.cols == 2 and microwave12.panel.rows == 1,
        "microwave's internal panel should be 2x1, got " .. microwave12.panel.cols .. "x" .. microwave12.panel.rows)

    print("PASS: kitchen_scene: the microwave is 2x2 on the floor grid but has a 2x1 internal panel")
end

-- Test 13: right-click is a one-click shortcut for double-click-to-open-
-- panel, on the same targets; it's a no-op on plain items and doesn't
-- reach through an already-open panel's backdrop.

do
    local ctx13 = runner.setup(function() return KitchenScene.new() end)
    local scene13 = ctx13.sm.current

    local microwave13, meat13
    for _, it in ipairs(scene13.grid:items()) do
        if it.type_id == "microwave" then microwave13 = it end
        if it.type_id == "raw_meat" and not meat13 then meat13 = it end
    end
    assert(microwave13 and meat13, "on_enter should have placed a microwave and raw_meat")

    -- Right-clicking a plain item (no has_panel) does nothing.
    local mx13, my13 = scene13.grid:cell_to_world(meat13.cell_col, meat13.cell_row)
    scene13:mouse_right_pressed(mx13 + 1, my13 + 1)
    assert(#scene13.panels == 0, "right-clicking a plain item should not open anything")

    -- Right-clicking the microwave opens its panel in one click.
    local wx13, wy13 = scene13.grid:cell_to_world(0, 0)
    scene13:mouse_right_pressed(wx13 + 1, wy13 + 1)
    assert(#scene13.panels == 1, "right-clicking a has_panel item should open its panel")
    local panel13 = scene13.panels[1]
    assert(panel13.item == microwave13)

    -- Right-clicking it again brings it to front rather than duplicating -
    -- open a second (merchant) panel first so there's something to reorder.
    scene13.customer:show({
        kind = "merchant", name = "Merchant",
        messages = { "Fresh stock, take a look!" },
        stock = { "raw_meat" }, walk_speed = 1000,
    })
    runner.fast_forward_until(ctx13, function() return scene13.customer:arrived() end, 0)
    scene13:mouse_pressed(scene13.customer.x, scene13.customer.y)
    assert(#scene13.panels == 2, "sanity check: merchant panel should now also be open")
    assert(scene13.panels[2].item == scene13.customer, "sanity check: merchant panel should be on top")

    scene13:mouse_right_pressed(wx13 + 1, wy13 + 1)
    assert(#scene13.panels == 2, "right-clicking an already-open panel's item should not duplicate it")
    assert(scene13.panels[2] == panel13, "right-click should bring the microwave panel back to front")

    -- Right-clicking on top of an open panel's backdrop does nothing (must
    -- not reach through to a main-grid item underneath).
    local panels_before = #scene13.panels
    scene13:mouse_right_pressed(panel13.title_bar.x + 5, panel13.title_bar.y + 5)
    assert(#scene13.panels == panels_before, "right-clicking a panel's own backdrop should be a no-op")

    print("PASS: kitchen_scene: right-click opens/focuses a has_panel item's panel like double-click does")
end

-- Test 14: dragging an item directly onto the microwave's own floor cells
-- inserts it into the microwave's panel (first-fit) if there's room,
-- without needing to open the panel first; once both of its 2 panel cells
-- are full, a further drop snaps back instead of being lost.

do
    local ctx14 = runner.setup(function() return KitchenScene.new() end)
    local scene14 = ctx14.sm.current

    local microwave14, meatA, meatB, meatC
    for _, it in ipairs(scene14.grid:items()) do
        if it.type_id == "microwave" then microwave14 = it end
        if it.type_id == "raw_meat" then
            if not meatA then meatA = it
            elseif not meatB then meatB = it
            elseif not meatC then meatC = it end
        end
    end
    assert(microwave14 and meatA and meatB and meatC,
        "on_enter should have placed a microwave and at least three raw_meat")

    local wx14, wy14 = scene14.grid:cell_to_world(0, 0) -- microwave's top-left cell

    -- Drag the first raw_meat onto the microwave's own cell (not via its
    -- panel - it isn't even open).
    local mxA, myA = scene14.grid:cell_to_world(meatA.cell_col, meatA.cell_row)
    scene14:mouse_pressed(mxA + 1, myA + 1)
    assert(scene14.grid.dragging == meatA)

    scene14:mouse_moved(wx14 + 1, wy14 + 1)
    scene14:mouse_released(wx14 + 1, wy14 + 1)

    assert(scene14.grid.dragging == nil, "drop should clear the main grid's drag state")
    assert(#scene14.panels == 0, "dropping onto the microwave should not itself open its panel")
    assert(meatA.grid == microwave14.panel, "item dropped on the microwave should land in its panel")

    local still_on_main_grid_A = false
    for _, it in ipairs(scene14.grid:items()) do
        if it == meatA then still_on_main_grid_A = true end
    end
    assert(not still_on_main_grid_A, "the inserted item should be gone from the main grid")

    -- The microwave's panel is 2 cells wide - a second item dropped on it
    -- the same way still has room and should also land in the panel.
    local mxB, myB = scene14.grid:cell_to_world(meatB.cell_col, meatB.cell_row)
    scene14:mouse_pressed(mxB + 1, myB + 1)
    scene14:mouse_moved(wx14 + 1, wy14 + 1)
    scene14:mouse_released(wx14 + 1, wy14 + 1)

    assert(meatB.grid == microwave14.panel,
        "a second item dropped on the microwave should also land in its 2-cell panel")

    local still_on_main_grid_B = false
    for _, it in ipairs(scene14.grid:items()) do
        if it == meatB then still_on_main_grid_B = true end
    end
    assert(not still_on_main_grid_B, "the second inserted item should be gone from the main grid")

    -- Both panel cells are now full - a third item dropped the same way
    -- must not be lost; it should snap back to its original cell on the
    -- main grid instead.
    local mxC, myC = scene14.grid:cell_to_world(meatC.cell_col, meatC.cell_row)
    local orig_col, orig_row = meatC.cell_col, meatC.cell_row
    scene14:mouse_pressed(mxC + 1, myC + 1)
    scene14:mouse_moved(wx14 + 1, wy14 + 1)
    scene14:mouse_released(wx14 + 1, wy14 + 1)

    assert(meatC.grid == scene14.grid, "with no room left in the panel, the item should snap back to the main grid")
    assert(meatC.cell_col == orig_col and meatC.cell_row == orig_row,
        "the snapped-back item should return to exactly its original cell")

    print("PASS: kitchen_scene: dragging items onto the microwave fills its 2-cell panel, then snaps back once full")
end

-- Test 15: the broccoli/Cook/steamed_broccoli pipeline works end-to-end
-- through this scene too, mirroring Test 4's meat/Cook/cooked_meat pipeline
-- but for the "Healthy" tag - proves the has_tag match-check isn't
-- special-cased to Protein/cooked_meat, and that the single "Cook" button
-- auto-matches broccoli's recipe just like it does raw meat's.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx15 = runner.setup(function() return KitchenScene.new() end)
    local scene15 = ctx15.sm.current

    -- Force a deterministic food-order customer requesting "Healthy" (the
    -- tag only steamed_broccoli carries) regardless of whatever
    -- CustomerQueue's random merchant-slot pick queued up first for this
    -- day.
    scene15.customer:show(order_cfg({
        requested_tag = "Healthy",
        messages      = { "Could I get something healthy?" },
    }))
    runner.fast_forward_until(ctx15, function() return scene15.customer:arrived() end, 0)
    assert(scene15.customer.requested_tag == "Healthy",
        "sanity check: the forced order customer request should be Healthy")

    local microwave15
    for _, it in ipairs(scene15.grid:items()) do
        if it.type_id == "microwave" then microwave15 = it end
    end
    assert(microwave15, "on_enter should have placed a microwave")

    scene15.panels = { ItemPanel.new(microwave15) }
    local microwave_panel15 = scene15.panels[1]

    -- Move a raw broccoli item from the floor into the panel and steam it,
    -- the same way Test 2/Test 4 already cover the transfer itself.
    local broccoli15
    for _, it in ipairs(scene15.grid:items()) do
        if it.type_id == "broccoli" then broccoli15 = it end
    end
    assert(broccoli15, "on_enter should have placed raw broccoli")

    local bx, by = scene15.grid:cell_to_world(broccoli15.cell_col, broccoli15.cell_row)
    scene15:mouse_pressed(bx + 1, by + 1)
    local px, py = microwave15.panel:cell_to_world(0, 0)
    scene15:mouse_moved(px + 1, py + 1)
    scene15:mouse_released(px + 1, py + 1)
    assert(broccoli15.grid == microwave15.panel, "sanity check: broccoli should now be in the panel")

    assert(microwave15:start_action("Cook"), "should be able to start cooking with broccoli in the panel")
    microwave15:update(3.5) -- past the 3.0s duration

    -- Cooking replaces the broccoli item with a brand new steamed_broccoli
    -- Item in the freed cell (see lua/game/item.lua's complete_action)
    -- rather than mutating broccoli15 in place, so look the result up fresh.
    local steamed15
    for _, it in ipairs(microwave15.panel:items()) do
        if it.type_id == "steamed_broccoli" then steamed15 = it end
    end
    assert(steamed15, "sanity check: panel should contain a steamed_broccoli item after steaming")

    local currency_before = scene15.day_state.currency
    local served_before   = scene15.day_state.customers_served

    -- Click through the greeting to open the order panel: one click finishes
    -- the greeting and immediately opens the panel (same behaviour as Test 1/Test 4).
    local cx15, cy15 = scene15.customer.x, scene15.customer.y
    scene15:mouse_pressed(cx15, cy15)
    assert(scene15.customer.done_talking, "sanity check: done_talking should be true after one click")
    assert(#scene15.panels == 2, "the same click that finishes the greeting should open the order panel alongside the microwave's")
    local order_panel15 = scene15.panels[2]
    assert(order_panel15.item == scene15.customer, "the order panel should wrap the customer itself")

    -- Reposition both panels to explicit, non-overlapping spots (same
    -- defensive pattern Test 4/Test 9 use) since the order panel's default
    -- cascaded position fully overlaps the microwave panel's default one.
    microwave_panel15:_layout(50, 50)
    order_panel15:_layout(800, 50)

    -- Drag the now-steamed item directly from the microwave's open panel
    -- into the order panel's own grid (cross-panel drag, same mechanics
    -- Test 9 already covers between two open panels).
    local smx, smy = microwave15.panel:cell_to_world(steamed15.cell_col, steamed15.cell_row)
    scene15:mouse_pressed(smx + 1, smy + 1)
    assert(microwave15.panel.dragging == steamed15, "should be dragging the steamed item out of the microwave's panel")

    local opx15, opy15 = order_panel15.item.panel:cell_to_world(0, 0)
    scene15:mouse_moved(opx15 + 1, opy15 + 1)
    scene15:mouse_released(opx15 + 1, opy15 + 1)

    assert(microwave15.panel.dragging == nil, "dropping into the order panel should clear the microwave panel's drag state")
    assert(steamed15.grid == order_panel15.item.panel, "the steamed item should now be in the order panel's grid")

    -- Click the order panel's Serve button.
    assert(order_panel15:_serve_enabled(),
        "Serve should be enabled with exactly one matching-tag item in the order panel")
    local serve15 = order_panel15.buttons["Serve"]
    assert(serve15, "order panel should have a Serve button")
    scene15:mouse_pressed(serve15.x + serve15.w / 2, serve15.y + serve15.h / 2)

    assert(#scene15.panels == 1, "clicking Serve should close the order panel, leaving the microwave's open")
    assert(scene15.day_state.currency == currency_before + 10,
        "currency should increase by 10 when serving a Healthy-tagged item for a Healthy request")
    assert(scene15.day_state.customers_served == served_before + 1,
        "customers_served should increment when serving directly from the panel")
    assert(not scene15.customer.dismissed, "the customer should be served, not dismissed")

    local still_in_panel = false
    for _, it in ipairs(microwave15.panel:items()) do
        if it == steamed15 then still_in_panel = true end
    end
    assert(not still_in_panel, "the served item should be removed from the microwave's panel")

    print("PASS: kitchen_scene: the broccoli/Cook/steamed_broccoli pipeline serves a Healthy-tag request end-to-end")
end

-- Test 16: dropping a RAW item (no tags at all) into the order panel is
-- always rejected, regardless of what tag the customer is requesting. This
-- falls straight out of has_tag's empty-tags-list check with no
-- special-casing needed in kitchen_scene.lua itself - this test just proves
-- it holds for both raw items and both tags currently in play. Rewritten
-- (Task 8) to drive the panel/Skip flow (same shape as Test 11's rewrite)
-- rather than dropping directly on the customer's sprite body, which no
-- longer does anything special.

do
    local function assert_raw_drop_rejected(raw_type_id, tag)
        local ctxN = runner.setup(function() return KitchenScene.new() end)
        local sceneN = ctxN.sm.current

        sceneN.customer:show(order_cfg({ requested_tag = tag }))
        runner.fast_forward_until(ctxN, function() return sceneN.customer:arrived() end, 0)
        assert(sceneN.customer.requested_tag == tag, "sanity check: forced customer wants " .. tag)

        local raw_item
        for _, it in ipairs(sceneN.grid:items()) do
            if it.type_id == raw_type_id then raw_item = it end
        end
        assert(raw_item, "on_enter should have placed " .. raw_type_id)
        assert(#raw_item.tags == 0, "sanity check: " .. raw_type_id .. " should carry no tags")

        local currency_before = sceneN.day_state.currency
        local served_before   = sceneN.day_state.customers_served

        -- Click through the greeting to open the order panel: one click
        -- finishes the greeting and immediately opens the panel.
        local cxN, cyN = sceneN.customer.x, sceneN.customer.y
        sceneN:mouse_pressed(cxN, cyN)
        assert(sceneN.customer.done_talking, "sanity check: done_talking should be true after one click")
        assert(#sceneN.panels == 1, "the same click that finishes the greeting should immediately open the order panel")
        local order_panelN = sceneN.panels[1]
        assert(order_panelN.item == sceneN.customer, "the order panel should wrap the customer itself")

        -- Drag the raw (untagged) item into the order panel's grid.
        local rx, ry = sceneN.grid:cell_to_world(raw_item.cell_col, raw_item.cell_row)
        sceneN:mouse_pressed(rx + 1, ry + 1)
        assert(sceneN.grid.dragging == raw_item, "mouse_pressed on the raw item's cell should start dragging it")

        local pxN, pyN = order_panelN.item.panel:cell_to_world(0, 0)
        sceneN:mouse_moved(pxN + 1, pyN + 1)
        sceneN:mouse_released(pxN + 1, pyN + 1)

        assert(sceneN.grid.dragging == nil, "dropping into the order panel should clear the main grid's drag state")
        assert(raw_item.grid == order_panelN.item.panel, "the raw item should now be in the order panel's grid")

        -- Serve must be disabled: a raw item carries no tags at all, so it
        -- can never satisfy any requested tag.
        assert(not order_panelN:_serve_enabled(),
            "Serve should be disabled with an untagged " .. raw_type_id .. " in the panel")

        -- Click Skip instead.
        local skipN = order_panelN.buttons["Skip"]
        assert(skipN, "order panel should have a Skip button")
        sceneN:mouse_pressed(skipN.x + skipN.w / 2, skipN.y + skipN.h / 2)

        assert(#sceneN.panels == 0, "clicking Skip should close the order panel")
        assert(raw_item.grid == sceneN.grid, "the skipped item should be returned to the main floor grid")

        local back_on_grid = false
        for _, it in ipairs(sceneN.grid:items()) do
            if it == raw_item then back_on_grid = true end
        end
        assert(back_on_grid, "the skipped item should be listed on the main floor grid")

        assert(sceneN.day_state.currency == currency_before,
            "dropping raw " .. raw_type_id .. " must never award currency, even when requesting " .. tag)
        assert(sceneN.day_state.customers_served == served_before + 1,
            "the visit should still count toward the day even though it was rejected")
        assert(sceneN.customer.dismissed,
            "dropping raw " .. raw_type_id .. " on a customer requesting " .. tag .. " should always be dismissed")
    end

    -- Cross-product: each raw item against each tag currently in play, so
    -- this doesn't just prove "raw_meat never satisfies Protein" (which
    -- could coincidentally hold for the wrong reason) but the general rule.
    assert_raw_drop_rejected("raw_meat", "Protein")
    assert_raw_drop_rejected("raw_meat", "Healthy")
    assert_raw_drop_rejected("broccoli", "Healthy")
    assert_raw_drop_rejected("broccoli", "Protein")

    print("PASS: kitchen_scene: dropping any raw (untagged) item on a customer is always rejected, regardless of the requested tag")
end

-- Test 17: double-click and right-click to open a container's panel also
-- work on an item sitting INSIDE an already-open panel's own grid - the
-- pot-in-microwave scenario from docs/design/cooking-methods.md.
-- Also a regression check that right-clicking dead backdrop space (e.g. a
-- panel's title bar) is still a no-op, unaffected by that generalization.

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx17 = runner.setup(function() return KitchenScene.new() end)
    local scene17 = ctx17.sm.current

    local microwave17
    for _, it in ipairs(scene17.grid:items()) do
        if it.type_id == "microwave" then microwave17 = it end
    end
    assert(microwave17, "on_enter should have placed a microwave")

    scene17.panels = { ItemPanel.new(microwave17) }

    -- Place a pot directly into the OPEN microwave panel (it fits:
    -- the microwave's panel is 2 cols wide, the pot's footprint is
    -- 2x1) - no need to drive it through a drag for this test.
    local pot17 = Item.new("pot")
    assert(microwave17.panel:can_place(pot17, 0, 0),
        "pot should fit in the microwave's 2-wide panel")
    microwave17.panel:place(pot17, 0, 0)

    -- Double-click the pot's cell within the open microwave panel.
    local dx17, dy17 = microwave17.panel:cell_to_world(0, 0)
    dx17, dy17 = dx17 + 1, dy17 + 1

    scene17:mouse_pressed(dx17, dy17)
    scene17:mouse_released(dx17, dy17)
    scene17:mouse_pressed(dx17, dy17)
    scene17:mouse_released(dx17, dy17)

    assert(#scene17.panels == 2,
        "double-clicking a has_panel item inside an open panel should open a second panel")
    assert(scene17.panels[2].item == pot17,
        "the newly opened (topmost) panel should wrap the pot")

    print("PASS: kitchen_scene: double-clicking a pot sitting inside an already-open microwave panel opens its own panel")
end

do
    local ItemPanel = require("lua/game/item_panel")

    local ctx17b = runner.setup(function() return KitchenScene.new() end)
    local scene17b = ctx17b.sm.current

    local microwave17b
    for _, it in ipairs(scene17b.grid:items()) do
        if it.type_id == "microwave" then microwave17b = it end
    end
    assert(microwave17b, "on_enter should have placed a microwave")

    scene17b.panels = { ItemPanel.new(microwave17b) }

    local pot17b = Item.new("pot")
    assert(microwave17b.panel:can_place(pot17b, 0, 0),
        "pot should fit in the microwave's 2-wide panel")
    microwave17b.panel:place(pot17b, 0, 0)

    -- Right-click the pot's cell within the open microwave panel:
    -- should open its panel in one click.
    local dx17b, dy17b = microwave17b.panel:cell_to_world(0, 0)
    dx17b, dy17b = dx17b + 1, dy17b + 1

    scene17b:mouse_right_pressed(dx17b, dy17b)

    assert(#scene17b.panels == 2,
        "right-clicking a has_panel item inside an open panel should open its panel in one click")
    assert(scene17b.panels[2].item == pot17b,
        "the newly opened (topmost) panel should wrap the pot")

    print("PASS: kitchen_scene: right-clicking a pot sitting inside an already-open microwave panel opens its panel in one click")
end

do
    -- Regression check: right-clicking elsewhere on an open panel's backdrop
    -- (e.g. its title bar) - dead space, not its inner grid - must remain a
    -- no-op. Confirms Task 3's generalization (checking a click's target
    -- grid topmost-first) didn't loosen the "backdrop dead space is a
    -- no-op" rule for right-click.
    local ItemPanel = require("lua/game/item_panel")

    local ctx17c = runner.setup(function() return KitchenScene.new() end)
    local scene17c = ctx17c.sm.current

    local microwave17c
    for _, it in ipairs(scene17c.grid:items()) do
        if it.type_id == "microwave" then microwave17c = it end
    end
    assert(microwave17c, "on_enter should have placed a microwave")

    local panel17c = ItemPanel.new(microwave17c)
    scene17c.panels = { panel17c }

    scene17c:mouse_right_pressed(panel17c.title_bar.x + 5, panel17c.title_bar.y + 5)

    assert(#scene17c.panels == 1,
        "right-clicking an open panel's dead backdrop space (e.g. its title bar) should remain a no-op")

    print("PASS: kitchen_scene: right-clicking dead backdrop space on an open panel is still a no-op")
end

-- Test 18: _hover_grid returns nil when the cursor is outside all grids.
-- Regression guard for the fix that makes `_hover_grid` check actual
-- grid bounds before falling back to `self.grid`, so the drop-preview
-- outline is suppressed while the cursor is in the customer stage area.

do
    local config = require("lua/game/config")

    local ctx18 = runner.setup(function() return KitchenScene.new() end)
    local scene18 = ctx18.sm.current

    -- A point well above SPLIT_Y is definitely in the stage area, never the
    -- floor grid (which starts at SPLIT_Y + 12).
    local stage_x = config.SCREEN_W / 2
    local stage_y = config.SPLIT_Y / 2

    assert(scene18:_hover_grid(stage_x, stage_y) == nil,
        "_hover_grid should return nil for a point in the customer stage area (above the floor grid)")

    -- A point in the dead space to the left of the grid (grid starts at
    -- GRID_ORIGIN_X, which is centered; left edge is well inside the screen).
    local left_of_grid = config.GRID_ORIGIN_X - 10
    local grid_mid_y   = config.GRID_ORIGIN_Y + config.GRID_ROWS * config.U / 2
    assert(scene18:_hover_grid(left_of_grid, grid_mid_y) == nil,
        "_hover_grid should return nil for a point to the left of the floor grid")

    -- A point squarely inside the floor grid must still return self.grid.
    local in_grid_x = config.GRID_ORIGIN_X + config.U
    local in_grid_y = config.GRID_ORIGIN_Y + config.U
    assert(scene18:_hover_grid(in_grid_x, in_grid_y) == scene18.grid,
        "_hover_grid should still return self.grid for a point inside the floor grid")

    print("PASS: kitchen_scene: _hover_grid returns nil for points outside all grids, self.grid for points inside it")
end

-- Test 19: the drop-preview is gated on can_place - it is suppressed when
-- hovering over an occupied or out-of-bounds cell, even though the preview
-- col/row ARE tracked internally while the cursor is over the grid. The
-- can_place guard was added to Grid:draw to make the preview only appear
-- where a successful drop is actually possible.

do
    local ctx19 = runner.setup(function() return KitchenScene.new() end)
    local scene19 = ctx19.sm.current

    -- The microwave occupies (0,0)-(1,1) on the main grid. Drag a meat item,
    -- then hover over the microwave's cell: can_place should be false there,
    -- so the draw guard suppresses the preview. Verify the state that drives
    -- the draw decision.
    local meat19
    for _, it in ipairs(scene19.grid:items()) do
        if it.type_id == "raw_meat" then meat19 = it end
    end
    assert(meat19, "on_enter should have placed raw_meat")

    local mx19, my19 = scene19.grid:cell_to_world(meat19.cell_col, meat19.cell_row)
    scene19:mouse_pressed(mx19 + 1, my19 + 1)
    assert(scene19.grid.dragging == meat19, "sanity check: should be dragging meat")

    -- Move over the microwave's cell (0,0) - occupied by a different item.
    local microwave_wx, microwave_wy = scene19.grid:cell_to_world(0, 0)
    scene19:mouse_moved(microwave_wx + 1, microwave_wy + 1)

    -- The preview col/row are set (cursor is over the grid), but can_place
    -- returns false (cell is occupied by the microwave), so Grid:draw would
    -- not render the outline.
    assert(scene19.grid.drag_preview_col ~= nil,
        "preview col should be tracked while cursor is over the grid")
    local pc, pr = scene19.grid.drag_preview_col, scene19.grid.drag_preview_row
    assert(not scene19.grid:can_place(meat19, pc, pr),
        "can_place should be false at an occupied cell, so the draw guard suppresses the preview")

    -- Hover over a free cell: can_place should now be true, preview shows.
    local free_wx, free_wy = scene19.grid:cell_to_world(5, 3)
    scene19:mouse_moved(free_wx + 1, free_wy + 1)
    local pc2, pr2 = scene19.grid.drag_preview_col, scene19.grid.drag_preview_row
    assert(scene19.grid:can_place(meat19, pc2, pr2),
        "can_place should be true at a free cell, so the draw guard would render the preview")

    scene19:mouse_released(free_wx + 1, free_wy + 1)

    print("PASS: kitchen_scene: drop-preview is gated on can_place - suppressed at occupied cells, shown at free cells")
end

-- Test 20: releasing a drag outside all grids (cursor in the stage area)
-- snaps the item back to its original cell. Regression guard for the nil-
-- hover fix in mouse_released: with hover == nil, the code must not crash
-- or lose the item; it must snap back just like a failed can_place drop.

do
    local config = require("lua/game/config")

    local ctx20 = runner.setup(function() return KitchenScene.new() end)
    local scene20 = ctx20.sm.current

    local meat20
    for _, it in ipairs(scene20.grid:items()) do
        if it.type_id == "raw_meat" then meat20 = it end
    end
    assert(meat20, "on_enter should have placed raw_meat")

    local orig_col, orig_row = meat20.cell_col, meat20.cell_row
    local mx20, my20 = scene20.grid:cell_to_world(orig_col, orig_row)

    scene20:mouse_pressed(mx20 + 1, my20 + 1)
    assert(scene20.grid.dragging == meat20, "sanity check: should be dragging the meat")

    -- Release in the stage area (above SPLIT_Y), which is outside all grids.
    local release_x = config.SCREEN_W / 2
    local release_y = config.SPLIT_Y / 2
    assert(scene20:_hover_grid(release_x, release_y) == nil,
        "sanity check: release point should be outside all grids")

    scene20:mouse_released(release_x, release_y)

    assert(scene20.grid.dragging == nil, "drag state should be cleared after release outside all grids")
    assert(meat20.grid == scene20.grid, "item should snap back to the main grid after release outside all grids")
    assert(meat20.cell_col == orig_col and meat20.cell_row == orig_row,
        "item should snap back to its original cell, got ("
            .. tostring(meat20.cell_col) .. "," .. tostring(meat20.cell_row) .. ")")

    print("PASS: kitchen_scene: releasing a drag outside all grids snaps the item back to its original cell")
end

print("ALL TESTS PASSED")
