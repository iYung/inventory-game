-- lua/game/customer_queue.lua
--
-- Builds the ordered list of customer configs for one game day.
-- One restock merchant always appears (random slot).
-- On even days a program merchant also appears (different random slot).
-- Remaining slots are rule-based food orders from OrderGen.

local config       = require("lua/game/config")
local RestockGen   = require("lua/game/restock_gen")
local MerchantGen  = require("lua/game/merchant_gen")
local OrderGen     = require("lua/game/order_gen")

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
        kind     = "program",
        name     = "Program Merchant",
        messages = { "Looking to expand? Take a look." },
        offer    = MerchantGen.offer(program_state),
        walk_speed = 80,
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

-- CustomerQueue.new(day, program_state)
-- day: current game day (integer, 1-based)
-- program_state: a ProgramState instance
-- Returns a CustomerQueue with self.total set.
function CustomerQueue.new(day, program_state)
    local self = setmetatable({}, CustomerQueue)

    local total = math.random(config.MIN_CUSTOMERS_PER_DAY, config.MAX_CUSTOMERS_PER_DAY)
    self.total  = total
    self._index = 0

    -- Decide which slots are merchants.
    local has_program = (day % 2 == 0)
    local merchant_count = has_program and 2 or 1

    local merchant_slots = pick_slots(merchant_count, total)
    local restock_slot = merchant_slots[1]
    local program_slot = merchant_slots[2]  -- nil if has_program is false

    self._configs = {}
    for i = 1, total do
        if i == restock_slot then
            self._configs[i] = make_restock_cfg(program_state)
        elseif i == program_slot then
            self._configs[i] = make_program_cfg(program_state)
        else
            self._configs[i] = make_order_cfg(day, program_state)
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
