require("lua/headless/stubs")
local Item = require("lua/game/item")

-- Test 0: tags - raw/unprepared items carry none; prepared items do.
do
    local raw = Item.new("raw_chicken")
    assert(#raw.tags == 0, "raw_chicken should carry no tags, got " .. #raw.tags)

    local cooked = Item.new("baked_chicken")
    assert(#cooked.tags == 1 and cooked.tags[1] == "Protein",
        "baked_chicken should be tagged Protein")

    local broccoli = Item.new("broccoli")
    assert(#broccoli.tags == 0, "raw broccoli should carry no tags")

    local steamed = Item.new("steamed_broccoli")
    assert(#steamed.tags == 2 and steamed.tags[1] == "Healthy" and steamed.tags[2] == "Veggie",
        "steamed_broccoli should be tagged Healthy and Veggie")

    print("PASS: item: raw items carry no tags, prepared items carry their def's tags")
end

-- Test: item.label is set from def.name
do
    local raw = Item.new("raw_chicken")
    assert(raw.label == "Raw Chicken", "raw_chicken label should be 'Raw Meat', got " .. tostring(raw.label))

    local cooked = Item.new("baked_chicken")
    assert(cooked.label == "Baked Chicken", "baked_chicken label should be 'Cooked Meat', got " .. tostring(cooked.label))

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
    assert(started == false, "start_action should return false when the panel has no raw_chicken")
    assert(microwave.action_state["Cook"] == nil, "action_state should not be set when start_action fails")
    print("PASS: item: start_action no-ops without required items in panel")
end

-- Test 3: start_action with required items present starts the timer
-- (returns true).
do
    local microwave = Item.new("microwave")
    local meat = Item.new("raw_chicken")
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
    local meat = Item.new("raw_chicken")
    local started = meat:start_action("Cook")
    assert(started == false, "start_action should return false when the item has no panel")
    print("PASS: item: start_action returns false when item has no panel")
end

-- Test 3d: the microwave's single "Cook" button handles more than one
-- recipe - it auto-matches whichever ingredient is actually present
-- (raw_chicken or broccoli+water in a pot) rather than needing a separate button per recipe.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    local broccoli  = Item.new("broccoli")
    local water     = Item.new("water")
    pot.panel:place(broccoli, 0, 0)
    pot.panel:place(water,    1, 0)
    microwave.panel:place(pot, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a pot of water+broccoli in the microwave")
    assert(microwave.action_state["Cook"].matches[1].recipe.produces.steamed_broccoli == 1,
        "the matched recipe should be the broccoli->steamed_broccoli one")

    microwave:update(3.5) -- past the 3.0s duration
    local pot_items = pot.panel:items()
    assert(#pot_items == 1 and pot_items[1].type_id == "steamed_broccoli",
        "broccoli+water in the pot should have cooked into steamed_broccoli")

    print("PASS: item: Cook auto-matches whichever recipe the panel's contents satisfy")
end

-- Test 3e: start_action returns false when the panel holds nothing that
-- matches ANY of Cook's recipes (not raw_chicken, not broccoli).
do
    local microwave = Item.new("microwave")
    local cooked = Item.new("baked_chicken") -- not an ingredient for any recipe
    microwave.panel:place(cooked, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == false, "Cook should not start when nothing in the panel matches any recipe")
    assert(microwave.action_state["Cook"] == nil, "action_state should stay unset")
    print("PASS: item: start_action returns false when no recipe's requirements are met")
end

-- Test 4: update(dt) advanced past duration transforms matching items in
-- panel from raw_chicken to baked_chicken in place (same cell).
do
    local microwave = Item.new("microwave")
    local meat = Item.new("raw_chicken")
    microwave.panel:place(meat, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "start_action should succeed with raw_chicken in the panel")

    -- Advance short of duration: should not complete yet.
    microwave:update(1.0)
    assert(microwave.action_state["Cook"] ~= nil, "action should still be running before duration elapses")
    local panel_items = microwave.panel:items()
    assert(#panel_items == 1 and panel_items[1].type_id == "raw_chicken",
        "panel should still contain raw_chicken before the action completes")

    -- Advance past duration (3.0s total, action.duration for Cook).
    microwave:update(2.5)

    assert(microwave.action_state["Cook"] == nil, "action_state['Cook'] should be cleared after completion")

    local final_items = microwave.panel:items()
    assert(#final_items == 1, "panel should still contain exactly one item after the action completes")
    assert(final_items[1].type_id == "baked_chicken",
        "panel item should have transformed from raw_chicken to baked_chicken, got " .. tostring(final_items[1].type_id))
    assert(final_items[1].cell_col == 0 and final_items[1].cell_row == 0,
        "baked_chicken should occupy the same cell the raw_chicken was in")
    print("PASS: item: update(dt) past duration transforms raw_chicken into baked_chicken in place")
end

-- Test 5: Item:draw() is nil-safe / does not error when unplaced.
do
    local meat = Item.new("raw_chicken")
    meat:draw() -- should not error even though cell_col/cell_row/grid are nil
    print("PASS: item: draw() does not error for an unplaced item")
end

-- Test 6: container recipe, happy path. A loaded pot sitting inside
-- the microwave's panel cooks into chicken_soup inside the pot's OWN
-- panel, not the microwave's - and the pot itself is never consumed.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    local water    = Item.new("water")
    local raw_chicken = Item.new("raw_chicken")
    pot.panel:place(water, 0, 0)
    pot.panel:place(raw_chicken, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a fully loaded pot in the microwave's panel")

    microwave:update(3.5) -- past the 3.0s duration

    local soup_items = pot.panel:items()
    assert(#soup_items == 1 and soup_items[1].type_id == "chicken_soup",
        "pot's own panel should contain exactly one chicken_soup after cooking")

    local microwave_items = microwave.panel:items()
    assert(#microwave_items == 1 and microwave_items[1].type_id == "pot" and microwave_items[1] == pot,
        "microwave's own panel should still contain only the same (uneaten) pot item")

    print("PASS: item: container recipe cooks a loaded pot's contents into chicken_soup inside its own panel")
end

-- Test 7: container recipe, not satisfied - a pot missing one
-- ingredient (water) does not let Cook start.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    local raw_chicken = Item.new("raw_chicken")
    pot.panel:place(raw_chicken, 0, 0)
    -- No water placed.

    local started = microwave:start_action("Cook")
    assert(started == false, "Cook should not start with a partially loaded pot (missing water)")
    assert(microwave.action_state["Cook"] == nil, "action_state should stay unset when the container recipe isn't satisfied")

    print("PASS: item: container recipe does not fire when the pot is only partially loaded")
end

-- Test 8: container recipe requires the container itself to be present -
-- loose ingredients sitting directly in the microwave's own 2-cell panel
-- (no pot item present) do not satisfy the container recipe. Note:
-- raw_chicken already has its OWN flat, non-container Cook
-- recipe (raw_chicken -> baked_chicken), so placing it loose would start
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

-- Test 9: multiple recipes fire in one press - raw_chicken and potato
-- together in the microwave's (2-wide) panel both cook from a single Cook press.
-- (Broccoli now requires a pot+water and takes the full 2-wide panel on its own,
-- so we use two 1-cell direct recipes to test multi-recipe firing.)
do
    local microwave = Item.new("microwave")
    local meat      = Item.new("raw_chicken")
    local potato    = Item.new("potato")
    microwave.panel:place(meat,   0, 0)
    microwave.panel:place(potato, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with both raw_chicken and potato present")

    microwave:update(3.5) -- past the 3.0s duration

    local items = microwave.panel:items()
    assert(#items == 2, "panel should contain exactly two items after both recipes fire, got " .. #items)

    local has_baked_chicken, has_baked_potato = false, false
    for _, it in ipairs(items) do
        if it.type_id == "baked_chicken" then has_baked_chicken = true end
        if it.type_id == "baked_potato"  then has_baked_potato  = true end
    end
    assert(has_baked_chicken, "panel should contain baked_chicken after the single Cook press")
    assert(has_baked_potato,  "panel should contain baked_potato after the single Cook press")

    print("PASS: item: a single Cook press fires every satisfied recipe (raw_chicken and potato together)")
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

-- Test: container item has a 6x6 panel and no actions.
do
    local c = Item.new("container")
    assert(c.panel ~= nil, "container should have a panel")
    assert(#c.panel:items() == 0, "container panel should start empty")

    local started = c:start_action("Store") -- no actions defined
    assert(started == false, "container has no actions; start_action should always return false")

    -- Place an item in each corner of the 6x6 panel to confirm full dimensions.
    local function place_at(panel, type_id, col, row)
        local it = Item.new(type_id)
        assert(panel:can_place(it, col, row), "should be able to place " .. type_id .. " at " .. col .. "," .. row)
        panel:place(it, col, row)
    end
    place_at(c.panel, "raw_chicken", 0, 0)
    place_at(c.panel, "raw_chicken", 5, 0)
    place_at(c.panel, "raw_chicken", 0, 5)
    place_at(c.panel, "raw_chicken", 5, 5)
    assert(#c.panel:items() == 4, "all four corners of the 6x6 panel should be reachable")

    print("PASS: item: container has a 6x6 panel, no actions, and accepts items in all corners")
end

-- Test 12: a newly created garden has a 3x3 panel that starts empty.
do
    local garden = Item.new("garden")
    assert(garden.panel ~= nil, "garden should have a panel")
    local items = garden.panel:items()
    assert(#items == 0, "garden panel should start empty, got " .. #items)
    print("PASS: item: newly created garden has an empty 3x3 panel")
end

-- Test 13: refill_daily() on a garden (no daily_fill) is a no-op.
do
    local garden = Item.new("garden")
    garden.panel:place(Item.new("onion"), 0, 0)
    assert(#garden.panel:items() == 1, "garden panel should have 1 item before refill")

    garden:refill_daily()
    assert(#garden.panel:items() == 1, "refill_daily() on garden should be a no-op (panel unchanged)")
    print("PASS: item: refill_daily() on a garden with no daily_fill is a no-op")
end

-- Test 14: refill_daily() on an item without daily_fill (e.g. raw_chicken) is a no-op.
do
    local meat = Item.new("raw_chicken")
    -- raw_chicken has no panel and no daily_fill — calling refill_daily() must not error.
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

-- Test: pump action requires nothing and produces one water per use.
do
    local pump = Item.new("pump")
    assert(pump.panel ~= nil, "pump should have a panel")

    local started = pump:start_action("Pump")
    assert(started == true, "Pump action should start on an empty panel (no requires)")

    pump:update(1.5) -- past the 1.0s duration

    local items = pump.panel:items()
    assert(#items == 1 and items[1].type_id == "water",
        "pump should produce one water, got " .. #items .. " items")

    -- Panel is now full (1x1); a second pump action should start (no requires)
    -- but produce nothing since there is no free cell.
    local started2 = pump:start_action("Pump")
    assert(started2 == true, "Pump action should still start when panel is full (no requires check)")

    pump:update(1.5)

    local items2 = pump.panel:items()
    assert(#items2 == 1, "panel should still hold exactly 1 item when full")

    print("PASS: item: pump action produces water regardless of panel state")
end

-- Coffee bean: microwave Cook action turns coffee_bean into roasted_coffee_bean.
do
    local microwave = Item.new("microwave")
    local bean = Item.new("coffee_bean")
    microwave.panel:place(bean, 0, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a coffee_bean in the microwave's panel")

    microwave:update(3.5) -- past the 3.0s duration

    local items = microwave.panel:items()
    assert(#items == 1 and items[1].type_id == "roasted_coffee_bean",
        "coffee_bean should have cooked into roasted_coffee_bean, got " ..
        (items[1] and items[1].type_id or "nothing"))

    print("PASS: item: microwave Cook turns coffee_bean into roasted_coffee_bean")
end

-- Coffee machine: roasted_coffee_bean has no tags (raw ingredient).
do
    local bean = Item.new("roasted_coffee_bean")
    assert(#bean.tags == 0, "roasted_coffee_bean should carry no tags, got " .. #bean.tags)
    print("PASS: item: roasted_coffee_bean carries no tags (raw ingredient)")
end

-- Coffee machine: black_coffee carries Caffeine and Bitter tags.
do
    local coffee = Item.new("black_coffee")
    assert(#coffee.tags == 2, "black_coffee should have exactly 2 tags, got " .. #coffee.tags)
    local has_caffeine, has_bitter = false, false
    for _, t in ipairs(coffee.tags) do
        if t == "Caffeine" then has_caffeine = true end
        if t == "Bitter"   then has_bitter   = true end
    end
    assert(has_caffeine, "black_coffee should have Caffeine tag")
    assert(has_bitter,   "black_coffee should have Bitter tag")
    print("PASS: item: black_coffee carries Caffeine and Bitter tags")
end

-- Coffee machine: Run action requires water + roasted_coffee_bean and
-- produces black_coffee.
do
    local machine = Item.new("coffee_machine")
    assert(machine.panel ~= nil, "coffee_machine should have a panel")

    -- Without ingredients, Run should not start.
    local no_start = machine:start_action("Run")
    assert(no_start == false, "Run should not start with an empty panel")

    -- With only water, still no start.
    local water = Item.new("water")
    machine.panel:place(water, 0, 0)
    local no_start2 = machine:start_action("Run")
    assert(no_start2 == false, "Run should not start with only water (missing roasted_coffee_bean)")

    -- Add roasted_coffee_bean — now it should start.
    local bean = Item.new("roasted_coffee_bean")
    machine.panel:place(bean, 1, 0)

    local started = machine:start_action("Run")
    assert(started == true, "Run should start with water + roasted_coffee_bean in the panel")

    machine:update(3.5) -- past the 3.0s duration

    local items = machine.panel:items()
    assert(#items == 1 and items[1].type_id == "black_coffee",
        "coffee_machine should produce black_coffee after Run completes, got " ..
        (items[1] and items[1].type_id or "nothing"))

    print("PASS: item: coffee_machine Run action brews black_coffee from water + roasted_coffee_bean")
end

-- Coffee machine: 2x2 footprint and 2x2 panel.
do
    local machine = Item.new("coffee_machine")
    local fp = machine:footprint()
    assert(#fp == 4, "coffee_machine footprint should have 4 cells, got " .. #fp)
    assert(machine.panel.cols == 2 and machine.panel.rows == 2,
        "coffee_machine panel should be 2x2")
    print("PASS: item: coffee_machine has 2x2 footprint and 2x2 panel")
end

-- Test: pot container recipe - egg + broccoli in a pot microwaved produces omelette.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    local egg      = Item.new("egg")
    local broccoli = Item.new("broccoli")
    pot.panel:place(egg, 0, 0)
    pot.panel:place(broccoli, 1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with a loaded pot in the microwave's panel")

    microwave:update(3.5) -- past the 3.0s duration

    local pot_items = pot.panel:items()
    assert(#pot_items == 1 and pot_items[1].type_id == "omelette",
        "pot's panel should contain one omelette after cooking, got " .. #pot_items)

    local microwave_items = microwave.panel:items()
    assert(#microwave_items == 1 and microwave_items[1].type_id == "pot" and microwave_items[1] == pot,
        "microwave's panel should still hold the same pot item")

    print("PASS: item: pot container recipe cooks egg + broccoli into omelette")
end

-- Test: omelette has Protein and Healthy tags.
do
    local omelette = Item.new("omelette")
    assert(omelette:has_tag("Protein"), "omelette should have the Protein tag")
    assert(omelette:has_tag("Healthy"), "omelette should have the Healthy tag")
    assert(not omelette:has_tag("Greasy"), "omelette should not have the Greasy tag")
    print("PASS: item: omelette carries Protein and Healthy tags")
end

print("ALL TESTS PASSED")
