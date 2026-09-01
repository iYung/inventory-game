-- tests/test_overnight.lua
-- Tests for Item:overnight_tick() and the meat_machine Process action.

require("lua/headless/stubs")
local Item = require("lua/game/item")

-- Helper: count items of a given type_id in a panel.
local function count_type(panel, type_id)
    local n = 0
    for _, it in ipairs(panel:items()) do
        if it.type_id == type_id then n = n + 1 end
    end
    return n
end

-- Test 1: coop with a chicken produces an egg after one overnight_tick.
do
    local coop    = Item.new("coop")
    local chicken = Item.new("chicken")
    coop.panel:place(chicken, 0, 0)

    coop:overnight_tick()

    local eggs    = count_type(coop.panel, "egg")
    local chickens = count_type(coop.panel, "chicken")
    assert(eggs == 1,    "coop should produce 1 egg after one tick, got " .. eggs)
    assert(chickens == 1, "coop should still contain the chicken after ticking, got " .. chickens)

    print("PASS: overnight: coop produces an egg overnight when a chicken is inside")
end

-- Test 2: incubator does NOT hatch after just one tick (needs 2 nights).
do
    local incubator = Item.new("incubator")
    local egg       = Item.new("egg")
    incubator.panel:place(egg, 0, 0)

    incubator:overnight_tick()

    local eggs    = count_type(incubator.panel, "egg")
    local chickens = count_type(incubator.panel, "chicken")
    assert(eggs == 1,    "incubator should still contain the egg after one tick, got " .. eggs)
    assert(chickens == 0, "incubator should NOT produce a chicken after only one tick, got " .. chickens)

    print("PASS: overnight: incubator does not hatch after one tick")
end

-- Test 3: incubator hatches a chicken after two ticks.
do
    local incubator = Item.new("incubator")
    local egg       = Item.new("egg")
    incubator.panel:place(egg, 0, 0)

    incubator:overnight_tick()
    incubator:overnight_tick()

    local eggs    = count_type(incubator.panel, "egg")
    local chickens = count_type(incubator.panel, "chicken")
    assert(eggs == 0,    "incubator should have consumed the egg after two ticks, got " .. eggs)
    assert(chickens == 1, "incubator should produce a chicken after two ticks, got " .. chickens)

    print("PASS: overnight: incubator hatches a chicken after two ticks")
end

-- Test 4: incubator resets progress when the egg is removed mid-incubation.
do
    local incubator = Item.new("incubator")
    local egg       = Item.new("egg")
    incubator.panel:place(egg, 0, 0)

    -- First tick: progress reaches 1 (needs 2 to hatch).
    incubator:overnight_tick()
    assert(count_type(incubator.panel, "chicken") == 0, "should not hatch after tick 1")

    -- Remove the egg: requirements no longer satisfied on next tick.
    incubator.panel:remove(egg)
    incubator:overnight_tick()  -- progress should reset to 0

    -- Re-add the egg and tick once more: only 1 night of progress again.
    local egg2 = Item.new("egg")
    incubator.panel:place(egg2, 0, 0)
    incubator:overnight_tick()

    local chickens = count_type(incubator.panel, "chicken")
    assert(chickens == 0,
        "incubator should not hatch after egg was removed and re-added (progress reset), got " .. chickens)
    assert(count_type(incubator.panel, "egg") == 1, "egg should still be in incubator")

    print("PASS: overnight: incubator resets progress when egg is removed mid-incubation")
end

-- Test 5: meat_machine Process action consumes chicken and produces 2 raw_chicken.
do
    local mm      = Item.new("meat_machine")
    local chicken = Item.new("chicken")
    mm.panel:place(chicken, 0, 0)

    local started = mm:start_action("Process")
    assert(started == true, "Process should start when a chicken is in the panel")

    mm:update(1.0)  -- duration is 1.0s

    local chickens  = count_type(mm.panel, "chicken")
    local raw_chickens = count_type(mm.panel, "raw_chicken")
    assert(chickens == 0,   "chicken should be consumed by Process, got " .. chickens)
    assert(raw_chickens == 2,  "Process should produce 2 raw_chicken, got " .. raw_chickens)

    print("PASS: overnight: meat_machine Process turns 1 chicken into 2 raw_chicken")
end

-- Test 6: overnight_tick is a no-op on items without overnight_actions.
do
    local microwave = Item.new("microwave")
    local before    = #microwave.panel:items()
    microwave:overnight_tick()
    local after     = #microwave.panel:items()
    assert(before == after, "overnight_tick on microwave should be a no-op")

    local raw = Item.new("raw_chicken")
    raw:overnight_tick()  -- no panel, should not error

    print("PASS: overnight: overnight_tick is a no-op on items without overnight_actions")
