-- lua/game/program_state.lua
--
-- Tracks which programs the player owns. Drives available_tags (used by
-- OrderGen) and available_outputs (used by OrderGen's specific-rule source).

local program_defs = require("lua/game/data/program_defs")
local item_defs    = require("lua/game/data/item_defs")

local ProgramState = {}
ProgramState.__index = ProgramState

function ProgramState.new(starting)
    local self = setmetatable({}, ProgramState)
    self._owned = {}
    if type(starting) == "string" then
        self._owned[starting] = true
    elseif type(starting) == "table" then
        for _, id in ipairs(starting) do
            self._owned[id] = true
        end
    end
    return self
end

function ProgramState:owns(id)
    return self._owned[id] == true
end

function ProgramState:buy(id)
    self._owned[id] = true
end

-- Returns a set (table keyed tag → true) of every tag unlocked by currently
-- owned programs.
function ProgramState:available_tags()
    local tags = {}
    for id, _ in pairs(self._owned) do
        local def = program_defs[id]
        if def then
            for _, tag in ipairs(def.tags_unlocked) do
                tags[tag] = true
            end
        end
    end
    return tags
end

-- Returns a list of type_ids that owned machines can produce as outputs.
-- Reads `produces` keys from item_defs actions and overnight_actions on each
-- machine type owned by any owned program. Used as the pool for `specific`
-- order rules.
function ProgramState:available_outputs()
    local seen    = {}
    local outputs = {}

    -- Collect all machine type_ids from owned programs.
    local machines = {}
    for id, _ in pairs(self._owned) do
        local def = program_defs[id]
        if def then
            for _, machine_id in ipairs(def.machines) do
                machines[machine_id] = true
            end
        end
    end

    local function collect_produces(produces_tbl)
        for type_id, _ in pairs(produces_tbl) do
            if not seen[type_id] then
                seen[type_id] = true
                outputs[#outputs + 1] = type_id
            end
        end
    end

    for machine_id, _ in pairs(machines) do
        local def = item_defs[machine_id]
        if def then
            for _, action in ipairs(def.actions or {}) do
                for _, recipe in ipairs(action.recipes or {}) do
                    if recipe.produces then collect_produces(recipe.produces) end
                end
                -- action-level produces (e.g. pump)
                if action.produces then collect_produces(action.produces) end
            end
            for _, action in ipairs(def.overnight_actions or {}) do
                if action.produces then collect_produces(action.produces) end
            end
        end
    end

    return outputs
end

return ProgramState
