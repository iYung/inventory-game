local Customer = require("lua/game/customer")

-- Test 1: full state walk — idle -> walking_in -> waiting -> serve ->
-- talking_after -> walking_out -> idle.
do
    local target_x, exit_x, y = 500, 100, 200
    local c = Customer.new(target_x, exit_x, y)
    assert(c.state == "idle", "new customer should start idle")

    c:show({
        name            = "Test Customer",
        messages        = { "Could I get some cooked meat?" },
        after_messages  = { "Thanks so much!" },
        requested_type  = "cooked_meat",
        walk_speed      = 1000,
    })
    assert(c.state == "walking_in", "show() should start walking_in")
    assert(c.requested_type == "cooked_meat", "requested_type should be stored")
    assert(c.name == "Test Customer", "name should be stored")
    assert(not c.done_talking, "done_talking should be false with pre-messages present")
    assert(not c:bubble_visible(), "bubble should not be visible yet while still walking in")

    -- Tick until the customer reaches target_x (state becomes "waiting").
    -- The bubble must stay hidden for the whole approach and only appear
    -- once actually arrived.
    local iters = 0
    while c.state ~= "waiting" do
        assert(not c:bubble_visible(), "bubble should stay hidden throughout walking_in, not just at the start")
        c:update(1 / 60)
        iters = iters + 1
        assert(iters < 10000, "customer never reached waiting state")
    end
    assert(c.x == target_x, "x should snap exactly to target_x on arrival")
    assert(c:arrived(), "arrived() should be true once waiting")
    assert(c:active(), "active() should be true once waiting")
    assert(c:bubble_visible(), "bubble should become visible immediately once waiting/arrived")

    -- Serve: since after_messages exist, should move to talking_after.
    c:serve()
    assert(c.state == "talking_after", "serve() with after_messages should enter talking_after")

    -- Reveal + advance through the single after-message to walking_out.
    c:skip_reveal()
    assert(c:line_complete(), "line should be complete after skip_reveal")
    c:advance_after()
    assert(c.state == "walking_out", "advance_after() past the last after-message should walk_out")

    -- Tick until the customer reaches exit_x (state becomes "idle").
    iters = 0
    while c.state ~= "idle" do
        c:update(1 / 60)
        iters = iters + 1
        assert(iters < 10000, "customer never returned to idle")
    end
    assert(c.x == exit_x, "x should snap exactly to exit_x on exit")
    assert(not c:active(), "active() should be false once idle")
    assert(not c.sprite.visible, "sprite should be hidden once idle")

    print("PASS: customer: full state walk idle -> walking_in -> waiting -> serve -> talking_after -> walking_out -> idle")
end

-- Test 2: dismiss() short-circuits straight to walking_out, skipping
-- talking_after, even when after_messages were provided.
do
    local target_x, exit_x, y = 500, 100, 200
    local c = Customer.new(target_x, exit_x, y)

    c:show({
        name           = "Wrong Item Customer",
        messages       = { "I wanted cooked meat!" },
        after_messages = { "Thanks so much!" }, -- present, but must be skipped
        requested_type = "cooked_meat",
        walk_speed     = 1000,
    })

    local iters = 0
    while c.state ~= "waiting" do
        c:update(1 / 60)
        iters = iters + 1
        assert(iters < 10000, "customer never reached waiting state")
    end
    assert(c:arrived(), "customer should be waiting before dismiss")

    c:dismiss()
    assert(c.state == "walking_out", "dismiss() should go straight to walking_out")
    assert(c.state ~= "talking_after", "dismiss() must not enter talking_after")
    assert(c.dismissed, "dismissed flag should be set")
    assert(not c:bubble_visible(), "bubble should not be visible after dismiss")

    iters = 0
    while c.state ~= "idle" do
        c:update(1 / 60)
        iters = iters + 1
        assert(iters < 10000, "dismissed customer never returned to idle")
    end
    assert(c.x == exit_x, "x should snap exactly to exit_x on exit after dismiss")

    print("PASS: customer: dismiss() short-circuits straight to walking_out, skipping talking_after")
end

-- Test 3: walking animation - the sprite bobs and legs swing while walking,
-- and both settle back to rest once the customer is waiting (standing
-- still). Placeholder-art walk cycle: no sprite frames, just a procedural
-- vertical bob plus two swinging leg rectangles drawn under the body.
do
    local target_x, exit_x, y = 900, 100, 200
    local c = Customer.new(target_x, exit_x, y)
    c:show({ name = "Walker", walk_speed = 200 })
    assert(c.state == "walking_in", "sanity check: should be walking in")

    local saw_bob     = false
    local saw_leg_off = false

    local iters = 0
    while c.state == "walking_in" do
        c:update(1 / 60)
        if c.sprite.y ~= (c.y - c.sprite.height / 2) then saw_bob = true end
        if c:_leg_swing() ~= 0 then saw_leg_off = true end
        iters = iters + 1
        assert(iters < 10000, "customer never reached waiting state")
    end

    assert(saw_bob, "sprite.y should bob away from its resting position while walking")
    assert(saw_leg_off, "_leg_swing() should be nonzero at some point while walking")

    -- Once waiting (standing still), the animation must settle back to rest.
    assert(c:_leg_swing() == 0, "_leg_swing() should be exactly 0 once standing still")
    c:update(1 / 60)
    assert(c.sprite.y == c.y - c.sprite.height / 2,
        "sprite.y should return to its exact resting position once standing still")

    print("PASS: customer: walking animation bobs/swings legs while moving and rests while standing still")