end

-- Test 7: water + egg in a pot microwaved produces a boiled_egg.
do
    local microwave = Item.new("microwave")
    local pot       = Item.new("pot")
    microwave.panel:place(pot, 0, 0)

    pot.panel:place(Item.new("water"), 0, 0)
    pot.panel:place(Item.new("egg"),   1, 0)

    local started = microwave:start_action("Cook")
    assert(started == true, "Cook should start with water+egg in pot")

    microwave:update(3.0)  -- Cook duration is 3.0s

    local boiled = count_type(pot.panel, "boiled_egg")
    local water  = count_type(pot.panel, "water")
    local eggs   = count_type(pot.panel, "egg")
    assert(boiled == 1, "pot should contain 1 boiled_egg after cooking, got " .. boiled)
    assert(water  == 0, "water should be consumed, got " .. water)
    assert(eggs   == 0, "egg should be consumed, got " .. eggs)

    print("PASS: boiled egg: water + egg in pot microwaved produces boiled_egg (Protein)")
end

-- Test 8: a single onion at center (1,1) spreads to all 4 orthogonal neighbors.
do
    local garden = Item.new("garden")
    garden.panel:place(Item.new("onion"), 1, 1)

    garden:overnight_tick()

    local onions = count_type(garden.panel, "onion")
    assert(onions == 5,
        "onion at center should spread to 4 neighbors (5 total), got " .. onions)
    assert(garden.panel:item_at(1, 0) ~= nil, "onion should spread to (1,0)")
    assert(garden.panel:item_at(0, 1) ~= nil, "onion should spread to (0,1)")
    assert(garden.panel:item_at(2, 1) ~= nil, "onion should spread to (2,1)")
    assert(garden.panel:item_at(1, 2) ~= nil, "onion should spread to (1,2)")

    print("PASS: garden spread: onion at center spreads to all 4 orthogonal neighbors")
end

-- Test 9: broccoli at corner (0,0) spreads only to its 2 in-bounds neighbors.
do
    local garden = Item.new("garden")
    garden.panel:place(Item.new("broccoli"), 0, 0)

    garden:overnight_tick()

    local broccolis = count_type(garden.panel, "broccoli")
    assert(broccolis == 3,
        "broccoli at corner should spread to 2 in-bounds neighbors (3 total), got " .. broccolis)
    assert(garden.panel:item_at(1, 0) ~= nil, "broccoli should spread to (1,0)")
    assert(garden.panel:item_at(0, 1) ~= nil, "broccoli should spread to (0,1)")

    print("PASS: garden spread: broccoli at corner spreads to exactly 2 in-bounds neighbors")
end

-- Test 10: a fully-occupied 3x3 garden (9 onions) does not error; count stays 9.
do
    local garden = Item.new("garden")
    for r = 0, 2 do
        for c = 0, 2 do
            garden.panel:place(Item.new("onion"), c, r)
        end
    end

    garden:overnight_tick()

    local onions = count_type(garden.panel, "onion")
    assert(onions == 9,
        "fully-occupied garden should still have 9 onions after tick, got " .. onions)

    print("PASS: garden spread: fully-occupied panel does not error and count stays 9")
end

-- Test 11: onion and broccoli spread independently without cross-type contamination.
do
    local garden = Item.new("garden")
    garden.panel:place(Item.new("onion"),   0, 0)
    garden.panel:place(Item.new("broccoli"), 2, 2)

    garden:overnight_tick()

    -- Verify onion positions: original (0,0) and neighbors (1,0) and (0,1).
    local function type_at(panel, col, row)
        local it = panel:item_at(col, row)
        return it and it.type_id or nil
    end

    assert(type_at(garden.panel, 0, 0) == "onion",    "(0,0) should be onion")
    assert(type_at(garden.panel, 1, 0) == "onion",    "(1,0) should be onion")
    assert(type_at(garden.panel, 0, 1) == "onion",    "(0,1) should be onion")
    assert(type_at(garden.panel, 2, 2) == "broccoli", "(2,2) should be broccoli")
    assert(type_at(garden.panel, 1, 2) == "broccoli", "(1,2) should be broccoli")
    assert(type_at(garden.panel, 2, 1) == "broccoli", "(2,1) should be broccoli")

    local onions    = count_type(garden.panel, "onion")
    local broccolis = count_type(garden.panel, "broccoli")
    assert(onions    == 3, "should be 3 onions, got " .. onions)
    assert(broccolis == 3, "should be 3 broccoli, got " .. broccolis)

    print("PASS: garden spread: onion and broccoli spread independently without interference")
