-- lua/game/item.lua
-- Base grid item: type id, footprint cells, rotation, placeholder sprite,
-- optional sub-inventory panel (a Grid) and timed actions.
--
-- See docs/checklists/cooking-inventory-game.md "Shared contracts" for the
-- authoritative API this class must match.

local config    = require("lua/game/config")
local Sprite    = require("lua/core/sprite")
local item_defs = require("lua/game/data/item_defs")

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
    -- Plain field, not a method like footprint() - tags don't depend on
    -- rotation state, they never change after construction.
    self.tags          = def.tags or {}

    local w, h = bounding_box(def.footprint)
    self.sprite = Sprite.new(0, 0, w * config.U, h * config.U)
    self.sprite.color = def.color

    self.panel = nil
    if def.has_panel then
        local Grid = require("lua/game/grid")
        self.panel = Grid.new(def.panel_cols, def.panel_rows, config.U, 0, 0)
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

-- Returns the first recipe in `action` whose `requires` is satisfied by
-- `counts` (from count_panel_items), or nil if none match.
local function matching_recipe(action, counts)
    for _, recipe in ipairs(action_recipes(action)) do
        local satisfied = true
        for type_id, needed in pairs(recipe.requires or {}) do
            if (counts[type_id] or 0) < needed then
                satisfied = false
                break
            end
        end
        if satisfied then return recipe end
    end
    return nil
end

-- Finds a recipe on `action` satisfied by the panel's current contents;
-- starts the timer (self.action_state[name] = { running = true, elapsed =
-- 0, recipe = <the matched recipe> }) and returns true if one was found.
-- Returns false (no-op) if the action doesn't exist, there is no panel,
-- it's already running, or no recipe's requirements are met.
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

    local recipe = matching_recipe(action, count_panel_items(self.panel))
    if not recipe then
        return false
    end

    self.action_state[name] = { running = true, elapsed = 0, recipe = recipe }
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

local function complete_action(self, def, recipe)
    for type_id, count in pairs(recipe.requires or {}) do
        remove_matching(self.panel, type_id, count)
    end

    for type_id, count in pairs(recipe.produces or {}) do
        for _ = 1, count do
            local new_item = Item.new(type_id)
            place_first_fit(self.panel, new_item, def.panel_cols, def.panel_rows)
        end
    end
end

-- Frame tick ----------------------------------------------------------------

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
                complete_action(self, def, state.recipe)
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

return Item
