-- tests/test_item_prices.lua
-- Tests for per-item buy_price / sell_price fields and the draw_labels context
-- parameter added to Grid.

require("lua/headless/stubs")
local item_defs  = require("lua/game/data/item_defs")
local prog_defs  = require("lua/game/data/program_defs")
local Item       = require("lua/game/item")
local Grid       = require("lua/game/grid")
local ItemPanel  = require("lua/game/item_panel")

-- ── item_defs price fields ────────────────────────────────────────────────────

-- Test 1: machine items have buy_price, no sell_price.
do
    local machines = {
        "fryer", "microwave", "pump", "garden", "pot",
        "coop", "incubator", "meat_machine", "barn",
        "milking_center", "cheese_cave", "coffee_machine",
        "container", "garden_book", "microwave_book",
    }
    for _, id in ipairs(machines) do
        local def = item_defs[id]
        assert(def, "item_defs should have entry for " .. id)
        assert(type(def.buy_price) == "number" and def.buy_price > 0,
            id .. " should have a positive buy_price, got " .. tostring(def.buy_price))
        assert(def.sell_price == nil,
            id .. " is a machine and should have no sell_price")
    end
    print("PASS: item_prices: all machine items have buy_price and no sell_price")
end

-- Test 2: raw ingredient items have both buy_price and sell_price.
do
    local raw_ingredients = {
        "raw_chicken", "raw_beef", "broccoli", "potato",
        "water", "coffee_bean", "onion", "egg", "chicken", "cow", "milk",
    }
    for _, id in ipairs(raw_ingredients) do
        local def = item_defs[id]
        assert(def, "item_defs should have entry for " .. id)
        assert(type(def.buy_price) == "number" and def.buy_price > 0,
            id .. " should have a positive buy_price, got " .. tostring(def.buy_price))
        assert(type(def.sell_price) == "number" and def.sell_price > 0,
            id .. " should have a positive sell_price, got " .. tostring(def.sell_price))
    end
    print("PASS: item_prices: raw ingredient items have both buy_price and sell_price")
end

-- Test 3: cooked/output items have sell_price but no buy_price.
do
    local cooked = {
        "baked_chicken", "steak", "fried_chicken", "steamed_broccoli",
        "roasted_coffee_bean", "black_coffee", "fries", "baked_potato",
        "beef_stew", "chicken_soup", "blooming_onion", "onion_soup",
        "boiled_egg", "omelette", "cheese",
    }
    for _, id in ipairs(cooked) do
        local def = item_defs[id]
        assert(def, "item_defs should have entry for " .. id)
        assert(type(def.sell_price) == "number" and def.sell_price > 0,
            id .. " should have a positive sell_price, got " .. tostring(def.sell_price))
        assert(def.buy_price == nil,
            id .. " is a cooked output and should have no buy_price")
    end
    print("PASS: item_prices: cooked output items have sell_price and no buy_price")
end

-- Test 4: sentinel items have neither buy_price nor sell_price.
do
    local sentinels = { "merchant", "order_customer", "book" }
    for _, id in ipairs(sentinels) do
        local def = item_defs[id]
        assert(def, "item_defs should have entry for " .. id)
        assert(def.buy_price == nil,
            id .. " sentinel should have no buy_price")
        assert(def.sell_price == nil,
            id .. " sentinel should have no sell_price")
    end
    print("PASS: item_prices: sentinel items have no buy_price or sell_price")
end

-- Test 5: spot-check specific price values.
do
    assert(item_defs.fryer.buy_price      == 30, "fryer buy_price should be 30")
    assert(item_defs.raw_chicken.buy_price == 3,  "raw_chicken buy_price should be 3")
    assert(item_defs.raw_chicken.sell_price == 5, "raw_chicken sell_price should be 5")
    assert(item_defs.steak.sell_price      == 12, "steak sell_price should be 12")
    assert(item_defs.microwave.buy_price   == 50, "microwave buy_price should be 50")
    assert(item_defs.black_coffee.sell_price == 12, "black_coffee sell_price should be 12")
    print("PASS: item_prices: spot-check price values are correct")
end

-- Test 6: sell_price > buy_price for items that have both (basic sanity).
do
    local both = { "raw_chicken", "raw_beef", "broccoli", "potato", "onion", "egg", "chicken", "cow", "milk" }
    for _, id in ipairs(both) do
        local def = item_defs[id]
        assert(def.sell_price >= def.buy_price,
            id .. " sell_price (" .. def.sell_price .. ") should be >= buy_price (" .. def.buy_price .. ")")
    end
    print("PASS: item_prices: sell_price >= buy_price for all dual-priced items")
end

-- ── program_defs: no cost field ───────────────────────────────────────────────

-- Test 7: program_defs has no cost field on any entry.
do
    for id, def in pairs(prog_defs) do
        assert(def.cost == nil,
            "program_def '" .. id .. "' should have no cost field (price lives on items now)")
    end
    print("PASS: item_prices: program_defs has no cost field on any entry")
end

-- ── ItemPanel: no _paid_programs ─────────────────────────────────────────────

-- Test 8: ItemPanel.new does not initialize _paid_programs.
do
    local microwave = Item.new("microwave")
    local panel = ItemPanel.new(microwave)
    assert(panel._paid_programs == nil,
        "ItemPanel should not have _paid_programs (removed with per-item pricing)")
    assert(panel._machines_placed ~= nil,
        "ItemPanel should still have _machines_placed for program completion tracking")
    print("PASS: item_prices: ItemPanel.new has no _paid_programs, keeps _machines_placed")
end

-- ── Grid.draw_labels context parameter ───────────────────────────────────────

-- Test 9: draw_labels(context) does not error with or without context.
-- The headless stubs no-op all love.graphics calls so we just verify
-- the function signature accepts the parameter without blowing up.
do
    local g = Grid.new(4, 4, 36, 0, 0)
    local item = Item.new("raw_chicken")
    g:place(item, 0, 0)
    g._hover_col = 0
    g._hover_row = 0

    -- Both call forms must succeed without error.
    local ok1, err1 = pcall(function() g:draw_labels() end)
    assert(ok1, "draw_labels() with no context should not error: " .. tostring(err1))

    local ok2, err2 = pcall(function() g:draw_labels("merchant") end)
    assert(ok2, "draw_labels('merchant') should not error: " .. tostring(err2))

    local ok3, err3 = pcall(function() g:draw_labels(nil) end)
    assert(ok3, "draw_labels(nil) should not error: " .. tostring(err3))

    print("PASS: item_prices: draw_labels accepts optional context param without error")
end

-- Test 10: draw_labels works for an item with no price fields (e.g. a machine
-- with only buy_price in merchant context, or a sentinel with no prices).
do
    local g = Grid.new(4, 4, 36, 0, 0)

    -- baked_chicken has sell_price but no buy_price; should render sell price in
    -- non-merchant context, and no price in merchant context (no buy_price).
    local cooked = Item.new("baked_chicken")
    g:place(cooked, 0, 0)
    g._hover_col = 0
    g._hover_row = 0

    local ok1, err1 = pcall(function() g:draw_labels("merchant") end)
    assert(ok1, "draw_labels('merchant') on item with no buy_price should not error: " .. tostring(err1))

    local ok2, err2 = pcall(function() g:draw_labels() end)
    assert(ok2, "draw_labels() on cooked item (sell_price only) should not error: " .. tostring(err2))

    print("PASS: item_prices: draw_labels handles items with partial or no price fields")
end

print("ALL TESTS PASSED")
