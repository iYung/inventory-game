-- lua/game/customer_queue.lua
--
-- Builds the ordered list of customer configs for one game day.
-- On day 1: no restock merchant; all slots are order customers (plus any scripted character).
-- On day 2+: a restock merchant always appears first.
-- On even days a program merchant also appears (different random slot).
-- Remaining slots are rule-based food orders from OrderGen.

local RestockGen        = require("lua/game/restock_gen")
local MerchantGen       = require("lua/game/merchant_gen")
local OrderGen          = require("lua/game/order_gen")
local CHARACTER_SCRIPTS = require("lua/game/data/character_scripts")

local CustomerQueue = {}
CustomerQueue.__index = CustomerQueue

local function make_restock_cfg(program_state)
    return {
        kind       = "restock",
        name       = "Restock Merchant",
        messages   = { "Fresh supplies — help yourself!" },
        stock      = RestockGen.stock(program_state),
        walk_speed = 80,
    }
end

local function make_program_cfg(program_state)
    return {
        kind           = "program",
        name           = "Program Merchant",
        messages       = { "Looking to expand? Take a look." },
        offer          = MerchantGen.offer(program_state),
        program_state  = program_state,
        walk_speed     = 80,
    }
end

local function make_order_cfg(day, program_state)
    local gen = OrderGen.generate(day, program_state)
    return {
        kind             = "order",
        name             = "Customer",
        messages         = { "I'd like to place an order." },
        after_messages   = { "Thanks, that's delicious!" },
        order_rules      = gen.order_rules,
        order_item_count = gen.order_item_count,
        payout           = gen.payout,
        walk_speed       = 80,
    }
end

-- Picks `count` distinct indices from [1, pool_size] without replacement.
local function pick_slots(count, pool_size)
    local indices = {}
    for i = 1, pool_size do indices[i] = i end
    for i = pool_size, pool_size - count + 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    local result = {}
    for i = pool_size - count + 1, pool_size do
        result[#result + 1] = indices[i]
    end
    return result
end

-- Returns the first CHARACTER_SCRIPTS entry that qualifies given day_state,
-- or nil if none do.
local function find_scripted(day_state)
    for _, entry in ipairs(CHARACTER_SCRIPTS) do
        local key = entry.id .. ":" .. entry.chapter
        if not day_state.seen_scripts[key] then
            local prior_ok = true
            for ch = 1, entry.chapter - 1 do
                if not day_state.seen_scripts[entry.id .. ":" .. ch] then
                    prior_ok = false
                    break
                end
            end
            if prior_ok then
                local t = entry.trigger
                local item_ok = true
                if t.item_sold then
                    item_ok = (day_state.total_sold[t.item_sold] or 0) >= (t.count or 1)
                end
                if item_ok then
                    return entry
                end
            end
        end
    end
    return nil
end

-- CustomerQueue.new(day, program_state [, day_state])
-- day: current game day (integer, 1-based)
-- program_state: a ProgramState instance
-- day_state: optional DayState; used for scripted character trigger evaluation
-- Returns a CustomerQueue with self.total set.
function CustomerQueue.new(day, program_state, day_state)
    local self = setmetatable({}, CustomerQueue)

    local lo, hi
    if day <= 4 then
        lo, hi = 3, 3
    elseif day <= 10 then
        lo, hi = 3, 4
    else
        lo, hi = 4, 5
    end
    local total = math.random(lo, hi)
    self.total  = total
    self._index = 0

    local has_restock = (day > 1)
    local has_program = (day % 2 == 0)
    local program_slot = nil
    if has_program then
        program_slot = math.random(2, total)
    end

    self._configs = {}
    for i = 1, total do
        if i == 1 and has_restock then
            self._configs[i] = make_restock_cfg(program_state)
        elseif i == program_slot then
            self._configs[i] = make_program_cfg(program_state)
        else
            self._configs[i] = make_order_cfg(day, program_state)
        end
    end

    -- Scripted character injection
    self.scripted_key      = nil
    self.scripted_no_dismiss = false
    if day_state then
        local entry = find_scripted(day_state)
        if entry then
            local cfg = {
                kind           = "scripted",
                name           = entry.name,
                color          = entry.color,
                icon           = entry.icon,
                no_dismiss     = entry.no_dismiss,
                messages       = entry.messages,
                after_messages = entry.after_messages,
                walk_speed     = 80,
            }
            local insert_at
            if entry.slot == "after_restock" then
                insert_at = has_restock and 2 or 1
            else
                insert_at = math.random(1, #self._configs + 1)
            end
            table.insert(self._configs, insert_at, cfg)
            self.total             = self.total + 1
            self.scripted_key      = entry.id .. ":" .. entry.chapter
            self.scripted_no_dismiss = entry.no_dismiss or false
        end
    end

    return self
end

-- Advances to and returns the next customer config, or nil once exhausted.
function CustomerQueue:next()
    self._index = self._index + 1
    if self._index <= self.total then
        return self._configs[self._index]
    end
    return nil
end

-- Whether next() would return a non-nil config right now.
function CustomerQueue:has_next()
    return self._index < self.total
end

return CustomerQueue
