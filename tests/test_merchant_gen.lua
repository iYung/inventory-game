local MerchantGen  = require("lua/game/merchant_gen")
local ProgramState = require("lua/game/program_state")
local program_defs = require("lua/game/data/program_defs")
local item_defs     = require("lua/game/data/item_defs")

-- Test 1: returns 2-4 entries total.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 30 do
        local offer = MerchantGen.offer(ps)
        assert(#offer >= 2 and #offer <= 4,
            "offer should have 2-4 entries, got " .. #offer)
    end
    print("PASS: merchant_gen: offer has 2-4 entries")
end

-- Test 2: new-program entries are not yet owned and have all prereqs met.
do
    local ps = ProgramState.new("fryer")
    for _ = 1, 30 do
        local offer = MerchantGen.offer(ps)
        for _, prog in ipairs(offer) do
            if not ps:owns(prog.id) then
                -- All requires must be satisfied.
                for _, req in ipairs(prog.requires or {}) do
                    assert(ps:owns(req),
                        "unowned program '" .. prog.id .. "' has unsatisfied prereq '" .. req .. "'")
                end
            end
        end
    end
    print("PASS: merchant_gen: unowned programs in offer all have prerequisites satisfied")
end

-- Test 3: repurchase entries (if any) are owned programs.
do
    local ps = ProgramState.new("fryer")
    ps:buy("garden")
    ps:buy("pump_microwave")

    for _ = 1, 30 do
        local offer = MerchantGen.offer(ps)
        for _, prog in ipairs(offer) do
            -- Either it's not owned (a new offer) or it is owned (repurchase) — both valid.
            -- What's NOT valid: an owned program appearing as if it were a new offer when
            -- it should only ever appear as repurchase. We just verify the table is well-formed.
            assert(type(prog.id) == "string" and prog.id ~= "", "prog.id should be a non-empty string")
            assert(type(prog.name) == "string", "prog.name should be a string")
            -- Program cost now lives on each machine item's own def
            -- (buy_price), not on the program def itself.
            for _, machine_type_id in ipairs(prog.machines or {}) do
                local def = item_defs[machine_type_id]
                assert(def and type(def.buy_price) == "number",
                    "program machine '" .. machine_type_id .. "' should have a buy_price")
            end
        end
    end
    print("PASS: merchant_gen: all offer entries have well-formed program def fields")
end

-- Test 4: step-1 count (new programs) is 2-3 when enough are available.
do
    -- With only fryer owned, garden/pump_microwave/coffee_machine are all available (prereqs = fryer).
    -- So step 1 should pick 2-3 of them.
    local ps = ProgramState.new("fryer")
    local min_new, max_new = math.huge, 0
    for _ = 1, 100 do
        local offer = MerchantGen.offer(ps)
        local new_count = 0
        for _, prog in ipairs(offer) do
            if not ps:owns(prog.id) then new_count = new_count + 1 end
        end
        if new_count < min_new then min_new = new_count end
        if new_count > max_new then max_new = new_count end
    end
    assert(min_new >= 2, "step-1 should pick at least 2 new programs, min saw " .. min_new)
    assert(max_new <= 3, "step-1 should pick at most 3 new programs, max saw " .. max_new)
    print("PASS: merchant_gen: step-1 picks 2-3 new programs")
end

-- Test 5: no program appears twice in the same offer.
do
    local ps = ProgramState.new("fryer")
    ps:buy("garden")
    for _ = 1, 30 do
        local offer = MerchantGen.offer(ps)
        local seen = {}
        for _, prog in ipairs(offer) do
            assert(not seen[prog.id], "program '" .. prog.id .. "' appeared twice in one offer")
            seen[prog.id] = true
        end
    end
    print("PASS: merchant_gen: no program appears twice in one offer")
end

print("ALL TESTS PASSED")
