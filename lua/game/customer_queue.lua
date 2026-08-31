-- lua/game/customer_queue.lua
--
-- Holds an ordered list of customer config tables for a single day (the
-- shape expected by Customer:show(cfg) — see lua/game/customer.lua).
-- MVP: every customer in the queue is identical.

local item_defs = require("lua/game/data/item_defs")

local CustomerQueue = {}
CustomerQueue.__index = CustomerQueue

-- Friendly per-tag greeting messages for food-order customers. Any tag not
-- listed here falls back to a generic message (see message_for_tag below)
-- so new tags don't require a change here to work correctly.
local TAG_MESSAGES = {
    Protein = "Could I get something with protein?",
    Healthy = "Could I get something healthy?",
}

local function message_for_tag(tag)
    return TAG_MESSAGES[tag] or ('Could I get something tagged "' .. tag .. '"?')
end

-- Collects every unique tag actually used anywhere in item_defs, sorted
-- alphabetically for deterministic iteration order (pairs() order over
-- item_defs is not guaranteed). Sorting only makes the SET's iteration
-- order deterministic - the tag ultimately picked by make_default_cfg is
-- still random via math.random.
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

local function make_default_cfg()
    local tags = known_tags()
    local tag  = tags[math.random(1, #tags)]

    return {
        name            = "Customer",
        requested_tag   = tag,
        messages        = { message_for_tag(tag) },
        after_messages  = { "Thanks, that's delicious!" },
        walk_speed      = 80,
    }
end

local function make_merchant_cfg()
    return {
        kind           = "merchant",
        name           = "Merchant",
        messages       = { "Fresh stock, take a look!" },
        stock          = { "raw_chicken", "raw_chicken", "broccoli", "water", "potato" },
        walk_speed     = 80,
    }
end

-- Builds a queue of `total` customer configs. Exactly one randomly-chosen
-- slot is a merchant visit; every other slot is the default food-order
-- config. Guarantees exactly one merchant per day, every day, regardless
-- of `total` (even total == 1 — that single slot is always the merchant).
function CustomerQueue.new(total)
    local self = setmetatable({}, CustomerQueue)

    self.total    = total
    self._index   = 0
    self._configs = {}

    local merchant_slot = math.random(1, total)
    for i = 1, total do
        if i == merchant_slot then
            self._configs[i] = make_merchant_cfg()
        else
            self._configs[i] = make_default_cfg()
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
