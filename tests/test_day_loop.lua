local CustomerQueue = require("lua/game/customer_queue")
local DayState      = require("lua/game/day_state")

-- Test 1: CustomerQueue exhausts after N next() calls, each returning a
-- config table with the expected fields; has_next() flips false once
-- exhausted.
do
    local q = CustomerQueue.new(3)
    assert(q.total == 3, "total should be stored")

    for i = 1, 3 do
        assert(q:has_next(), "has_next() should be true before customer " .. i)
        local cfg = q:next()
        assert(cfg ~= nil, "next() should return a config table for customer " .. i)
        assert(cfg.name == "Customer", "config should have a name field")
        assert(cfg.requested_type == "cooked_meat", "config should have requested_type field")
        assert(type(cfg.messages) == "table" and #cfg.messages > 0, "config should have non-empty messages")
        assert(type(cfg.after_messages) == "table" and #cfg.after_messages > 0, "config should have non-empty after_messages")
        assert(type(cfg.walk_speed) == "number", "config should have a numeric walk_speed")
    end

    assert(not q:has_next(), "has_next() should be false once exhausted")
    local cfg4 = q:next()
    assert(cfg4 == nil, "next() should return nil once exhausted")

    print("PASS: customer_queue: next() yields N configs then nil, has_next() tracks exhaustion")
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