end

-- Test 4: show() with cfg.kind == "merchant" populates panel/type_id and
-- first-fit places the stock items into a Grid sized per config.
do
    local config = require("lua/game/config")

    local target_x, exit_x, y = 500, 100, 200
    local c = Customer.new(target_x, exit_x, y)

    c:show({
        name  = "Merchant",
        kind  = "merchant",
        stock = { "raw_meat", "raw_meat", "cooked_meat" },
    })

    assert(c.kind == "merchant", "kind should be 'merchant'")
    assert(c.type_id == "merchant", "type_id should be 'merchant'")
    assert(c.panel ~= nil, "panel should be populated for a merchant")
    assert(c.panel.cols == config.MERCHANT_PANEL_COLS, "panel cols should match config.MERCHANT_PANEL_COLS")
    assert(c.panel.rows == config.MERCHANT_PANEL_ROWS, "panel rows should match config.MERCHANT_PANEL_ROWS")

    local items = c.panel:items()
    assert(#items == 3, "panel should contain all 3 stock items")

    local counts = {}
    for _, it in ipairs(items) do
        counts[it.type_id] = (counts[it.type_id] or 0) + 1
    end
    assert(counts.raw_meat == 2, "panel should contain 2 raw_meat")
    assert(counts.cooked_meat == 1, "panel should contain 1 cooked_meat")

    print("PASS: customer: show() with kind == 'merchant' populates panel/type_id with first-fit stock")
end

-- Test 5: show() with cfg.kind omitted (a normal order-customer config)
-- leaves panel/type_id nil - regression guard against merchant fields
-- leaking into ordinary order customers.
do
    local target_x, exit_x, y = 500, 100, 200
    local c = Customer.new(target_x, exit_x, y)

    c:show({
        name            = "Test Customer",
        messages        = { "Could I get some cooked meat?" },
        after_messages  = { "Thanks so much!" },
        requested_type  = "cooked_meat",
        walk_speed      = 1000,
    })

    assert(c.kind == "order", "kind should default to 'order' when omitted")
    assert(c.panel == nil, "panel should be nil for a non-merchant customer")
    assert(c.type_id == nil, "type_id should be nil for a non-merchant customer")

    print("PASS: customer: show() with kind omitted leaves panel/type_id nil (regression guard)")
end

-- Test 6: a reused Customer instance correctly resets panel/type_id when
-- show() is called again without kind == "merchant" - guards against a
-- stale panel/type_id from a previous merchant visit leaking into a later
-- order-customer visit on the same object (Customer instances are reused
-- across a day, per kitchen_scene.lua's existing pattern).
do
    local target_x, exit_x, y = 500, 100, 200
    local c = Customer.new(target_x, exit_x, y)

    c:show({
        name  = "Merchant",
        kind  = "merchant",
        stock = { "raw_meat" },
    })
    assert(c.panel ~= nil, "sanity check: panel should be set after merchant show()")
    assert(c.type_id == "merchant", "sanity check: type_id should be set after merchant show()")

    c:show({
        name            = "Test Customer",
        messages        = { "Could I get some cooked meat?" },
        requested_type  = "cooked_meat",
    })
    assert(c.kind == "order", "kind should reset to 'order' on a subsequent non-merchant show()")
    assert(c.panel == nil, "panel should reset to nil on a subsequent non-merchant show()")
    assert(c.type_id == nil, "type_id should reset to nil on a subsequent non-merchant show()")

    -- And the reverse direction: order -> merchant should also populate
    -- fresh fields correctly (not just reset from merchant -> order).
    c:show({
        name  = "Merchant",
        kind  = "merchant",
        stock = { "cooked_meat", "cooked_meat" },
    })
    assert(c.kind == "merchant", "kind should become 'merchant' again on a subsequent merchant show()")
    assert(c.panel ~= nil, "panel should be repopulated on a subsequent merchant show()")
    assert(c.type_id == "merchant", "type_id should be set again on a subsequent merchant show()")
    assert(#c.panel:items() == 2, "repopulated panel should contain the new stock, not the old")

    print("PASS: customer: show() on a reused instance resets panel/type_id correctly in both directions")
end

print("ALL TESTS PASSED")
