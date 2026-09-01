local ProgramState = require("lua/game/program_state")

-- Test 1: starts with starting program owned; others are not.
do
    local ps = ProgramState.new("fryer")
    assert(ps:owns("fryer"), "fryer should be owned at start")
    assert(not ps:owns("garden"), "garden should not be owned at start")
    assert(not ps:owns("pot"), "pot should not be owned at start")
    print("PASS: program_state: starts with only the starting program owned")
end

-- Test 2: buy() marks a program as owned.
do
    local ps = ProgramState.new("fryer")
    assert(not ps:owns("garden"), "garden not owned before buy")
    ps:buy("garden")
    assert(ps:owns("garden"), "garden should be owned after buy")
    print("PASS: program_state: buy() marks program as owned")
end

-- Test 3: buy() is idempotent.
do
    local ps = ProgramState.new("fryer")
    ps:buy("garden")
    ps:buy("garden")
    assert(ps:owns("garden"), "double buy should still leave garden owned")
    print("PASS: program_state: buy() is idempotent")
end

-- Test 4: available_tags() returns union of tags_unlocked across owned programs.
do
    local ps = ProgramState.new("fryer")
    -- Fryer unlocks Greasy and Protein.
    local tags = ps:available_tags()
    assert(type(tags) == "table", "available_tags() should return a table")
    assert(tags["Greasy"], "fryer should unlock Greasy tag")
    assert(tags["Protein"], "fryer should unlock Protein tag")
    assert(not tags["Healthy"], "Healthy should not be available without pot")

    -- Adding pump_microwave (which also unlocks Filling and Protein) doesn't break.
    ps:buy("pump_microwave")
    local tags2 = ps:available_tags()
    assert(tags2["Greasy"], "Greasy still available after buying pump_microwave")
    assert(tags2["Filling"], "Filling should be unlocked by pump_microwave")

    print("PASS: program_state: available_tags() returns union across owned programs")
end

-- Test 5: available_outputs() returns only items producible from owned machines.
do
    local ps = ProgramState.new("fryer")
    local outputs = ps:available_outputs()
    assert(type(outputs) == "table", "available_outputs() should return a table")
    -- Fryer produces fried_chicken and fries (check at least one exists).
    local has_output = #outputs > 0
    assert(has_output, "fryer should produce at least one output")
    print("PASS: program_state: available_outputs() returns producible items for owned machines")
end

print("ALL TESTS PASSED")
