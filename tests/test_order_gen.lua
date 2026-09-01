local OrderGen     = require("lua/game/order_gen")
local ProgramState = require("lua/game/program_state")

-- Helper: returns true if at least one combination of `count` items from
-- `outputs` satisfies all rules. Mirrors the satisfiability logic in OrderGen.
local item_defs = require("lua/game/data/item_defs")

local function has_tag(type_id, tag)
    local def = item_defs[type_id]
    if not def or not def.tags then return false end
    for _, t in ipairs(def.tags) do
        if t == tag then return true end
    end
    return false
end

local function is_satisfiable(rules, outputs)
    for _, rule in ipairs(rules) do
        if rule.kind == "no" then
            local any_clean = false
            for _, id in ipairs(outputs) do
                if not has_tag(id, rule.tag) then any_clean = true; break end
            end
            if not any_clean then return false end
        elseif rule.kind == "at_least" then
            local carriers = 0
            for _, id in ipairs(outputs) do
                if has_tag(id, rule.tag) then carriers = carriers + 1 end
            end
            if carriers == 0 then return false end
        elseif rule.kind == "specific" then
            local found = false
            for _, id in ipairs(outputs) do
                if id == rule.type_id then found = true; break end
            end
            if not found then return false end
        elseif rule.kind == "all_unique" then
            -- satisfiable if outputs has enough distinct items
        end
    end
    return true
end

-- Test 1: item count within correct day ranges.
do
    local ps = ProgramState.new("fryer")
    local ranges = {
        { 1,  1, 2 }, { 2,  1, 2 },   -- days 1-2 → 1-2
        { 3,  1, 4 }, { 6,  1, 4 },   -- days 3-6 → 1-4
        { 7,  1, 5 }, { 20, 1, 5 },   -- days 7+  → 1-5
    }
    for _, r in ipairs(ranges) do
        local day, lo, hi = r[1], r[2], r[3]
        for _ = 1, 50 do
            local result = OrderGen.generate(day, ps)
            local c = result.order_item_count
            assert(c >= lo and c <= hi,
                "day " .. day .. " item_count " .. c .. " outside [" .. lo .. "," .. hi .. "]")
        end
    end
    print("PASS: order_gen: item_count within correct range for each day bracket")
end

-- Test 2: rule count within correct day ranges.
do
    local ps = ProgramState.new("fryer")
    -- Days 1-4: rule count 1-2; days 5+: 1-4.
    -- With empty available_tags (fryer unlocks tags), rules can be generated.
    local day_cases = {
        { day = 1, max_rules = 2 },
        { day = 4, max_rules = 2 },
        { day = 5, max_rules = 4 },
        { day = 10, max_rules = 4 },
    }
    for _, c in ipairs(day_cases) do
        for _ = 1, 50 do
            local result = OrderGen.generate(c.day, ps)
            local n = #result.order_rules
            assert(n >= 0 and n <= c.max_rules,
                "day " .. c.day .. " rule_count " .. n .. " exceeds max " .. c.max_rules)
        end
    end
    print("PASS: order_gen: rule_count within correct range for each day bracket")
end

-- Test 3: no rule references a tag outside available_tags.
do
    local ps = ProgramState.new("fryer")
    local avail = ps:available_tags()

    for day = 1, 10 do
        for _ = 1, 20 do
            local result = OrderGen.generate(day, ps)
            for _, rule in ipairs(result.order_rules) do
                if rule.tag then
                    assert(avail[rule.tag],
                        "rule references tag '" .. rule.tag .. "' not in available_tags")
                end
            end
        end
    end
    print("PASS: order_gen: no rule references a tag outside available_tags")
end

-- Test 4: generated order is satisfiable (not provably impossible).
do
    local ps = ProgramState.new("fryer")
    local outputs = ps:available_outputs()

    for day = 1, 10 do
        for _ = 1, 50 do
            local result = OrderGen.generate(day, ps)
            assert(is_satisfiable(result.order_rules, outputs),
                "generated order for day " .. day .. " is not satisfiable")
        end
    end
    print("PASS: order_gen: generated orders are satisfiable")
end

-- Test 5: payout formula is item_count * 10 + max(0, rule_count - 1) * 5.
do
    local ps = ProgramState.new("fryer")
    for day = 1, 15 do
        for _ = 1, 20 do
            local result = OrderGen.generate(day, ps)
            local expected = result.order_item_count * 10 + math.max(0, #result.order_rules - 1) * 5
            assert(result.payout == expected,
                "payout " .. result.payout .. " != expected " .. expected
                .. " (items=" .. result.order_item_count .. " rules=" .. #result.order_rules .. ")")
        end
    end
    print("PASS: order_gen: payout formula is correct")
end

-- Test 6: result always has required fields.
do
    local ps = ProgramState.new("fryer")
    for day = 1, 7 do
        local result = OrderGen.generate(day, ps)
        assert(type(result.order_rules) == "table", "order_rules should be a table")
        assert(type(result.order_item_count) == "number", "order_item_count should be a number")
        assert(type(result.payout) == "number", "payout should be a number")
    end
    print("PASS: order_gen: result always has required fields")
end

-- Test 7: no generated rule set contains same-tag contradictions.
do
    local ps = ProgramState.new("fryer")
    -- Buy every program to maximise available tags and stress the generator.
    local program_defs = require("lua/game/data/program_defs")
    for id, _ in pairs(program_defs) do
        ps:buy(id)
    end

    for day = 1, 15 do
        for _ = 1, 100 do
            local result = OrderGen.generate(day, ps)
            local at_least_n = {}
            local no_more_n  = {}
            local has_no     = {}
            for _, rule in ipairs(result.order_rules) do
                if rule.kind == "at_least" then
                    at_least_n[rule.tag] = rule.n
                elseif rule.kind == "no_more" then
                    no_more_n[rule.tag] = rule.n
                elseif rule.kind == "no" then
                    has_no[rule.tag] = true
                end
            end
            for tag, n in pairs(at_least_n) do
                assert(not has_no[tag],
                    "day " .. day .. ": at_least + no on same tag '" .. tag .. "'")
                if no_more_n[tag] then
                    assert(n <= no_more_n[tag],
                        "day " .. day .. ": at_least " .. n .. " + no_more " .. no_more_n[tag]
                        .. " on tag '" .. tag .. "'")
                end
            end
        end
    end
    print("PASS: order_gen: no contradictory rules on the same tag")
end

print("ALL TESTS PASSED")
