-- lua/game/customer_queue.lua
--
-- Holds an ordered list of customer config tables for a single day (the
-- shape expected by Customer:show(cfg) — see lua/game/customer.lua).
-- MVP: every customer in the queue is identical.

local item_defs = require("lua/game/data/item_defs")

local CustomerQueue = {}
CustomerQueue.__index = CustomerQueue

-- Collects every unique tag actually used anywhere in item_defs, sorted
-- alphabetically for deterministic iteration order (pairs() order over
-- item_defs is not guaranteed).
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

-- Fisher-Yates shuffle (in place).
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Assigns known tags into three tiers with no overlap. Shuffles the pool
-- then takes 1-2 for loved, 1-2 for liked, 1 for disliked (capped by what
-- remains). Tags not assigned to any tier are neutral (not shown).
local function assign_traits()
    local pool = known_tags()
    shuffle(pool)
    local idx = 1

    local loved, liked, disliked = {}, {}, {}

    local n_loved = math.random(1, math.min(2, #pool))
    for _ = 1, n_loved do
        loved[#loved + 1] = pool[idx]; idx = idx + 1
    end

    if idx <= #pool then
        local n_liked = math.random(1, math.min(2, #pool - idx + 1))
        for _ = 1, n_liked do
            liked[#liked + 1] = pool[idx]; idx = idx + 1
        end
    end

    if idx <= #pool then
        disliked[1] = pool[idx]
    end

    return loved, liked, disliked
end

-- Builds a one-line message summarising the customer's preferences from
-- their loved/liked/disliked tiers.
local function message_for_traits(loved, liked, disliked)
    local parts = {}
    if #loved > 0 then
        parts[#parts + 1] = "I'd love some " .. table.concat(loved, " or ") .. "!"
    end
    if #liked > 0 then
        parts[#parts + 1] = table.concat(liked, " and ") .. " works for me."
    end
    if #disliked > 0 then
        parts[#parts + 1] = "Not a fan of " .. table.concat(disliked, " or ") .. "."
    end
    if #parts == 0 then return "I'll take anything!" end
    return table.concat(parts, " ")
end

local function make_default_cfg()
    local loved, liked, disliked = assign_traits()

    return {
        name           = "Customer",
        loved_tags     = loved,
        liked_tags     = liked,
        disliked_tags  = disliked,
        messages       = { message_for_traits(loved, liked, disliked) },
        after_messages = { "Thanks, that's delicious!" },
        walk_speed     = 80,
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
