local CustomerQueue = require("lua/game/customer_queue")
local DayState      = require("lua/game/day_state")
local ProgramState  = require("lua/game/program_state")

-- Helper: drain a queue and return all configs as a list.
local function drain(q)
    local out = {}
    while q:has_next() do
        out[#out + 1] = q:next()
    end
    return out
end

-- Helper: count configs with a given kind.
local function count_kind(configs, kind)
    local n = 0
    for _, c in ipairs(configs) do
        if c.kind == kind then n = n + 1 end
    end
    return n
end

-- Test a: Day 1 has no restock merchant.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 20 do
        local q    = CustomerQueue.new(1, ps)
        local cfgs = drain(q)
        assert(count_kind(cfgs, "restock") == 0,
            "day 1 should have no restock merchant")
    end
    print("PASS: character_scripts: day 1 has no restock merchant")
end

-- Test b: Qualifying script (guide ch1, empty trigger) inserted at slot 2
--         on day 2 (after_restock → index 2, right after the restock merchant).
do
    local ps = ProgramState.new("fryer")
    local ds = DayState.new()  -- seen_scripts={}, total_sold={}

    for _ = 1, 20 do
        local q    = CustomerQueue.new(2, ps, ds)
        local cfgs = drain(q)

        assert(count_kind(cfgs, "scripted") == 1,
            "day 2 with fresh day_state should insert exactly 1 scripted customer")
        assert(cfgs[1].kind == "restock",
            "slot 1 on day 2 should be the restock merchant")
        assert(cfgs[2].kind == "scripted",
            "slot 2 on day 2 should be the scripted customer (after_restock)")
        assert(cfgs[2].name == "The Guide",
            "scripted customer should be The Guide")
    end
    print("PASS: character_scripts: guide ch1 inserted at slot 2 on day 2")
end

-- Test c: When ch1 is unseen, ch2 is blocked; ch1 fires instead (ch1 has
--         empty trigger so it always qualifies regardless of total_sold).
do
    local ps = ProgramState.new("fryer")
    local ds = DayState.new()
    ds.total_sold = { fried_chicken = 5 }  -- ch2 item_sold condition met, but ch1 unseen

    local q    = CustomerQueue.new(2, ps, ds)
    local cfgs = drain(q)

    -- ch1 has no prerequisites and an empty trigger, so it fires.
    -- ch2 requires ch1 seen first, so it's blocked.
    assert(count_kind(cfgs, "scripted") == 1,
        "should have exactly 1 scripted customer when ch1 unseen")
    local scripted_cfg
    for _, c in ipairs(cfgs) do
        if c.kind == "scripted" then scripted_cfg = c; break end
    end
    assert(scripted_cfg ~= nil, "scripted config should exist")
    assert(q.scripted_key == "guide:1",
        "scripted_key should be guide:1 (ch2 blocked, ch1 fires); got " .. tostring(q.scripted_key))
    print("PASS: character_scripts: ch2 blocked when ch1 unseen; ch1 fires instead")
end

-- Test d: item_sold count gates ch2 correctly.
do
    local ps = ProgramState.new("fryer")

    -- With ch1 seen but zero fried_chicken sold: ch2 should NOT fire.
    local ds_no_sales = DayState.new()
    ds_no_sales.seen_scripts = { ["guide:1"] = true }
    ds_no_sales.total_sold   = {}

    local q1 = CustomerQueue.new(2, ps, ds_no_sales)
    assert(q1.scripted_key == nil,
        "ch2 should not fire when fried_chicken total_sold is 0")

    -- With ch1 seen and at least 1 fried_chicken sold: ch2 fires.
    local ds_with_sales = DayState.new()
    ds_with_sales.seen_scripts = { ["guide:1"] = true }
    ds_with_sales.total_sold   = { fried_chicken = 1 }

    local q2 = CustomerQueue.new(2, ps, ds_with_sales)
    assert(q2.scripted_key == "guide:2",
        "ch2 should fire when fried_chicken total_sold >= 1; got " .. tostring(q2.scripted_key))

    print("PASS: character_scripts: item_sold count gates ch2 correctly")
end

-- Test e: DayState.total_sold accumulates across advance_day(); sold_items resets.
do
    local ds = DayState.new()

    ds:record_serve({ "fried_chicken" }, 10)
    assert(ds.total_sold["fried_chicken"] == 1, "total_sold should be 1 after first serve")
    assert(ds.sold_items["fried_chicken"] == 1, "sold_items should be 1 after first serve")

    ds:advance_day()
    assert(ds.sold_items["fried_chicken"] == nil,
        "sold_items should reset to nil after advance_day")
    assert(ds.total_sold["fried_chicken"] == 1,
        "total_sold should still be 1 after advance_day")

    ds:record_serve({ "fried_chicken" }, 10)
    assert(ds.total_sold["fried_chicken"] == 2,
        "total_sold should be 2 after second serve across days")
    assert(ds.sold_items["fried_chicken"] == 1,
        "sold_items should be 1 (day 2 only)")

    print("PASS: character_scripts: total_sold accumulates across advance_day; sold_items resets")
end

print("ALL TESTS PASSED")
