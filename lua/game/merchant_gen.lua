-- lua/game/merchant_gen.lua
--
-- Generates the program list shown by a program merchant.
-- Step 1: 2-3 randomly chosen programs not yet owned whose requires are all met.
-- Step 2: fill remaining slots (up to 4 total) with randomly chosen owned programs
--         for repurchase.

local program_defs = require("lua/game/data/program_defs")

local MerchantGen = {}

local MAX_SLOTS     = 3
local MIN_NEW       = 1
local MAX_NEW       = 2

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Returns a list of program def tables (up to 4) to display in the program
-- merchant panel. program_state: a ProgramState instance.
function MerchantGen.offer(program_state)
    local available    = {}  -- not owned, prereqs met
    local repurchasable = {} -- already owned

    for id, def in pairs(program_defs) do
        if program_state:owns(id) then
            repurchasable[#repurchasable + 1] = def
        else
            -- Check all requires are satisfied.
            local ok = true
            for _, req in ipairs(def.requires) do
                if not program_state:owns(req) then
                    ok = false
                    break
                end
            end
            if ok then
                available[#available + 1] = def
            end
        end
    end

    shuffle(available)
    shuffle(repurchasable)

    local result   = {}
    local new_count = math.min(math.random(MIN_NEW, MAX_NEW), #available)
    for i = 1, new_count do
        result[#result + 1] = available[i]
    end

    local remaining = MAX_SLOTS - #result
    for i = 1, math.min(remaining, #repurchasable) do
        result[#result + 1] = repurchasable[i]
    end

    return result
end

return MerchantGen