end

-- Test 12: overnight_tick on an empty garden panel is a no-op.
do
    local garden = Item.new("garden")

    garden:overnight_tick()

    local total = #garden.panel:items()
    assert(total == 0,
        "empty garden panel should remain empty after tick, got " .. total)

    print("PASS: garden spread: overnight_tick on empty garden panel is a no-op")
end

-- Test 13: potato spreads in the garden like onion/broccoli.
do
    local garden = Item.new("garden")
    garden.panel:place(Item.new("potato"), 1, 1)

    garden:overnight_tick()

    local potatoes = count_type(garden.panel, "potato")
    assert(potatoes == 5, "potato at center should spread to 4 neighbors (5 total), got " .. potatoes)

    print("PASS: garden spread: potato at center spreads to all 4 orthogonal neighbors")
end

-- Test 14: coop with 2 chickens produces 2 eggs overnight.
do
    local coop = Item.new("coop")
    coop.panel:place(Item.new("chicken"), 0, 0)
    coop.panel:place(Item.new("chicken"), 1, 0)

    coop:overnight_tick()

    local eggs    = count_type(coop.panel, "egg")
    local chickens = count_type(coop.panel, "chicken")
    assert(eggs == 2,    "coop with 2 chickens should produce 2 eggs, got " .. eggs)
    assert(chickens == 2, "both chickens should remain in the coop, got " .. chickens)

    print("PASS: coop: 2 chickens produce 2 eggs overnight")
end

-- Test 15: coop with 3 chickens and only 1 free cell produces 1 egg (space-capped).
do
    local coop = Item.new("coop")
    -- 2x2 panel; fill 3 cells with chickens, leaving 1 free
    coop.panel:place(Item.new("chicken"), 0, 0)
    coop.panel:place(Item.new("chicken"), 1, 0)
    coop.panel:place(Item.new("chicken"), 0, 1)
    -- (1,1) is free

    coop:overnight_tick()

    local eggs    = count_type(coop.panel, "egg")
    local chickens = count_type(coop.panel, "chicken")
    assert(eggs == 1,    "coop with 3 chickens and 1 free cell should produce 1 egg, got " .. eggs)
    assert(chickens == 3, "all 3 chickens should remain in the coop, got " .. chickens)

    print("PASS: coop: 3 chickens with 1 free cell produce 1 egg (space-capped)")
end

-- Test 16: coop with no chickens produces no eggs.
do
    local coop = Item.new("coop")

    coop:overnight_tick()

    local eggs = count_type(coop.panel, "egg")
    assert(eggs == 0, "empty coop should produce no eggs, got " .. eggs)

    print("PASS: coop: empty coop produces no eggs overnight")
end

-- Test 17: barn with 2 cows produces 1 new cow overnight.
do
    local barn = Item.new("barn")
    barn.panel:place(Item.new("cow"), 0, 0)
    barn.panel:place(Item.new("cow"), 2, 0)

    barn:overnight_tick()

    local cows = count_type(barn.panel, "cow")
    assert(cows == 3, "barn with 2 cows should produce 1 new cow (total 3), got " .. cows)

    print("PASS: barn: 2 cows produce 1 new cow overnight")
end

-- Test 18: barn with 4 cows produces 2 new cows overnight.
do
    local barn = Item.new("barn")
    barn.panel:place(Item.new("cow"), 0, 0)
    barn.panel:place(Item.new("cow"), 2, 0)
    barn.panel:place(Item.new("cow"), 4, 0)
    barn.panel:place(Item.new("cow"), 0, 2)

    barn:overnight_tick()

    local cows = count_type(barn.panel, "cow")
    assert(cows == 6, "barn with 4 cows should produce 2 new cows (total 6), got " .. cows)

    print("PASS: barn: 4 cows produce 2 new cows overnight")
end

-- Test 19: barn with 1 cow produces no new cows (requires 2).
do
    local barn = Item.new("barn")
    barn.panel:place(Item.new("cow"), 0, 0)

    barn:overnight_tick()

    local cows = count_type(barn.panel, "cow")
    assert(cows == 1, "barn with 1 cow should produce no new cows, got " .. cows)

    print("PASS: barn: 1 cow produces no new cows (requirement not met)")
end

