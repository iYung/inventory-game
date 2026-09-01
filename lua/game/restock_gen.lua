-- lua/game/restock_gen.lua
--
-- Generates the stock list for a restock merchant visit.
-- Reads the `inputs` field from each owned program to build the pool,
-- then randomly picks up to 5 distinct items with random quantities.

local program_defs = require("lua/game/data/program_defs")

local RestockGen = {}

local MAX_ITEMS     = 5
local MIN_QUANTITY  = 1
local MAX_QUANTITY  = 4

-- Fisher-Yates shuffle (in place).
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Returns a list of { type_id, quantity } tables for the restock merchant.
-- program_state: a ProgramState instance.
function RestockGen.stock(program_state)
    -- Collect union of inputs across all owned programs, deduped.
    local seen = {}
    local pool = {}
    for id, def in pairs(program_defs) do
        if program_state:owns(id) then
            for _, type_id in ipairs(def.inputs) do
                if not seen[type_id] then
                    seen[type_id] = true
                    pool[#pool + 1] = type_id
                end
            end
        end
    end

    shuffle(pool)

    local result = {}
    local count  = math.min(MAX_ITEMS, #pool)
    for i = 1, count do
        result[#result + 1] = {
            type_id  = pool[i],
            quantity = math.random(MIN_QUANTITY, MAX_QUANTITY),
        }
    end
    return result
end

return RestockGen
