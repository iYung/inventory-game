-- lua/game/day_state.lua
--
-- Tracks per-day progress (day number, customers served/total, currency).
-- Deliberately does NOT know about CustomerQueue — keeping the two classes
-- independently testable. The caller (integration code, Wave 3) is
-- responsible for constructing a CustomerQueue and calling
-- DayState:start_day(total) whenever it starts a new day, including right
-- after DayState:advance_day().

local DayState = {}
DayState.__index = DayState

function DayState.new()
    local self = setmetatable({}, DayState)

    self.day              = 1
    self.customers_served = 0
    self.customers_total  = 0
    self.currency         = 0
    self.sold_items       = {}

    return self
end

-- Called by the caller whenever a day's CustomerQueue is (re)created: sets
-- the total customer count for the day and resets the served counter.
function DayState:start_day(total)
    self.customers_total  = total
    self.customers_served = 0
end

-- Happy path: items matched the order. Awards payout currency.
-- items: list of type_id strings; payout: integer currency to add.
function DayState:record_serve(items, payout)
    self.customers_served = self.customers_served + 1
    self.currency         = self.currency + (payout or 10)
    for _, type_id in ipairs(items or {}) do
        self.sold_items[type_id] = (self.sold_items[type_id] or 0) + 1
    end
end

-- Failure path: wrong item / send-away. No currency awarded.
function DayState:record_dismiss()
    self.customers_served = self.customers_served + 1
end

function DayState:day_complete()
    return self.customers_served >= self.customers_total
end

-- Bumps the day counter and resets customers_served to 0. Does NOT touch
-- customers_total and does NOT construct a new CustomerQueue — the caller
-- must separately build a fresh CustomerQueue.new(config.CUSTOMERS_PER_DAY)
-- and call start_day(config.CUSTOMERS_PER_DAY) to fully set up the new day.
function DayState:advance_day()
    self.day              = self.day + 1
    self.customers_served = 0
    self.sold_items       = {}
end

return DayState