-- Test 20: barn with 8 cows and only one 2x2 free slot produces 1 new cow (space-capped).
-- 8 cows at positions (0,0),(2,0),(4,0),(0,2),(2,2),(4,2),(0,4),(2,4) fill
-- 32 of 36 cells; only the 2x2 block at (4,4) remains free.
-- floor(8/2) = 4 new cows attempted; only 1 fits.
do
    local barn = Item.new("barn")
    local positions = { {0,0},{2,0},{4,0},{0,2},{2,2},{4,2},{0,4},{2,4} }
    for _, pos in ipairs(positions) do
        barn.panel:place(Item.new("cow"), pos[1], pos[2])
    end

    barn:overnight_tick()

    local cows = count_type(barn.panel, "cow")
    assert(cows == 9, "barn with 8 cows and 1 free 2x2 slot should produce 1 new cow (total 9), got " .. cows)

    print("PASS: barn: 8 cows with 1 free slot produce 1 new cow (space-capped)")
end

-- Test: milking_center with 1 cow produces 2 milk overnight (cow preserved).
do
    local mc  = Item.new("milking_center")
    local cow = Item.new("cow")
    mc.panel:place(cow, 0, 0)

    mc:overnight_tick()

    local milks = count_type(mc.panel, "milk")
    local cows  = count_type(mc.panel, "cow")
    assert(milks == 2,  "milking_center with 1 cow should produce 2 milk, got " .. milks)
    assert(cows  == 1,  "cow should be preserved in milking_center, got " .. cows)

    print("PASS: milking_center: 1 cow produces 2 milk overnight (cow preserved)")
end

-- Test: milking_center with 2 cows produces 4 milk overnight.
-- (4x3 panel; each cow is 2x2; 2 cows fill rows 0-1, row 2 holds the 4 milk.)
do
    local mc = Item.new("milking_center")
    mc.panel:place(Item.new("cow"), 0, 0)
    mc.panel:place(Item.new("cow"), 2, 0)

    mc:overnight_tick()

    local milks = count_type(mc.panel, "milk")
    local cows  = count_type(mc.panel, "cow")
    assert(milks == 4, "milking_center with 2 cows should produce 4 milk, got " .. milks)
    assert(cows  == 2, "both cows should be preserved, got " .. cows)

    print("PASS: milking_center: 2 cows produce 4 milk overnight")
end

-- Test: milking_center with no cows produces no milk.
do
    local mc = Item.new("milking_center")

    mc:overnight_tick()

    local milks = count_type(mc.panel, "milk")
    assert(milks == 0, "empty milking_center should produce no milk, got " .. milks)

    print("PASS: milking_center: empty milking_center produces no milk overnight")
end

-- Test: cheese_cave with 1 milk converts to 1 cheese overnight (milk consumed).
do
    local cave = Item.new("cheese_cave")
    cave.panel:place(Item.new("milk"), 0, 0)

    cave:overnight_tick()

    local cheeses = count_type(cave.panel, "cheese")
    local milks   = count_type(cave.panel, "milk")
    assert(cheeses == 1, "cheese_cave with 1 milk should produce 1 cheese, got " .. cheeses)
    assert(milks   == 0, "milk should be consumed by cheese_cave, got " .. milks)

    print("PASS: cheese_cave: 1 milk converts to 1 cheese overnight")
end

-- Test: cheese_cave with 4 milks converts all to cheese overnight.
do
    local cave = Item.new("cheese_cave")
    cave.panel:place(Item.new("milk"), 0, 0)
    cave.panel:place(Item.new("milk"), 1, 0)
    cave.panel:place(Item.new("milk"), 0, 1)
    cave.panel:place(Item.new("milk"), 1, 1)

    cave:overnight_tick()

    local cheeses = count_type(cave.panel, "cheese")
    local milks   = count_type(cave.panel, "milk")
    assert(cheeses == 4, "cheese_cave with 4 milks should produce 4 cheeses, got " .. cheeses)
    assert(milks   == 0, "all milk should be consumed, got " .. milks)

    print("PASS: cheese_cave: 4 milks all convert to cheese overnight")
end

-- Test: cheese_cave with no milk is a no-op.
do
    local cave = Item.new("cheese_cave")

    cave:overnight_tick()

    local cheeses = count_type(cave.panel, "cheese")
    assert(cheeses == 0, "empty cheese_cave should produce no cheese, got " .. cheeses)

    print("PASS: cheese_cave: empty cheese_cave is a no-op overnight")
end

print("ALL OVERNIGHT TESTS PASSED")
