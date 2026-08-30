-- lua/game/item_panel.lua
-- Popup sub-inventory panel for a container Item: wraps the item's `panel`
-- Grid plus its def's `actions` as clickable buttons with a progress
-- indicator. Draggable by its title bar.
--
-- See docs/checklists/cooking-inventory-game.md "Shared contracts" (Task D)
-- for the intended API summary; the real `Item`/`Grid` files (lua/game/item.lua,
-- lua/game/grid.lua) are authoritative where they differ.
--
-- Coordinate choice (documented per the task instructions): rather than
-- translating incoming screen x,y into panel-local space on every call, this
-- module simply repositions `item.panel`'s origin (origin_x/origin_y) to
-- wherever the panel is drawn on screen, whenever the panel is laid out
-- (construction, and again on every drag move). That way `item.panel`'s own
-- world_to_cell/cell_to_world math always lines up with screen space, and
-- mouse_pressed/moved/released can forward x,y straight through with no
-- translation. This does mean the panel Grid's origin is no longer (0,0)
-- once opened; nothing else depends on that (the panel grid is only ever
-- drawn/interacted with via ItemPanel while open).

local config    = require("lua/game/config")
local item_defs = require("lua/game/data/item_defs")

local ItemPanel = {}
ItemPanel.__index = ItemPanel

-- Layout tuning -------------------------------------------------------------

local MARGIN       = 16  -- gap between panel content and the backdrop edge
local BUTTON_W      = 96
local BUTTON_H      = 28
local BUTTON_GAP    = 8
local PROGRESS_H    = 6
local CLOSE_SIZE    = 22
local CLOSE_GAP     = 6
local TITLE_H       = 28

local COLOR_DISABLED = { 0.35, 0.35, 0.35, 1 }
local COLOR_CLOSE    = { 0.75, 0.25, 0.25, 1 }
local COLOR_TITLE    = { 0.20, 0.20, 0.26, 1 }
-- "Leave" (merchant-only) button: same warning-red as the close button, kept
-- as its own constant so its meaning is self-documenting where it's used
-- below, even though the color values are identical today.
local COLOR_LEAVE    = COLOR_CLOSE

local function point_in_rect(x, y, r)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Construction ---------------------------------------------------------------

-- ItemPanel.new(item): errors if item.panel is nil (item isn't a container).
function ItemPanel.new(item)
    if not item or not item.panel then
        error("ItemPanel.new: item.panel is nil (item is not a container)")
    end

    local self = setmetatable({}, ItemPanel)
    self.item = item
    self.def  = item_defs[item.type_id]
    self.should_close    = false
    self.should_leave    = false
    self._dragging_panel = false

    local panel = item.panel
    self.grid_w = panel.cols * panel.cell_size
    self.grid_h = panel.rows * panel.cell_size

    -- Button row sizing: any def.actions plus one more slot for "Leave" when
    -- this is a merchant-kind item. "Leave" is not a def.actions entry (a
    -- merchant has no matching action def to look up) - it's additive to the
    -- same row/centering math, kept generic so an item with both actions AND
    -- kind == "merchant" would still get both (never happens today, but the
    -- layout math doesn't assume otherwise).
    local actions = (self.def and self.def.actions) or {}
    local button_count = #actions + ((item.kind == "merchant") and 1 or 0)
    self._button_total_w = button_count * BUTTON_W + math.max(0, button_count - 1) * BUTTON_GAP

    -- Overall backdrop size: wide enough for the grid or the button row,
    -- whichever is wider; tall enough for title bar + grid + button row,
    -- each separated by MARGIN.
    self.bg_w = math.max(self.grid_w, self._button_total_w) + MARGIN * 2
    self.bg_h = TITLE_H + MARGIN + self.grid_h + BUTTON_GAP + BUTTON_H + MARGIN

    -- Default position: centered horizontally, sitting just above the
    -- split line so it doesn't overlap the main floor grid.
    local default_x = (config.SCREEN_W - self.bg_w) / 2
    local default_y = config.SPLIT_Y - self.bg_h - 12

    self:_layout(default_x, default_y)

    return self
end

-- Recomputes every rect (bg, title bar, close button, grid position,
-- action buttons) from the backdrop's top-left corner, and repositions the
-- real panel Grid to match. Called at construction and on every drag move.
function ItemPanel:_layout(bg_x, bg_y)
    self.bg = { x = bg_x, y = bg_y, w = self.bg_w, h = self.bg_h }

    self.title_bar = { x = bg_x, y = bg_y, w = self.bg_w, h = TITLE_H }

    self.close_button = {
        x = bg_x + self.bg_w - CLOSE_SIZE - CLOSE_GAP,
        y = bg_y + (TITLE_H - CLOSE_SIZE) / 2,
        w = CLOSE_SIZE,
        h = CLOSE_SIZE,
    }

    self.grid_x = bg_x + (self.bg_w - self.grid_w) / 2
    self.grid_y = bg_y + TITLE_H + MARGIN

    -- Reposition the item's real panel grid to this screen location; see
    -- module comment above.
    self.item.panel.origin_x = self.grid_x
    self.item.panel.origin_y = self.grid_y

    self.buttons = {}
    local actions = (self.def and self.def.actions) or {}
    local start_x = bg_x + (self.bg_w - self._button_total_w) / 2
    local by = self.grid_y + self.grid_h + BUTTON_GAP

    local slot = 0
    for _, action in ipairs(actions) do
        local bx = start_x + slot * (BUTTON_W + BUTTON_GAP)
        self.buttons[action.name] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
        slot = slot + 1
    end

    -- "Leave" occupies the next slot in the same row, when present. It is
    -- NOT a def.actions entry - there's no action def to look it up by, it's
    -- purely an ItemPanel-level button for merchant-kind items.
    if self.item.kind == "merchant" then
        local bx = start_x + slot * (BUTTON_W + BUTTON_GAP)
        self.buttons["Leave"] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
        slot = slot + 1
    end
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

function ItemPanel:_point_in_close_button(x, y)
    return point_in_rect(x, y, self.close_button)
end

-- Whether (x,y) lands anywhere on this panel's opaque backdrop (title bar,
-- grid, buttons, or just dead space between them) - used by the scene to
-- decide whether a click is claimed by this panel at all before checking
-- what it's on lower in stacking order (another panel, or the game
-- underneath). A panel is meant to read as a solid window; nothing should
-- click "through" it.
function ItemPanel:_point_in_bg(x, y)
    return point_in_rect(x, y, self.bg)
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

