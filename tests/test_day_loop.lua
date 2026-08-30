local CustomerQueue = require("lua/game/customer_queue")
local DayState      = require("lua/game/day_state")

-- Test 1: CustomerQueue exhausts after N next() calls, each returning a
-- config table with the expected fields; has_next() flips false once
-- exhausted.
--
-- Deviation from the original version of this test: CustomerQueue.new()
-- now mixes exactly one random merchant config in among the order configs
-- (see docs/design/merchant-npc.md), so configs are no longer all
-- identical. Each returned config is checked against the fields expected
-- for its own kind rather than assuming every slot is a food-order config;
-- merchant-specific field coverage lives in Test 1b below.
do
    local q = CustomerQueue.new(3)
    assert(q.total == 3, "total should be stored")

    for i = 1, 3 do
        assert(q:has_next(), "has_next() should be true before customer " .. i)
        local cfg = q:next()
        assert(cfg ~= nil, "next() should return a config table for customer " .. i)
        assert(type(cfg.messages) == "table" and #cfg.messages > 0, "config should have non-empty messages")
        assert(type(cfg.walk_speed) == "number", "config should have a numeric walk_speed")

        if cfg.kind == "merchant" then
            assert(cfg.name == "Merchant", "merchant config should have name Merchant")
        else
            assert(cfg.name == "Customer", "order config should have a name field")
            assert(cfg.requested_type == "cooked_meat", "order config should have requested_type field")
            assert(type(cfg.after_messages) == "table" and #cfg.after_messages > 0, "order config should have non-empty after_messages")
        end
    end

    assert(not q:has_next(), "has_next() should be false once exhausted")
    local cfg4 = q:next()
    assert(cfg4 == nil, "next() should return nil once exhausted")

    print("PASS: customer_queue: next() yields N configs then nil, has_next() tracks exhaustion")
end

-- Test 1b: CustomerQueue.new(total) mixes in exactly one merchant config
-- among the food-order configs, for several values of total (including
-- total == 1, where the single slot must still always be the merchant).
-- Position is random (math.random(1, total)) so we assert on counts, not
-- on which index holds the merchant.
do
    for _, total in ipairs({ 1, 3, 5 }) do
        local q = CustomerQueue.new(total)

        local merchant_count = 0
        local order_count    = 0
        local drained        = 0

        while q:has_next() do
            local cfg = q:next()
            assert(cfg ~= nil, "next() should return a config while has_next() is true")
            drained = drained + 1

            if cfg.kind == "merchant" then
                merchant_count = merchant_count + 1

                assert(cfg.name == "Merchant", "merchant config should be named Merchant")
                assert(type(cfg.messages) == "table" and #cfg.messages > 0,
                    "merchant config should have non-empty messages")
                assert(type(cfg.walk_speed) == "number", "merchant config should have a numeric walk_speed")

                assert(type(cfg.stock) == "table", "merchant config should have a stock list")
                local counts = {}
                for _, item_type in ipairs(cfg.stock) do
                    counts[item_type] = (counts[item_type] or 0) + 1
                end
                assert(counts.raw_meat == 2, "merchant stock should contain exactly 2 raw_meat")
                assert(counts.cooked_meat == 1, "merchant stock should contain exactly 1 cooked_meat")
                local total_stock = 0
                for _ in pairs(counts) do total_stock = total_stock + 1 end
                assert(total_stock == 2, "merchant stock should only contain raw_meat and cooked_meat entries")
            else
                order_count = order_count + 1
                assert(cfg.kind == nil or cfg.kind == "order",
                    "non-merchant config should have no kind field, or kind == 'order'")
            end
        end

        assert(drained == total, "queue of total " .. total .. " should drain exactly " .. total .. " configs")
        assert(merchant_count == 1,
            "queue of total " .. total .. " should contain exactly one merchant config, got " .. merchant_count)
        assert(order_count == total - 1,
            "queue of total " .. total .. " should contain total-1 order configs, got " .. order_count)
    end

    print("PASS: customer_queue: new(total) always mixes in exactly one merchant config among order configs")
end

-- Test 1c: the merchant slot is actually randomly positioned, not
-- hardcoded to a fixed index — across enough trials with total > 1, the
-- merchant should land at more than one distinct index. Uses a decent
-- trial count to keep this robust against coincidental non-variation.
do
    local total  = 5
    local trials = 200
    local seen_indices = {}

    for _ = 1, trials do
        local q = CustomerQueue.new(total)
        local i = 0
        while q:has_next() do
            i = i + 1
            local cfg = q:next()
            if cfg.kind == "merchant" then
                seen_indices[i] = true
            end
        end
    end

    local distinct = 0
    for _ in pairs(seen_indices) do distinct = distinct + 1 end
    assert(distinct > 1,
        "merchant slot should vary across runs (saw " .. distinct .. " distinct index/indices over " .. trials .. " trials)")

    print("PASS: customer_queue: merchant slot position varies across multiple new() calls")
end

-- Test 2: DayState tracks day/customers_served/customers_total/currency
-- across start_day, record_serve, record_dismiss, day_complete, and
-- advance_day.
do
    local ds = DayState.new()
    assert(ds.day == 1, "day should start at 1")
    assert(ds.customers_served == 0, "customers_served should start at 0")
    assert(ds.customers_total == 0, "customers_total should start at 0")
    assert(ds.currency == 0, "currency should start at 0")

    ds:start_day(3)
    assert(ds.customers_total == 3, "start_day should set customers_total")
    assert(ds.customers_served == 0, "start_day should reset customers_served")
    assert(not ds:day_complete(), "day_complete() should be false right after start_day(3)")

    ds:record_serve()
    assert(ds.customers_served == 1, "record_serve should increment customers_served")
    assert(ds.currency == 10, "record_serve should award currency")
    assert(not ds:day_complete(), "day_complete() should still be false after 1 of 3")

    ds:record_serve()
    assert(ds.customers_served == 2, "record_serve should increment customers_served again")
    assert(ds.currency == 20, "currency should reflect only the 2 serves so far")
    assert(not ds:day_complete(), "day_complete() should still be false after 2 of 3")

    ds:record_dismiss()
    assert(ds.customers_served == 3, "record_dismiss should also increment customers_served")
    assert(ds.currency == 20, "record_dismiss should NOT change currency (still 20, not 30)")
    assert(ds:day_complete(), "day_complete() should be true once customers_served >= customers_total")

    ds:advance_day()
    assert(ds.day == 2, "advance_day should bump day from 1 to 2")
    assert(ds.customers_served == 0, "advance_day should reset customers_served to 0")
    -- Deviation from the checklist's literal wording: advance_day() does NOT
    -- construct/return a fresh CustomerQueue and does NOT reset
    -- customers_total — it only bumps day and resets customers_served.
    -- customers_total is left untouched here (still 3 from the prior
    -- start_day call), so day_complete() reflects that unchanged total.
    assert(ds.customers_total == 3, "advance_day should leave customers_total untouched (caller's job via start_day)")
    assert(not ds:day_complete(), "day_complete() should be false again after advance_day resets customers_served")

    print("PASS: day_state: start_day/record_serve/record_dismiss/day_complete/advance_day track day progress correctly")
end

print("ALL TESTS PASSED")
