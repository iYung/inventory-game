local CustomerQueue  = require("lua/game/customer_queue")
local DayState       = require("lua/game/day_state")
local ProgramState   = require("lua/game/program_state")

-- Smoke test for CustomerQueue with the new API.
-- Full coverage (generator output, slot counts, rule validation) lives in
-- tests/test_customer_queue.lua (Task 18).
do
    local ps = ProgramState.new("fryer")

    -- Day 1: only a restock merchant slot (odd day)
    local q1 = CustomerQueue.new(1, ps)
    assert(type(q1.total) == "number" and q1.total >= 4 and q1.total <= 6,
        "queue total should be 4-6")
    assert(q1:has_next(), "has_next() should be true before first next()")

    local kinds = {}
    while q1:has_next() do
        local cfg = q1:next()
        assert(cfg ~= nil, "next() should return a config while has_next() is true")
        assert(type(cfg.kind) == "string", "each config should have a kind field")
        assert(type(cfg.messages) == "table" and #cfg.messages > 0,
            "each config should have non-empty messages")
        kinds[cfg.kind] = (kinds[cfg.kind] or 0) + 1
    end
    assert(q1:next() == nil, "next() should return nil once exhausted")
    assert(not q1:has_next(), "has_next() should be false once exhausted")
    assert(kinds["restock"] == 1, "day 1 queue should contain exactly one restock merchant")
    assert(kinds["program"] == nil, "day 1 queue should not contain a program merchant")

    -- Day 2: restock + program merchant (even day)
    local q2 = CustomerQueue.new(2, ps)
    local kinds2 = {}
    while q2:has_next() do
        local cfg = q2:next()
        kinds2[cfg.kind] = (kinds2[cfg.kind] or 0) + 1
    end
    assert(kinds2["restock"] == 1, "day 2 queue should contain exactly one restock merchant")
    assert(kinds2["program"] == 1, "day 2 queue should contain exactly one program merchant")

    print("PASS: customer_queue: smoke test — next()/has_next(), slot counts by day parity")
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

    ds:record_serve({"baked_chicken"}, 10)
    assert(ds.customers_served == 1, "record_serve should increment customers_served")
    assert(ds.currency == 10, "record_serve should award currency")
    assert(not ds:day_complete(), "day_complete() should still be false after 1 of 3")

    ds:record_serve({"baked_chicken"}, 10)
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
    assert(ds.customers_total == 3, "advance_day should leave customers_total untouched (caller's job via start_day)")
    assert(not ds:day_complete(), "day_complete() should be false again after advance_day resets customers_served")

    print("PASS: day_state: start_day/record_serve/record_dismiss/day_complete/advance_day track day progress correctly")
end

-- Test 3: DayState.sold_items tallies served item types and resets on advance_day.
do
    local ds = DayState.new()
    assert(type(ds.sold_items) == "table", "sold_items should be initialized as a table")

    ds:start_day(4)
    ds:record_serve({"baked_chicken"}, 10)
    ds:record_serve({"baked_chicken"}, 10)
    ds:record_serve({"steamed_broccoli"}, 10)
    ds:record_dismiss()

    assert(ds.sold_items["baked_chicken"] == 2, "sold_items should tally baked_chicken × 2")
    assert(ds.sold_items["steamed_broccoli"] == 1, "sold_items should tally steamed_broccoli × 1")
    assert(ds.sold_items["baked_potato"] == nil, "unsold items should not appear in sold_items")

    ds:advance_day()
    assert(next(ds.sold_items) == nil, "advance_day should clear sold_items")

    print("PASS: day_state: sold_items tallies served types and clears on advance_day")
end

print("ALL TESTS PASSED")
