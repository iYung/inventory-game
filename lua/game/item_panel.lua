-- lua/game/item_panel.lua
-- Popup sub-inventory panel for a container Item: wraps the item's `panel`
-- Grid plus its def's `actions` as clickable buttons with a progress
-- indicator.
--
-- See docs/checklists/cooking-inventory-game.md "Shared contracts" (Task D)
-- for the intended API summary; the real `Item`/`Grid` files (lua/game/item.lua,
-- lua/game/grid.lua) are authoritative where they differ.
--
-- Coordinate choice (documented per the task instructions): rather than
-- translating incoming screen x,y into panel-local space on every call, this
-- module simply repositions `item.panel`'s origin (origin_x/origin_y) to
-- wherever the panel is drawn on screen, at ItemPanel.new() time. That way
-- `item.panel`'s own world_to_cell/cell_to_world math already lines up with
-- screen space, and mouse_pressed/moved/released can forward x,y straight
-- through with no translation. This does mean the panel Grid's origin is no
-- longer (0,0) once opened; nothing else depends on that (the panel grid is
-- only ever drawn/interacted with via ItemPanel while open).

local config    = require("lua/game/config")
local item_defs = require("lua/game/data/item_defs")

local ItemPanel = {}
ItemPanel.__index = ItemPanel

-- Layout tuning -------------------------------------------------------------

local MARGIN       = 16  -- gap between panel grid and buttons/edges
local BUTTON_W      = 96
local BUTTON_H      = 28
local BUTTON_GAP    = 8
local PROGRESS_H    = 6
local CLOSE_SIZE    = 22
local CLOSE_GAP     = 6

local COLOR_DISABLED = { 0.35, 0.35, 0.35, 1 }
local COLOR_CLOSE    = { 0.75, 0.25, 0.25, 1 }

-- Construction ---------------------------------------------------------------

