-- lua/game/item.lua
-- Base grid item: type id, footprint cells, rotation, placeholder sprite,
-- optional sub-inventory panel (a Grid) and timed actions.
--
-- See docs/checklists/cooking-inventory-game.md "Shared contracts" for the
-- authoritative API this class must match.

local config    = require("lua/game/config")
local Sprite    = require("lua/core/sprite")
local item_defs = require("lua/game/data/item_defs")

local _icon_cache = {}
local function load_icon(type_id)
    if not _icon_cache[type_id] then
        local path = "assets/images/items/" .. type_id .. ".png"
        if love.filesystem.getInfo(path) then
            _icon_cache[type_id] = love.graphics.newImage(path)
        end
    end
    return _icon_cache[type_id]
end

local Item = {}
Item.__index = Item

-- Internal helpers -----------------------------------------------------

-- Returns the {width, height} bounding box (in cells) of a footprint cell
-- list, assuming it is already normalized (min dx/dy == 0).
local function bounding_box(cells)
    local max_dx, max_dy = 0, 0
    for _, c in ipairs(cells) do
        if c[1] > max_dx then max_dx = c[1] end
        if c[2] > max_dy then max_dy = c[2] end
    end
    return max_dx + 1, max_dy + 1
end

-- Rotates a footprint cell list 90 degrees: (dx,dy) -> (-dy,dx), then
-- re-normalizes so the minimum dx/dy is 0 again. Returns a NEW list; does
-- not mutate `cells`.
local function rotate_cells(cells)
    local rotated = {}
    for i, c in ipairs(cells) do
        rotated[i] = { -c[2], c[1] }
    end

    local min_dx, min_dy = math.huge, math.huge
    for _, c in ipairs(rotated) do
        if c[1] < min_dx then min_dx = c[1] end
        if c[2] < min_dy then min_dy = c[2] end
    end
    for _, c in ipairs(rotated) do
        c[1] = c[1] - min_dx
        c[2] = c[2] - min_dy
    end

    return rotated
end

-- Forward declaration so Item.new (below) can call fill_panel, which in
-- turn calls Item.new recursively to create the fill items. The actual
-- body is assigned further down once Item itself is defined.
local fill_panel

-- Construction -----------------------------------------------------------

function Item.new(type_id)
    local def = item_defs[type_id]
    assert(def, "Item.new: unknown type_id '" .. tostring(type_id) .. "'")

    local self = setmetatable({}, Item)

    self.type_id      = type_id
    self.rotation      = 0
    self.cell_col      = nil
    self.cell_row      = nil
    self.grid           = nil
    self.action_state  = {}
    self.overnight_state = {}
    -- Plain field, not a method like footprint() - tags don't depend on
    -- rotation state, they never change after construction.
    self.tags          = def.tags or {}
    self.label         = def.name or ""

    local w, h = bounding_box(def.footprint)
    self.sprite = Sprite.new(0, 0, w * config.U, h * config.U)
    self.sprite.color = def.color

    local icon = load_icon(type_id)
    if icon then
        self.sprite.image = icon
        self.sprite.border_color = def.color
        self.sprite.color = { 1, 1, 1, 1 }  -- don't tint the PNG
    end

    self.panel = nil
    if def.has_panel then
        local Grid = require("lua/game/grid")
        self.panel = Grid.new(def.panel_cols, def.panel_rows, config.U, 0, 0)
        self.panel.owner = self
    end

    if def.daily_fill then
        fill_panel(self.panel, def.daily_fill, def.panel_cols, def.panel_rows)
    end

    return self
end

-- Footprint / rotation -----------------------------------------------------

-- Returns a freshly-built list of {dx,dy} cells for this item's def
-- footprint, rotated by self.rotation quarter turns and re-normalized.
-- Never mutates the def's base footprint.
function Item:footprint()
    local def = item_defs[self.type_id]

    local cells = {}
    for i, c in ipairs(def.footprint) do
        cells[i] = { c[1], c[2] }
    end

    for _ = 1, self.rotation do
        cells = rotate_cells(cells)
    end

    return cells
end

function Item:rotate()
    self.rotation = (self.rotation + 1) % 4

    local cells = self:footprint()
    local w, h = bounding_box(cells)
    self.sprite.width  = w * config.U
    self.sprite.height = h * config.U
end

-- Actions -----------------------------------------------------------------

local function find_action(def, name)
    if not def.actions then return nil end
    for _, action in ipairs(def.actions) do
        if action.name == name then
            return action
        end
    end
    return nil
end

-- Returns true iff `tag` appears in item.tags, false otherwise.
local function has_tag(item, tag)
    for _, t in ipairs(item.tags) do
        if t == tag then
            return true
        end
    end
    return false
end

-- Counts how many items of each type_id currently sit in `panel`.
local function count_panel_items(panel)
    local counts = {}
    for _, it in ipairs(panel:items()) do
        counts[it.type_id] = (counts[it.type_id] or 0) + 1
    end
    return counts
end

-- An action's recipe list: action.recipes if present (a button that
-- handles more than one ingredient, e.g. the microwave's "Cook" working
-- for both raw meat and broccoli), else a single recipe built from the
-- action's own flat requires/produces (a button with exactly one recipe
-- doesn't need the wrapper). Either way, callers just get a list of
-- { requires, produces } to try in order.
local function action_recipes(action)
    return action.recipes or { { requires = action.requires, produces = action.produces } }
end

-- Returns true iff every type_id = needed pair in `requires` has
-- (counts[type_id] or 0) >= needed. `requires` may be nil - treated as
-- "always satisfied".
local function satisfies(requires, counts)
    for type_id, needed in pairs(requires or {}) do
        if (counts[type_id] or 0) < needed then
            return false
        end
    end
    return true
end

-- Returns the first item in `panel:items()` whose type_id == type_id, or
-- nil if none match.
local function find_item_of_type(panel, type_id)
    for _, it in ipairs(panel:items()) do
        if it.type_id == type_id then
            return it
        end
    end
    return nil
end

-- Returns every recipe on `action` satisfied by panel's contents right now,
-- as a list of { recipe, target_item } - target_item is the matched
-- container instance for a `container` recipe, else nil (meaning "act on
-- panel itself", the existing behavior). Deducts each match's `requires`
-- from a running `counts` copy so two recipes never double-claim the same
-- ingredient; a container recipe's own requirements are checked against
-- (and only ever deducted from) the container's own panel, never `counts`.
local function matching_recipes(action, panel)
    local counts = count_panel_items(panel)
    local matches = {}
    for _, recipe in ipairs(action_recipes(action)) do
        if recipe.container then
            local container_item = find_item_of_type(panel, recipe.container)
            if container_item and satisfies(recipe.requires, count_panel_items(container_item.panel)) then
                matches[#matches + 1] = { recipe = recipe, target_item = container_item }
            end
        elseif satisfies(recipe.requires, counts) then
            matches[#matches + 1] = { recipe = recipe, target_item = nil }
            for type_id, needed in pairs(recipe.requires or {}) do
                counts[type_id] = counts[type_id] - needed
            end
        end
    end
    return matches
end

-- Finds every recipe on `action` satisfied by the panel's current contents;
-- starts the timer (self.action_state[name] = { running = true, elapsed =
-- 0, matches = <list of { recipe, target_item } from matching_recipes> })
-- and returns true if at least one was found. Returns false (no-op) if the
-- action doesn't exist, there is no panel, it's already running, or no
-- recipe's requirements are met.
function Item:start_action(name)
    local def = item_defs[self.type_id]
    local action = find_action(def, name)
    if not action or not self.panel then
        return false
    end

    self.action_state = self.action_state or {}
    local state = self.action_state[name]
    if state and state.running then
        return false
    end

    local matches = matching_recipes(action, self.panel)
    if #matches == 0 then
        return false
    end

    self.action_state[name] = { running = true, elapsed = 0, matches = matches }
    return true
end

-- Removes up to `count` items of `type_id` from `panel`, returning the list
-- of cells (col,row) that were freed.
local function remove_matching(panel, type_id, count)
    local removed = 0
    local freed_cells = {}

    -- Snapshot first: panel:remove mutates the list panel:items() returns.
    local snapshot = {}
    for _, it in ipairs(panel:items()) do
        snapshot[#snapshot + 1] = it
    end

    for _, it in ipairs(snapshot) do
        if removed >= count then break end
        if it.type_id == type_id then
            freed_cells[#freed_cells + 1] = { it.cell_col, it.cell_row }
            panel:remove(it)
            removed = removed + 1
        end
    end

    return freed_cells
end

-- Places a freshly-created item into the first free cell of `panel`
-- (simple first-fit scan, col-major within row, top-left first).
local function place_first_fit(panel, item, cols, rows)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            if panel:can_place(item, col, row) then
                panel:place(item, col, row)
                return true
            end
        end
    end
    return false
end

-- Fills `panel` with items specified by `daily_fill` (type_id -> count),
-- placing each freshly created item using first-fit scan over cols x rows.
-- Assigned here (not declared local) because the forward declaration at the
-- top of the file lets Item.new reference it before this point.
fill_panel = function(panel, daily_fill, cols, rows)
    for type_id, count in pairs(daily_fill) do
        for _ = 1, count do
            local new_item = Item.new(type_id)
            place_first_fit(panel, new_item, cols, rows)
        end
    end
end

local function complete_action(self, def, matches)
    for _, match in ipairs(matches) do
        local recipe      = match.recipe
        local target_item = match.target_item
        local target_panel = target_item and target_item.panel or self.panel
        local target_def   = target_item and item_defs[target_item.type_id] or def

        for type_id, count in pairs(recipe.requires or {}) do
            remove_matching(target_panel, type_id, count)
        end

        for type_id, count in pairs(recipe.produces or {}) do
            for _ = 1, count do
                local new_item = Item.new(type_id)
                place_first_fit(target_panel, new_item, target_def.panel_cols, target_def.panel_rows)
            end
        end
    end
end

-- Frame tick ----------------------------------------------------------------

function Item:overnight_tick()
    if not self.panel then return end
    local def = item_defs[self.type_id]

    if def.overnight_actions then
        for i, action in ipairs(def.overnight_actions) do
            local counts = count_panel_items(self.panel)
            local state = self.overnight_state[i] or { nights_elapsed = 0 }

            if satisfies(action.requires, counts) then
                state.nights_elapsed = state.nights_elapsed + 1
                if state.nights_elapsed >= action.nights then
                    if not action.preserve then
                        for type_id, count in pairs(action.requires or {}) do
                            remove_matching(self.panel, type_id, count)
                        end
                    end
                    local step = action.per_item_step or 1
                    local repeats = action.per_item
                        and math.floor((counts[action.per_item] or 0) / step)
                        or 1
                    for _ = 1, repeats do
                        for type_id, count in pairs(action.produces or {}) do
                            for _ = 1, count do
                                local new_item = Item.new(type_id)
                                place_first_fit(self.panel, new_item, def.panel_cols, def.panel_rows)
                            end
                        end
                    end
                    state.nights_elapsed = 0
                end
                self.overnight_state[i] = state
            else
                self.overnight_state[i] = { nights_elapsed = 0 }
            end
        end
    end

    if def.garden_spread then
        local Grid = require("lua/game/grid")
        for _, spread_type in ipairs(def.garden_spread) do
            -- Snapshot occupied cells for this type
            local sources = {}
            for _, it in ipairs(self.panel:items()) do
                if it.type_id == spread_type then
                    sources[#sources + 1] = { it.cell_col, it.cell_row }
                end
            end
            -- Collect empty orthogonal neighbors
            local seen = {}
            local targets = {}
            for _, src in ipairs(sources) do
                local neighbors = {
                    { src[1]-1, src[2] },
                    { src[1]+1, src[2] },
                    { src[1],   src[2]-1 },
                    { src[1],   src[2]+1 },
                }
                for _, nb in ipairs(neighbors) do
                    local c, r = nb[1], nb[2]
                    local key = c .. "," .. r
                    if not seen[key]
                        and c >= 0 and c < def.panel_cols
                        and r >= 0 and r < def.panel_rows
                        and not self.panel:item_at(c, r)
                    then
                        seen[key] = true
                        targets[#targets + 1] = { c, r }
                    end
                end
            end
            -- Place new items (won't spread this tick — they weren't in sources)
            for _, pos in ipairs(targets) do
                local new_item = Item.new(spread_type)
                if self.panel:can_place(new_item, pos[1], pos[2]) then
                    self.panel:place(new_item, pos[1], pos[2])
                end
            end
        end
    end
end

-- Ticks the panel grid (so nested items' own timers keep running) and any
-- running action timers on this item; completes actions whose duration has
-- elapsed.
function Item:update(dt)
    if self.panel then
        self.panel:update(dt)
    end

    local def = item_defs[self.type_id]
    if not def.actions then return end

    for _, action in ipairs(def.actions) do
        local state = self.action_state[action.name]
        if state and state.running then
            state.elapsed = state.elapsed + dt
            if state.elapsed >= action.duration then
                complete_action(self, def, state.matches)
                self.action_state[action.name] = nil
            end
        end
    end
end

-- Draw ------------------------------------------------------------------

function Item:draw()
    if not self.sprite then return end

    -- While this item is the grid's active drag, Grid keeps sprite.x/y
    -- centered on the cursor each frame (see Grid:_position_dragging_sprite);
    -- don't fight that by snapping back to the (stale) cell_col/cell_row.
    local being_dragged = self.grid and self.grid.dragging == self
    if not being_dragged and self.grid and self.cell_col and self.cell_row then
        self.sprite.x, self.sprite.y = self.grid:cell_to_world(self.cell_col, self.cell_row)
    end

    self.sprite:draw()
end

-- Clears the panel and re-fills it from def.daily_fill. No-op when this
-- item has no panel or no daily_fill.
function Item:refill_daily()
    if not self.panel then return end
    local def = item_defs[self.type_id]
    if not def.daily_fill then return end
    -- Snapshot before removing to avoid mutating the live list mid-iteration.
    local snapshot = {}
    for _, it in ipairs(self.panel:items()) do
        snapshot[#snapshot + 1] = it
    end
    for _, it in ipairs(snapshot) do
        self.panel:remove(it)
    end
    fill_panel(self.panel, def.daily_fill, def.panel_cols, def.panel_rows)
end

Item.matching_recipes = matching_recipes
Item.has_tag = has_tag

return Item
