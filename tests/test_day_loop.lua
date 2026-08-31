local CustomerQueue = require("lua/game/customer_queue")
local DayState      = require("lua/game/day_state")
local item_defs     = require("lua/game/data/item_defs")

-- Mirrors customer_queue.lua's own known_tags()/TAG_MESSAGES scan, kept
-- separately here on purpose: assertions below check the real code's
-- output against this independently-derived expectation rather than a
-- hardcoded literal, so this test doesn't need updating if a tag is
-- added/removed in item_defs later.
local function known_tags()
    local seen, tags = {}, {}
    for _, def in pairs(item_defs) do
        for _, tag in ipairs(def.tags or {}) do
            if not seen[tag] then
                seen[tag] = true
                tags[#tags + 1] = tag
            end
        end
    end
    table.sort(tags)
    return tags
end

local TAG_MESSAGES = {
    Protein = "Could I get something with protein?",
    Healthy = "Could I get something healthy?",
}

local function expected_message_for_tag(tag)
    return TAG_MESSAGES[tag] or ('Could I get something tagged "' .. tag .. '"?')
end

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

            local tags = known_tags()
            local function all_in_pool(tier)
                for _, t in ipairs(tier) do
                    local found = false
                    for _, tag in ipairs(tags) do if t == tag then found = true end end
                    if not found then return false end
                end
                return true
            end
            assert(type(cfg.loved_tags) == "table" and #cfg.loved_tags >= 1, "order config should have at least one loved_tag")
            assert(all_in_pool(cfg.loved_tags), "all loved_tags should be tags present in item_defs")
            assert(type(cfg.liked_tags) == "table", "order config should have a liked_tags table")
            assert(all_in_pool(cfg.liked_tags), "all liked_tags should be tags present in item_defs")
            assert(type(cfg.disliked_tags) == "table", "order config should have a disliked_tags table")
            assert(all_in_pool(cfg.disliked_tags), "all disliked_tags should be tags present in item_defs")

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
                assert(counts.raw_chicken == 2, "merchant stock should contain exactly 2 raw_chicken")
                assert(counts.broccoli and counts.broccoli >= 1, "merchant stock should contain broccoli")
                assert(counts.water and counts.water >= 1, "merchant stock should contain water")
                assert(counts.potato and counts.potato >= 1, "merchant stock should contain potato")
                assert(counts.baked_chicken == nil, "merchant stock should not offer baked_chicken (raw ingredients only)")
                local total_stock = 0
                for _ in pairs(counts) do total_stock = total_stock + 1 end
                assert(total_stock == 4, "merchant stock should only contain raw_chicken, broccoli, water, and potato entries")
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

-- Test 1d: across many CustomerQueue.new() draws, every order config's
-- trait-tier invariant holds (all tags in loved/liked/disliked_tags are
-- valid item_defs tags, no tag appears in more than one tier, and
-- messages[1] is non-empty), and the merchant config's stock always
-- contains broccoli. Also confirms that loved_tags vary across trials.
do
    local total  = 5
    local trials = 50
    local seen_loved = {}

    local function all_valid(tier)
        local tags = known_tags()
        for _, t in ipairs(tier) do
            local ok = false
            for _, tag in ipairs(tags) do if t == tag then ok = true end end
            if not ok then return false end
        end
        return true
    end

    local function no_overlap(loved, liked, disliked)
        local seen = {}
        for _, t in ipairs(loved)    do if seen[t] then return false end seen[t] = true end
        for _, t in ipairs(liked)    do if seen[t] then return false end seen[t] = true end
        for _, t in ipairs(disliked) do if seen[t] then return false end seen[t] = true end
        return true
    end

    for _ = 1, trials do
        local q = CustomerQueue.new(total)
        while q:has_next() do
            local cfg = q:next()
            if cfg.kind == "merchant" then
                local has_broccoli, has_baked_chicken = false, false
                for _, item_type in ipairs(cfg.stock) do
                    if item_type == "broccoli" then has_broccoli = true end
                    if item_type == "baked_chicken" then has_baked_chicken = true end
                end
                assert(has_broccoli, "merchant config's stock should contain broccoli")
                assert(not has_baked_chicken, "merchant config's stock should never contain baked_chicken")
            else
                assert(type(cfg.loved_tags) == "table" and #cfg.loved_tags >= 1,
                    "order config should have at least one loved_tag")
                assert(all_valid(cfg.loved_tags),    "all loved_tags should be tags present in item_defs")
                assert(all_valid(cfg.liked_tags),    "all liked_tags should be tags present in item_defs")
                assert(all_valid(cfg.disliked_tags), "all disliked_tags should be tags present in item_defs")
                assert(no_overlap(cfg.loved_tags, cfg.liked_tags, cfg.disliked_tags),
                    "no tag should appear in more than one tier")
                assert(type(cfg.messages) == "table" and type(cfg.messages[1]) == "string" and #cfg.messages[1] > 0,
                    "order config's messages[1] should be a non-empty string")
                seen_loved[cfg.loved_tags[1]] = true
            end
        end
    end

    local distinct = 0
    for _ in pairs(seen_loved) do distinct = distinct + 1 end
    assert(distinct > 1,
        "loved_tags[1] should vary across runs (saw " .. distinct .. " distinct tag(s) over " .. trials .. " trials)")

    print("PASS: customer_queue: trait-tier invariant holds and varies across many new() draws; merchant stock always has broccoli")
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

    ds:record_serve("baked_chicken")
    assert(ds.customers_served == 1, "record_serve should increment customers_served")
    assert(ds.currency == 10, "record_serve should award currency")
    assert(not ds:day_complete(), "day_complete() should still be false after 1 of 3")

    ds:record_serve("baked_chicken")
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

-- Test 3: DayState.sold_items tallies served item types and resets on advance_day.
do
    local ds = DayState.new()
    assert(type(ds.sold_items) == "table", "sold_items should be initialized as a table")

    ds:start_day(4)
    ds:record_serve("baked_chicken")
    ds:record_serve("baked_chicken")
    ds:record_serve("steamed_broccoli")
    ds:record_dismiss()

    assert(ds.sold_items["baked_chicken"] == 2, "sold_items should tally baked_chicken × 2")
    assert(ds.sold_items["steamed_broccoli"] == 1, "sold_items should tally steamed_broccoli × 1")
    assert(ds.sold_items["baked_potato"] == nil, "unsold items should not appear in sold_items")

    ds:advance_day()
    assert(next(ds.sold_items) == nil, "advance_day should clear sold_items")

    print("PASS: day_state: sold_items tallies served types and clears on advance_day")
end

print("ALL TESTS PASSED")