-- ItemPanel.new(item): errors if item.panel is nil (item isn't a container).
function ItemPanel.new(item)
    if not item or not item.panel then
        error("ItemPanel.new: item.panel is nil (item is not a container)")
    end

    local self = setmetatable({}, ItemPanel)
    self.item = item

    local def = item_defs[item.type_id]
    self.def = def

    local panel = item.panel
    local grid_w = panel.cols * panel.cell_size
    local grid_h = panel.rows * panel.cell_size

    -- Centered horizontally, upper-middle of the screen (above the main
    -- floor grid, below/within the customer stage area is avoided by
    -- sitting just below SPLIT_Y's midpoint region - actually we want it to
    -- NOT overlap the customer stage (top half) or the main floor grid
    -- (bottom half), so anchor it around the split line itself.
    local origin_x = (config.SCREEN_W - grid_w) / 2
    local origin_y = config.SPLIT_Y - grid_h - MARGIN - BUTTON_H - BUTTON_GAP

    -- Reposition the item's real panel grid to this screen location so its
    -- own world_to_cell/cell_to_world math lines up with screen space; see
    -- module comment above.
    panel.origin_x = origin_x
    panel.origin_y = origin_y

    self.grid_x, self.grid_y = origin_x, origin_y
    self.grid_w, self.grid_h = grid_w, grid_h

    -- Close (X) button, overlapping the grid's top-right corner (title-bar
    -- style). Explicit close only - clicking outside the panel does nothing.
    self.close_button = {
        x = origin_x + grid_w - CLOSE_SIZE,
        y = origin_y - CLOSE_SIZE - CLOSE_GAP,
        w = CLOSE_SIZE,
        h = CLOSE_SIZE,
    }
    self.should_close = false

    -- Button rects, one per action, laid out in a row below the grid.
    self.buttons = {}
    local actions = (def and def.actions) or {}
    local total_w = #actions * BUTTON_W + math.max(0, #actions - 1) * BUTTON_GAP
    local start_x = origin_x + (grid_w - total_w) / 2
    local by = origin_y + grid_h + BUTTON_GAP

    for i, action in ipairs(actions) do
        local bx = start_x + (i - 1) * (BUTTON_W + BUTTON_GAP)
        self.buttons[action.name] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
    end

    return self
end

-- Helpers ---------------------------------------------------------------

-- Read-only lookup of the action def by name, or nil.
local function find_action(def, name)
    if not def or not def.actions then return nil end
    for _, action in ipairs(def.actions) do
        if action.name == name then return action end
    end
    return nil
end

-- Read-only re-implementation of Item's internal count_panel_items check
-- (Item does not expose this without side effects, so it's duplicated here
-- rather than speculatively calling start_action).
local function count_panel_items(panel)
    local counts = {}
    for _, it in ipairs(panel:items()) do
        counts[it.type_id] = (counts[it.type_id] or 0) + 1
    end
    return counts
end

function ItemPanel:_point_in_grid(x, y)
    return x >= self.grid_x and x < self.grid_x + self.grid_w
       and y >= self.grid_y and y < self.grid_y + self.grid_h
end

local function point_in_rect(x, y, r)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function ItemPanel:_point_in_close_button(x, y)
    return point_in_rect(x, y, self.close_button)
end

function ItemPanel:_button_at(x, y)
    for name, rect in pairs(self.buttons) do
        if x >= rect.x and x < rect.x + rect.w
           and y >= rect.y and y < rect.y + rect.h then
            return name
        end
    end
    return nil
end

-- Whether action `name` is currently clickable: requirements satisfied by
-- the panel's current contents, and not already running.
function ItemPanel:is_action_enabled(name)
    local action = find_action(self.def, name)
    if not action then return false end

    local state = self.item.action_state and self.item.action_state[name]
    if state and state.running then
        return false
    end

    local counts = count_panel_items(self.item.panel)
    for type_id, needed in pairs(action.requires or {}) do
        if (counts[type_id] or 0) < needed then
            return false
        end
    end

    return true
end

-- Input forwarding ------------------------------------------------------

function ItemPanel:mouse_pressed(x, y)
    if self:_point_in_close_button(x, y) then
        self.should_close = true
        return
    end

    if self:_point_in_grid(x, y) then
        self.item.panel:mouse_pressed(x, y)
        return
    end

    local name = self:_button_at(x, y)
    if name and self:is_action_enabled(name) then
        self.item:start_action(name)
    end
end

function ItemPanel:mouse_moved(x, y)
    if self:_point_in_grid(x, y) or self.item.panel.dragging then
        self.item.panel:mouse_moved(x, y)
    end
end

function ItemPanel:mouse_released(x, y)
    if self:_point_in_grid(x, y) or self.item.panel.dragging then
        self.item.panel:mouse_released(x, y)
    end
end

-- Draw --------------------------------------------------------------------

function ItemPanel:draw()
    self.item.panel:draw()

    local colors = config.COLORS or {}
    local actions = (self.def and self.def.actions) or {}

    for _, action in ipairs(actions) do
        local rect = self.buttons[action.name]
        if rect then
            local enabled = self:is_action_enabled(action.name)
            local color = enabled and (colors.button or { 0.3, 0.55, 0.3, 1 }) or COLOR_DISABLED

            love.graphics.setColor(color)
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

            local state = self.item.action_state and self.item.action_state[action.name]
            if state and state.running then
                local frac = math.min(1, state.elapsed / action.duration)
                love.graphics.setColor(colors.grid_line or { 0.8, 0.8, 0.2, 1 })
                love.graphics.rectangle(
                    "fill", rect.x, rect.y + rect.h - PROGRESS_H,
                    rect.w * frac, PROGRESS_H
                )
            end

            love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
            love.graphics.print(action.name, rect.x + 6, rect.y + 6)
        end
    end

    local cb = self.close_button
    love.graphics.setColor(COLOR_CLOSE)
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print("X", cb.x + cb.w / 2 - 4, cb.y + cb.h / 2 - 8)

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemPanel
