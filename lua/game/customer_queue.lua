-- lua/game/customer_queue.lua
--
-- Holds an ordered list of customer config tables for a single day (the
-- shape expected by Customer:show(cfg) — see lua/game/customer.lua).
-- MVP: every customer in the queue is identical.

local CustomerQueue = {}
CustomerQueue.__index = CustomerQueue

local function make_default_cfg()
    return {
        name            = "Customer",
        requested_type  = "cooked_meat",
        messages        = { "Could I get some cooked meat?" },
        after_messages  = { "Thanks, that's delicious!" },
        walk_speed      = 80,
    }
end

-- Builds a queue of `total` customer configs.
function CustomerQueue.new(total)
    local self = setmetatable({}, CustomerQueue)

    self.total    = total
    self._index   = 0
    self._configs = {}
    for i = 1, total do
        self._configs[i] = make_default_cfg()
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
