-- lua/game/order_gen.lua
--
-- Generates rule-based, multi-item orders scaled by day number and the
-- player's owned programs.
--
-- Rule kinds:
--   { kind="at_least", tag, n }   -- ≥ n items with tag
--   { kind="no_more",  tag, n }   -- ≤ n items with tag
--   { kind="no",       tag   }    -- 0 items with tag
--   { kind="specific", type_id }  -- order must contain this type_id
--   { kind="all_unique"       }   -- no two items share a type_id
--
-- Returned config: { order_rules, order_item_count, payout }

local item_defs = require("lua/game/data/item_defs")

local OrderGen = {}

-- ── Scaling tables ────────────────────────────────────────────────────────────

local function item_range(day)
    if day <= 2 then return 1, 2
    elseif day <= 6 then return 1, 4
    else return 1, 5 end
end

local function rule_range(day)
    if day <= 4 then return 1, 2
    else return 1, 4 end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

local function keys(tbl)
    local ks = {}
    for k, _ in pairs(tbl) do ks[#ks + 1] = k end
    return ks
end

-- Weighted random pick from { value, weight } list. Returns value or nil.
local function weighted_pick(choices)
    local total = 0
    for _, c in ipairs(choices) do total = total + c[2] end
    if total == 0 then return nil end
    local r = math.random() * total
    local acc = 0
    for _, c in ipairs(choices) do
        acc = acc + c[2]
        if r <= acc then return c[1] end
    end
    return choices[#choices][1]
end

-- ── Satisfiability check ──────────────────────────────────────────────────────

-- Returns true if there exists a multiset of `count` items drawn from
-- `output_list` that satisfies all rules in `rules`.
-- Uses a greedy check: not exhaustive, but good enough to catch impossible rules.
local function is_satisfiable(rules, count, output_list)
    if #output_list == 0 then return count == 0 end

    -- Build tag index: type_id -> set of tags.
    local item_tags = {}
    for _, type_id in ipairs(output_list) do
        local def = item_defs[type_id]
        item_tags[type_id] = {}
        if def and def.tags then
            for _, tag in ipairs(def.tags) do
                item_tags[type_id][tag] = true
            end
        end
    end

    -- Check "no" rules: if every output has a forbidden tag, unsatisfiable.
    for _, rule in ipairs(rules) do
        if rule.kind == "no" then
            local any_clean = false
            for _, type_id in ipairs(output_list) do
                if not item_tags[type_id][rule.tag] then
                    any_clean = true; break
                end
            end
            if not any_clean then return false end
        end
    end

    -- Check "at_least" rules: need enough items carrying the tag.
    for _, rule in ipairs(rules) do
        if rule.kind == "at_least" then
            local carriers = 0
            for _, type_id in ipairs(output_list) do
                if item_tags[type_id][rule.tag] then carriers = carriers + 1 end
            end
            -- With repetition allowed, carriers > 0 means we can fill rule.n slots.
            if carriers == 0 then return false end
            if rule.n > count then return false end
        end
    end

    -- Check "specific" rule: type_id must be in output_list.
    for _, rule in ipairs(rules) do
        if rule.kind == "specific" then
            local found = false
            for _, type_id in ipairs(output_list) do
                if type_id == rule.type_id then found = true; break end
            end
            if not found then return false end
        end
    end

    -- Check "all_unique": need at least `count` distinct outputs.
    for _, rule in ipairs(rules) do
        if rule.kind == "all_unique" and #output_list < count then
            return false
        end
    end

    return true
end

-- ── Rule generator ────────────────────────────────────────────────────────────

local KIND_WEIGHTS = {
    { "at_least",  40 },
    { "no",        35 },
    { "no_more",   15 },
    { "specific",   7 },
    { "all_unique", 3 },
}

local function build_rules(rule_count, available_tags_set, output_list, item_count)
    local tag_list      = keys(available_tags_set)
    local constrained   = {}  -- tag -> kind already used
    local specific_used = false
    local unique_used   = false
    local rules         = {}

    for _ = 1, rule_count do
        local kind = weighted_pick(KIND_WEIGHTS)
        if not kind then break end

        if kind == "all_unique" then
            if not unique_used and item_count >= 2 then
                rules[#rules + 1] = { kind = "all_unique" }
                unique_used = true
            end

        elseif kind == "specific" then
            if not specific_used and #output_list > 0 then
                shuffle(output_list)
                rules[#rules + 1] = { kind = "specific", type_id = output_list[1] }
                specific_used = true
            end

        elseif kind == "at_least" or kind == "no" or kind == "no_more" then
            -- Pick a tag not already constrained by the same kind.
            local candidates = {}
            for _, tag in ipairs(tag_list) do
                if constrained[tag] ~= kind then
                    candidates[#candidates + 1] = tag
                end
            end
            if #candidates > 0 then
                shuffle(candidates)
                local tag = candidates[1]
                constrained[tag] = kind
                if kind == "at_least" then
                    rules[#rules + 1] = { kind = "at_least", tag = tag, n = math.random(1, math.min(2, item_count)) }
                elseif kind == "no_more" then
                    rules[#rules + 1] = { kind = "no_more",  tag = tag, n = math.random(1, math.max(1, item_count - 1)) }
                else
                    rules[#rules + 1] = { kind = "no", tag = tag }
                end
            end
        end
    end

    return rules
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Returns { order_rules, order_item_count, payout }.
-- program_state: a ProgramState instance.
function OrderGen.generate(day, program_state)
    local lo_items, hi_items = item_range(day)
    local lo_rules, hi_rules = rule_range(day)

    local item_count = math.random(lo_items, hi_items)
    local rule_count = math.random(lo_rules, hi_rules)

    local available_tags = program_state:available_tags()
    local output_list    = program_state:available_outputs()

    -- If no tags are available yet, return a simple no-rule order.
    if not next(available_tags) then
        return {
            order_rules      = {},
            order_item_count = item_count,
            payout           = item_count * 10,
        }
    end

    -- Build rules, then validate. Drop last rule and retry once if invalid.
    local rules = build_rules(rule_count, available_tags, output_list, item_count)

    if not is_satisfiable(rules, item_count, output_list) then
        table.remove(rules)
        if not is_satisfiable(rules, item_count, output_list) then
            rules = {}
        end
    end

    local payout = item_count * 10 + math.max(0, #rules - 1) * 5

    return {
        order_rules      = rules,
        order_item_count = item_count,
        payout           = payout,
    }
end

return OrderGen
