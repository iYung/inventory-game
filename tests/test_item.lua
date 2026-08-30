local Item = require("lua/game/item")

-- Test 1: rotate cycles through 4 states and returns to the original
-- footprint on the 4th call.
do
    local microwave = Item.new("microwave")
    local original = microwave:footprint()

    local seen_dims = {}
    for i = 1, 4 do
        microwave:rotate()
        local fp = microwave:footprint()
        local max_dx, max_dy = 0, 0
        for _, c in ipairs(fp) do
            if c[1] > max_dx then max_dx = c[1] end
            if c[2] > max_dy then max_dy = c[2] end
        end
        seen_dims[i] = { max_dx + 1, max_dy + 1 }
    end

    assert(microwave.rotation == 0, "rotation should wrap back to 0 after 4 rotate() calls, got " .. tostring(microwave.rotation))

    local final = microwave:footprint()
    assert(#final == #original, "footprint cell count should match original after 4 rotations")

    -- Compare as sets of {dx,dy} pairs (order not guaranteed to matter, but
    -- rotate_cells/place_first_fit style code preserves index order here).
    local function cells_equal(a, b)
        if #a ~= #b then return false end
        local function key(c) return c[1] .. "," .. c[2] end
        local set_a, set_b = {}, {}
        for _, c in ipairs(a) do set_a[key(c)] = true end
        for _, c in ipairs(b) do set_b[key(c)] = true end
        for k in pairs(set_a) do
            if not set_b[k] then return false end
        end
        for k in pairs(set_b) do
            if not set_a[k] then return false end
        end
        return true
    end

    assert(cells_equal(final, original), "footprint after 4 rotations should equal the original footprint")
    print("PASS: item: rotate() cycles through 4 states and returns to the original footprint")
end

-- Test 1b: a 1x1 item's bounding box is trivially unchanged through
-- rotation (sanity check that rotate() still correctly refreshes sprite
-- dimensions from the footprint even when they don't actually change).
do
    local microwave = Item.new("microwave")
    assert(microwave.sprite.width  == 1 * 36, "microwave sprite width should start at 1 cell")
    assert(microwave.sprite.height == 1 * 36, "microwave sprite height should start at 1 cell")
    microwave:rotate()
    assert(microwave.sprite.width  == 1 * 36, "microwave sprite width should remain 1 cell after rotation (1x1 footprint)")
    assert(microwave.sprite.height == 1 * 36, "microwave sprite height should remain 1 cell after rotation (1x1 footprint)")
    print("PASS: item: rotate() refreshes sprite dimensions from the rotated footprint")
end

-- Test 2: start_action no-ops (returns false, doesn't start the timer)
-- without required items present in panel.
do
    local microwave = Item.new("microwave")
    assert(microwave.panel ~= nil, "microwave should have a panel")

    local started = microwave:start_action("Cook")
    assert(started == false, "start_action should return false when the panel has no raw_meat")
    assert(microwave.action_state["Cook"] == nil, "action_state should not be set when start_action fails")
    print("PASS: item: start_action no-ops without required items in panel")
end

-- Test 3: start_action with required items present starts the timer
-- (returns true).
do
    local microwave = Item.new("microwave")
    local meat = Item.new("raw_meat")
    local placed = microwave.panel:place(meat, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "start_action should return true when requirements are met")
    assert(microwave.action_state["Cook"] ~= nil, "action_state['Cook'] should be set after starting")
    assert(microwave.action_state["Cook"].running == true, "action_state['Cook'].running should be true")
    assert(microwave.action_state["Cook"].elapsed == 0, "action_state['Cook'].elapsed should start at 0")
    print("PASS: item: start_action with required items present starts the timer")
end

-- Test 3b: start_action returns false for an unknown action name.
do
    local microwave = Item.new("microwave")
    local started = microwave:start_action("Nope")
    assert(started == false, "start_action should return false for an unknown action name")
    print("PASS: item: start_action returns false for an unknown action")
end

-- Test 3c: start_action returns false for an item with no panel.
do
    local meat = Item.new("raw_meat")
    local started = meat:start_action("Cook")
    assert(started == false, "start_action should return false when the item has no panel")
    print("PASS: item: start_action returns false when item has no panel")
end

-- Test 4: update(dt) advanced past duration transforms matching items in
-- panel from raw_meat to cooked_meat in place (same cell).
do
    local microwave = Item.new("microwave")
    local meat = Item.new("raw_meat")
    microwave.panel:place(meat, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "start_action should succeed with raw_meat in the panel")

    -- Advance short of duration: should not complete yet.
    microwave:update(1.0)
    assert(microwave.action_state["Cook"] ~= nil, "action should still be running before duration elapses")
    local panel_items = microwave.panel:items()
    assert(#panel_items == 1 and panel_items[1].type_id == "raw_meat",
        "panel should still contain raw_meat before the action completes")

    -- Advance past duration (3.0s total, action.duration for Cook).
    microwave:update(2.5)

    assert(microwave.action_state["Cook"] == nil, "action_state['Cook'] should be cleared after completion")

    local final_items = microwave.panel:items()
    assert(#final_items == 1, "panel should still contain exactly one item after the action completes")
    assert(final_items[1].type_id == "cooked_meat",
        "panel item should have transformed from raw_meat to cooked_meat, got " .. tostring(final_items[1].type_id))
    assert(final_items[1].cell_col == 0 and final_items[1].cell_row == 0,
        "cooked_meat should occupy the same cell the raw_meat was in")
    print("PASS: item: update(dt) past duration transforms raw_meat into cooked_meat in place")
end

-- Test 5: Item:draw() is nil-safe / does not error when unplaced.
do
    local meat = Item.new("raw_meat")
    meat:draw() -- should not error even though cell_col/cell_row/grid are nil
    print("PASS: item: draw() does not error for an unplaced item")
end

print("ALL TESTS PASSED")