-- Returns true if (x,y) landed on some part of the panel's own UI (close
-- button, grid, a button, or the title bar) and was handled here; false if
-- the click missed the panel entirely, so the caller can treat it as a
-- normal click on whatever's behind/around the panel instead (e.g. starting
-- a drag from the main floor grid while the panel stays open).
function ItemPanel:mouse_pressed(x, y)
    if self:_point_in_close_button(x, y) then
        self.should_close = true
        return true
    end

    if self:_point_in_grid(x, y) then
        self.item.panel:mouse_pressed(x, y)
        return true
    end

    -- "Leave" (merchant-only, absent otherwise) ends the visit: sets both
    -- the existing should_close flag (hides the panel like any other close)
    -- and should_leave, which ItemPanel itself does nothing further with -
    -- it's the caller's (KitchenScene's) job to act on it.
    if self.buttons["Leave"] and point_in_rect(x, y, self.buttons["Leave"]) then
        self.should_close = true
        self.should_leave = true
        return true
    end

    local name = self:_button_at(x, y)
    if name then
        if self:is_action_enabled(name) then
            self.item:start_action(name)
        end
        return true
    end

    -- Title bar (checked last: the close button overlaps its right edge and
    -- is already handled above) starts dragging the whole panel.
    if point_in_rect(x, y, self.title_bar) then
        self._dragging_panel = true
        self._drag_offset_x  = x - self.bg.x
        self._drag_offset_y  = y - self.bg.y
        return true
    end

    return false
end

function ItemPanel:mouse_moved(x, y)
    if self._dragging_panel then
        self:_layout(x - self._drag_offset_x, y - self._drag_offset_y)
        return
    end

    if self:_point_in_grid(x, y) or self.item.panel.dragging then
        self.item.panel:mouse_moved(x, y)
    end
end

function ItemPanel:mouse_released(x, y)
    if self._dragging_panel then
        self._dragging_panel = false
        return
    end

    if self:_point_in_grid(x, y) or self.item.panel.dragging then
        self.item.panel:mouse_released(x, y)
    end
end

-- Draw --------------------------------------------------------------------

-- skip_dragging: passed straight through to the inner panel Grid's draw, so
-- a caller can draw whatever's mid-drag separately on top of everything
-- (see Grid:draw's skip_dragging param).
function ItemPanel:draw(skip_dragging)
    local colors = config.COLORS or {}

    if self.bg then
        love.graphics.setColor(colors.panel_bg or { 0.1, 0.1, 0.13, 0.95 })
        love.graphics.rectangle("fill", self.bg.x, self.bg.y, self.bg.w, self.bg.h)
        love.graphics.setColor(colors.panel_border or { 0.45, 0.45, 0.55, 1 })
        love.graphics.rectangle("line", self.bg.x, self.bg.y, self.bg.w, self.bg.h)
    end

    local tb = self.title_bar
    love.graphics.setColor(COLOR_TITLE)
    love.graphics.rectangle("fill", tb.x, tb.y, tb.w, tb.h)
    love.graphics.setColor(colors.panel_border or { 0.45, 0.45, 0.55, 1 })
    love.graphics.rectangle("line", tb.x, tb.y, tb.w, tb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print((self.def and self.def.name) or self.item.type_id, tb.x + 8, tb.y + 6)

    self.item.panel:draw(skip_dragging)

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

    -- "Leave" (merchant-only): drawn distinctly from action buttons - no
    -- progress bar, since it's not tied to action_state.
    local leave_rect = self.buttons["Leave"]
    if leave_rect then
        love.graphics.setColor(COLOR_LEAVE)
        love.graphics.rectangle("fill", leave_rect.x, leave_rect.y, leave_rect.w, leave_rect.h)
        love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
        love.graphics.print("Leave", leave_rect.x + 6, leave_rect.y + 6)
    end

    local cb = self.close_button
    love.graphics.setColor(COLOR_CLOSE)
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print("X", cb.x + cb.w / 2 - 4, cb.y + cb.h / 2 - 8)

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemPanel
