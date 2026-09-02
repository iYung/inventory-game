local CustomerQueue = require("lua/game/customer_queue")
local ProgramState  = require("lua/game/program_state")
local item_defs     = require("lua/game/data/item_defs")

-- Test 1: total respects day-based ramp (days 1-4: 3, days 5-10: 3-4, days 11+: 4-5).
do
    local ps = ProgramState.new("fryer")
    local cases = {
        { day = 1,  lo = 3, hi = 3 },
        { day = 4,  lo = 3, hi = 3 },
        { day = 5,  lo = 3, hi = 4 },
        { day = 10, lo = 3, hi = 4 },
        { day = 11, lo = 4, hi = 5 },
        { day = 20, lo = 4, hi = 5 },
    }
    for _, c in ipairs(cases) do
        for _ = 1, 30 do
            local q = CustomerQueue.new(c.day, ps)
            assert(q.total >= c.lo and q.total <= c.hi,
                "day " .. c.day .. " total " .. q.total .. " outside [" .. c.lo .. "," .. c.hi .. "]")
        end
    end
    print("PASS: customer_queue: total respects day-based ramp")
end

-- Test 2: day 1 has no restock merchant; days 2+ always have exactly one.
do
    local ps = ProgramState.new("fryer")
    -- day 1: no restock
    for _ = 1, 10 do
        local q = CustomerQueue.new(1, ps)
        local restock_count = 0
        while q:has_next() do
            local cfg = q:next()
            if cfg.kind == "restock" then restock_count = restock_count + 1 end
        end
        assert(restock_count == 0, "day 1 should have no restock merchant, got " .. restock_count)
    end
    -- days 2-4: exactly one restock
    for day = 2, 4 do
        for _ = 1, 10 do
            local q = CustomerQueue.new(day, ps)
            local restock_count = 0
            while q:has_next() do
                local cfg = q:next()
                if cfg.kind == "restock" then restock_count = restock_count + 1 end
            end
            assert(restock_count == 1,
                "day " .. day .. " should have exactly 1 restock merchant, got " .. restock_count)
        end
    end
    print("PASS: customer_queue: day 1 no restock; days 2+ exactly one restock merchant")
end

-- Test 3: odd days have no program merchant.
do
    local ps = ProgramState.new("fryer")
    for _, day in ipairs({ 1, 3, 5, 7, 9 }) do
        for _ = 1, 10 do
            local q = CustomerQueue.new(day, ps)
            local prog_count = 0
            while q:has_next() do
                local cfg = q:next()
                if cfg.kind == "program" then prog_count = prog_count + 1 end
            end
            assert(prog_count == 0,
                "odd day " .. day .. " should have 0 program merchants, got " .. prog_count)
        end
    end
    print("PASS: customer_queue: odd days have no program merchant")
end

-- Test 4: even days have exactly one program merchant.
do
    local ps = ProgramState.new("fryer")
    for _, day in ipairs({ 2, 4, 6, 8, 10 }) do
        for _ = 1, 10 do
            local q = CustomerQueue.new(day, ps)
            local prog_count = 0
            while q:has_next() do
                local cfg = q:next()
                if cfg.kind == "program" then prog_count = prog_count + 1 end
            end
            assert(prog_count == 1,
                "even day " .. day .. " should have 1 program merchant, got " .. prog_count)
        end
    end
    print("PASS: customer_queue: even days have exactly one program merchant")
end

-- Test 5: all non-merchant slots are order customers.
do
    local ps = ProgramState.new("fryer")
    for day = 1, 4 do
        for _ = 1, 10 do
            local q = CustomerQueue.new(day, ps)
            local drained = 0
            while q:has_next() do
                local cfg = q:next()
                drained = drained + 1
                if cfg.kind ~= "restock" and cfg.kind ~= "program" and cfg.kind ~= "scripted" then
                    assert(cfg.kind == "order",
                        "non-merchant slot should have kind='order' or 'scripted', got '" .. tostring(cfg.kind) .. "'")
                    assert(type(cfg.order_rules) == "table", "order cfg should have order_rules")
                    assert(type(cfg.order_item_count) == "number", "order cfg should have order_item_count")
                    assert(type(cfg.payout) == "number", "order cfg should have payout")
                end
            end
            assert(drained == q.total, "drained " .. drained .. " != q.total " .. q.total)
        end
    end
    print("PASS: customer_queue: all non-merchant slots are well-formed order customers")
end

-- Test 6: restock merchant config has well-formed stock list (day 2+ only).
do
    local ps = ProgramState.new("fryer")
    for day = 2, 2 do
        for _ = 1, 10 do
            local q = CustomerQueue.new(day, ps)
            while q:has_next() do
                local cfg = q:next()
                if cfg.kind == "restock" then
                    assert(type(cfg.stock) == "table", "restock cfg should have stock table")
                    for _, entry in ipairs(cfg.stock) do
                        assert(type(entry.type_id) == "string" and entry.type_id ~= "",
                            "restock stock entry should have a type_id string")
                        assert(type(entry.quantity) == "number" and entry.quantity >= 1,
                            "restock stock entry should have quantity >= 1")
                    end
                end
            end
        end
    end
    print("PASS: customer_queue: restock merchant has well-formed stock entries")
end

-- Test 7: program merchant config has well-formed offer list.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 10 do
        local q = CustomerQueue.new(2, ps)  -- even day
        while q:has_next() do
            local cfg = q:next()
            if cfg.kind == "program" then
                assert(type(cfg.offer) == "table", "program cfg should have offer table")
                assert(#cfg.offer >= 2 and #cfg.offer <= 4,
                    "program offer should have 2-4 entries, got " .. #cfg.offer)
                for _, prog in ipairs(cfg.offer) do
                    assert(type(prog.id) == "string", "program entry should have id")
                    -- Program cost now lives on each machine item's own def
                    -- (buy_price), not on the program def itself.
                    for _, machine_type_id in ipairs(prog.machines or {}) do
                        local def = item_defs[machine_type_id]
                        assert(def and type(def.buy_price) == "number",
                            "program machine '" .. machine_type_id .. "' should have a buy_price")
                    end
                end
            end
        end
    end
    print("PASS: customer_queue: program merchant has well-formed offer list")
end

-- Test 8: all customer configs use config.WALK_SPEED (no hardcoded 80).
do
    local config = require("lua/game/config")
    local ps = ProgramState.new("fryer")
    for _, day in ipairs({ 1, 2 }) do
        for _ = 1, 5 do
            local q = CustomerQueue.new(day, ps)
            while q:has_next() do
                local cfg = q:next()
                assert(cfg.walk_speed == config.WALK_SPEED,
                    "kind='" .. cfg.kind .. "' walk_speed=" .. tostring(cfg.walk_speed) ..
                    " expected " .. config.WALK_SPEED)
            end
        end
    end
    print("PASS: customer_queue: all customer kinds use config.WALK_SPEED")
end

print("ALL TESTS PASSED")
