local Item = require("lua/game/item")

-- Test 0: tags - raw/unprepared items carry none; prepared items do.
do
    local raw = Item.new("raw_meat")
    assert(#raw.tags == 0, "raw_meat should carry no tags, got " .. #raw.tags)

    local cooked = Item.new("cooked_meat")
    assert(#cooked.tags == 1 and cooked.tags[1] == "Protein",
        "cooked_meat should be tagged Protein")

    local broccoli = Item.new("broccoli")
    assert(#broccoli.tags == 0, "raw broccoli should carry no tags")

    local steamed = Item.new("steamed_broccoli")
    assert(#steamed.tags == 1 and steamed.tags[1] == "Healthy",
        "steamed_broccoli should be tagged Healthy")

    print("PASS: item: raw items carry no tags, prepared items carry their def's tags")
end

-- Test: item.label is set from def.name
do
    local raw = Item.new("raw_meat")
    assert(raw.label == "Raw Meat", "raw_meat label should be 'Raw Meat', got " .. tostring(raw.label))

    local cooked = Item.new("cooked_meat")
    assert(cooked.label == "Cooked Meat", "cooked_meat label should be 'Cooked Meat', got " .. tostring(cooked.label))

    local mw = Item.new("microwave")
    assert(mw.label == "Microwave", "microwave label should be 'Microwave', got " .. tostring(mw.label))

    print("PASS: item: label field matches def.name for each item type")
end

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

-- Test 1b: a 2x2 item's bounding box stays square through rotation (sanity
-- check on the rotation math specifically for the microwave).
do
    local microwave = Item.new("microwave")
    assert(microwave.sprite.width  == 2 * 36, "microwave sprite width should start at 2 cells")
    assert(microwave.sprite.height == 2 * 36, "microwave sprite height should start at 2 cells")
    microwave:rotate()
    assert(microwave.sprite.width  == 2 * 36, "microwave sprite width should remain 2 cells after rotation (square footprint)")
    assert(microwave.sprite.height == 2 * 36, "microwave sprite height should remain 2 cells after rotation (square footprint)")
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

-- Test 3d: the microwave's single "Cook" button handles more than one
-- recipe - it auto-matches whichever ingredient is actually present
-- (raw_meat or broccoli) rather than needing a separate button per recipe.
do
    local microwave = Item.new("microwave")
    local broccoli = Item.new("broccoli")
    microwave.panel:place(broccoli, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with broccoli in the panel too, not just raw_meat")
    assert(microwave.action_state["Cook"].matches[1].recipe.produces.steamed_broccoli == 1,
        "the matched recipe should be the broccoli->steamed_broccoli one")

    microwave:update(3.5) -- past the 3.0s duration
    local items = microwave.panel:items()
    assert(#items == 1 and items[1].type_id == "steamed_broccoli",
        "broccoli should have cooked into steamed_broccoli via the same Cook button")

    print("PASS: item: Cook auto-matches whichever recipe the panel's contents satisfy")
end

-- Test 3e: start_action returns false when the panel holds nothing that
-- matches ANY of Cook's recipes (not raw_meat, not broccoli).
do
    local microwave = Item.new("microwave")
    local cooked = Item.new("cooked_meat") -- not an ingredient for any recipe
    microwave.panel:place(cooked, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == false, "Cook should not start when nothing in the panel matches any recipe")
    assert(microwave.action_state["Cook"] == nil, "action_state should stay unset")
    print("PASS: item: start_action returns false when no recipe's requirements are met")
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

-- Test 6: container recipe, happy path. A loaded pot sitting inside
-- the microwave's panel cooks into soup inside the pot's OWN
-- panel, not the microwave's - and the pot itself is never consumed.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    local water    = Item.new("water")
    local raw_meat = Item.new("raw_meat")
    pot.panel:place(water, 0, 0)
    pot.panel:place(raw_meat, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a fully loaded pot in the microwave's panel")

    microwave:update(3.5) -- past the 3.0s duration

    local soup_items = pot.panel:items()
    assert(#soup_items == 1 and soup_items[1].type_id == "soup",
        "pot's own panel should contain exactly one soup after cooking")

    local microwave_items = microwave.panel:items()
    assert(#microwave_items == 1 and microwave_items[1].type_id == "pot" and microwave_items[1] == pot,
        "microwave's own panel should still contain only the same (uneaten) pot item")

    print("PASS: item: container recipe cooks a loaded pot's contents into soup inside its own panel")
end

-- Test 7: container recipe, not satisfied - a pot missing one
-- ingredient (water) does not let Cook start.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    local raw_meat = Item.new("raw_meat")
    pot.panel:place(raw_meat, 0, 0)
    -- No water placed.

    local started = microwave:start_action("Cook")
    assert(started == false, "Cook should not start with a partially loaded pot (missing water)")
    assert(microwave.action_state["Cook"] == nil, "action_state should stay unset when the container recipe isn't satisfied")

    print("PASS: item: container recipe does not fire when the pot is only partially loaded")
end

-- Test 8: container recipe requires the container itself to be present -
-- loose ingredients sitting directly in the microwave's own 2-cell panel
-- (no pot item present) do not satisfy the container recipe. Note:
-- raw_meat already has its OWN flat, non-container Cook
-- recipe (raw_meat -> cooked_meat), so placing it loose would start
-- Cook via that unrelated recipe instead and wouldn't isolate what this
-- test is checking; water has no flat recipe of its own, so two waters
-- (filling both of the microwave's panel cells) are used here to keep
-- the "no container present" check isolated from those other,
-- already-passing recipes.
do
    local microwave = Item.new("microwave")

    local water_a = Item.new("water")
    local water_b = Item.new("water")
    microwave.panel:place(water_a, 0, 0)
    microwave.panel:place(water_b, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == false, "Cook should not start via the container recipe when no pot item is present")

    print("PASS: item: container recipe never fires without an actual container item present")
end

-- Test 9: multiple recipes fire in one press - raw_meat and broccoli
-- together in the microwave's (now 2-wide) panel both cook from a single
-- Cook press.
do
    local microwave = Item.new("microwave")
    local meat      = Item.new("raw_meat")
    local broccoli  = Item.new("broccoli")
    microwave.panel:place(meat, 0, 0)
    microwave.panel:place(broccoli, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with both raw_meat and broccoli present")

    microwave:update(3.5) -- past the 3.0s duration

    local items = microwave.panel:items()
    assert(#items == 2, "panel should contain exactly two items after both recipes fire, got " .. #items)

    local has_cooked_meat, has_steamed_broccoli = false, false
    for _, it in ipairs(items) do
        if it.type_id == "cooked_meat" then has_cooked_meat = true end
        if it.type_id == "steamed_broccoli" then has_steamed_broccoli = true end
    end
    assert(has_cooked_meat, "panel should contain cooked_meat after the single Cook press")
    assert(has_steamed_broccoli, "panel should contain steamed_broccoli after the single Cook press")

    print("PASS: item: a single Cook press fires every satisfied recipe (raw_meat and broccoli together)")
end

-- Test 10: the new simple potato recipe (potato -> baked_potato) works like
-- the other flat, non-container microwave recipes.
do
    local microwave = Item.new("microwave")
    local potato    = Item.new("potato")
    microwave.panel:place(potato, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a potato in the microwave's panel")

    microwave:update(3.5) -- past the 3.0s duration

    local items = microwave.panel:items()
    assert(#items == 1 and items[1].type_id == "baked_potato",
        "potato should have cooked into baked_potato")

    print("PASS: item: potato -> baked_potato recipe works via the microwave's Cook button")
end

-- Test 12: a newly created plant has its panel pre-filled with 3 broccoli.
do
    local plant = Item.new("plant")
    assert(plant.panel ~= nil, "plant should have a panel")
    local items = plant.panel:items()
    assert(#items == 3, "plant panel should start with 3 items, got " .. #items)
    for i, it in ipairs(items) do
        assert(it.type_id == "broccoli",
            "plant panel item " .. i .. " should be broccoli, got " .. tostring(it.type_id))
    end
    print("PASS: item: newly created plant has 3 broccoli pre-filled in its panel")
end

-- Test 13: removing one broccoli and calling refill_daily() restores 3 broccoli.
do
    local plant = Item.new("plant")
    local items = plant.panel:items()
    plant.panel:remove(items[1])
    assert(#plant.panel:items() == 2, "plant panel should have 2 items after removing one")

    plant:refill_daily()
    local refilled = plant.panel:items()
    assert(#refilled == 3, "plant panel should be back to 3 items after refill_daily(), got " .. #refilled)
    for i, it in ipairs(refilled) do
        assert(it.type_id == "broccoli",
            "plant panel item " .. i .. " should be broccoli after refill, got " .. tostring(it.type_id))
    end
    print("PASS: item: refill_daily() restores plant panel back to 3 broccoli after one is removed")
end

-- Test 14: refill_daily() on an item without daily_fill (e.g. raw_meat) is a no-op.
do
    local meat = Item.new("raw_meat")
    -- raw_meat has no panel and no daily_fill — calling refill_daily() must not error.
    meat:refill_daily()
    print("PASS: item: refill_daily() is a no-op and does not error on an item without daily_fill")
end

-- Test 11: the fryer's single-recipe Fry action (potato -> fries).
do
    local fryer  = Item.new("fryer")
    local potato = Item.new("potato")
    fryer.panel:place(potato, 0, 0)

    local started = fryer:start_action("Fry")
    assert(started == true, "Fry should start with a potato in the fryer's panel")

    fryer:update(3.5) -- past the 3.0s duration

    local items = fryer.panel:items()
    assert(#items == 1 and items[1].type_id == "fries",
        "potato should have fried into fries")

    print("PASS: item: fryer's Fry action turns potato into fries")
end

print("ALL TESTS PASSED")
