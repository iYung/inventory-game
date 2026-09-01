local RestockGen   = require("lua/game/restock_gen")
local ProgramState = require("lua/game/program_state")
local program_defs = require("lua/game/data/program_defs")

-- Build the union of inputs from owned programs for comparison.
local function expected_pool(ps)
    local seen = {}
    for id, def in pairs(program_defs) do
        if ps:owns(id) then
            for _, type_id in ipairs(def.inputs) do
                seen[type_id] = true
            end
        end
    end
    return seen
end

-- Test 1: returns ≤ 5 items.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 20 do
        local stock = RestockGen.stock(ps)
        assert(#stock <= 5, "stock should have at most 5 entries, got " .. #stock)
    end
    print("PASS: restock_gen: returns at most 5 items")
end

-- Test 2: all returned type_ids are in the owned-programs input pool.
do
    local ps = ProgramState.new("fryer")
    ps:buy("garden")
    ps:buy("pump_microwave")
    local pool = expected_pool(ps)

    for _ = 1, 30 do
        local stock = RestockGen.stock(ps)
        for _, entry in ipairs(stock) do
            assert(pool[entry.type_id],
                "type_id '" .. entry.type_id .. "' not in owned-program input pool")
        end
    end
    print("PASS: restock_gen: all returned type_ids are in the owned-programs input pool")
end

-- Test 3: quantities are in [1, 4].
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 30 do
        local stock = RestockGen.stock(ps)
        for _, entry in ipairs(stock) do
            assert(type(entry.quantity) == "number", "quantity should be a number")
            assert(entry.quantity >= 1 and entry.quantity <= 4,
                "quantity should be in [1,4], got " .. entry.quantity)
        end
    end
    print("PASS: restock_gen: quantities are in [1, 4]")
end

-- Test 4: no duplicate type_ids in a single stock call.
do
    local ps = ProgramState.new("fryer")
    ps:buy("garden"); ps:buy("pump_microwave"); ps:buy("pot")
    for _ = 1, 30 do
        local stock = RestockGen.stock(ps)
        local seen = {}
        for _, entry in ipairs(stock) do
            assert(not seen[entry.type_id],
                "type_id '" .. entry.type_id .. "' appeared twice in one stock call")
            seen[entry.type_id] = true
        end
    end
    print("PASS: restock_gen: no duplicate type_ids within one stock call")
end

-- Test 5: when pool has fewer than 5 items, take all (no padding).
do
    -- Fryer inputs: raw_chicken, potato, onion — exactly 3 items.
    local ps = ProgramState.new("fryer")
    local pool = expected_pool(ps)
    local pool_size = 0
    for _ in pairs(pool) do pool_size = pool_size + 1 end

    if pool_size < 5 then
        for _ = 1, 10 do
            local stock = RestockGen.stock(ps)
            assert(#stock == pool_size,
                "when pool has " .. pool_size .. " items, stock should also have "
                .. pool_size .. ", got " .. #stock)
        end
        print("PASS: restock_gen: when pool < 5 items, returns all of them")
    else
        print("SKIP: restock_gen pool-size < 5 test (pool is already ≥ 5 for fryer alone)")
    end
end

-- Test 6: coffee_machine program restock pool includes coffee_bean and
-- does NOT include roasted_coffee_bean (which was replaced by coffee_bean).
do
    local ps = ProgramState.new("fryer")
    ps:buy("pump_microwave")
    ps:buy("coffee_machine")

    local pool = expected_pool(ps)
    assert(pool["coffee_bean"],
        "restock pool should include coffee_bean when coffee_machine program is owned")
    assert(not pool["roasted_coffee_bean"],
        "restock pool should NOT include roasted_coffee_bean for the coffee_machine program")

    print("PASS: restock_gen: coffee_machine program pools coffee_bean, not roasted_coffee_bean")
end

print("ALL TESTS PASSED")
