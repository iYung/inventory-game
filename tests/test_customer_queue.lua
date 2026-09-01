local CustomerQueue = require("lua/game/customer_queue")
local ProgramState  = require("lua/game/program_state")
local config        = require("lua/game/config")

-- Test 1: total is 4-6.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 50 do
        local q = CustomerQueue.new(1, ps)
        assert(q.total >= config.MIN_CUSTOMERS_PER_DAY and q.total <= config.MAX_CUSTOMERS_PER_DAY,
            "total " .. q.total .. " outside [" .. config.MIN_CUSTOMERS_PER_DAY
            .. "," .. config.MAX_CUSTOMERS_PER_DAY .. "]")
    end
    print("PASS: customer_queue: total is always in [4, 6]")
end

-- Test 2: always contains exactly one restock merchant.
do
    local ps = ProgramState.new("fryer")
    for day = 1, 4 do
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
    print("PASS: customer_queue: always exactly one restock merchant per day")
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
                if cfg.kind ~= "restock" and cfg.kind ~= "program" then
                    assert(cfg.kind == "order",
                        "non-merchant slot should have kind='order', got '" .. tostring(cfg.kind) .. "'")
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

-- Test 6: restock merchant config has well-formed stock list.
do
    local ps = ProgramState.new("fryer")
    for day = 1, 2 do
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
                    assert(type(prog.cost) == "number", "program entry should have cost")
                end
            end
        end
    end
    print("PASS: customer_queue: program merchant has well-formed offer list")
end

print("ALL TESTS PASSED")
