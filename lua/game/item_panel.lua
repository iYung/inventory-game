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
local Item      = require("lua/game/item")

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
local RULE_ROW_H    = 18  -- height of one rule row in the order reminder area
local RULE_PAD      = 6   -- vertical padding above/below rules

local COLOR_DISABLED = { 0.35, 0.35, 0.35, 1 }
local COLOR_CLOSE    = { 0.75, 0.25, 0.25, 1 }
local COLOR_TITLE    = { 0.20, 0.20, 0.26, 1 }
local COLOR_PASS     = { 0.25, 0.85, 0.35, 1 }  -- green
local COLOR_FAIL     = { 0.90, 0.25, 0.25, 1 }  -- red
local COLOR_WARN     = { 0.95, 0.70, 0.15, 1 }  -- amber (no_more at limit)
local COLOR_NEUTRAL  = { 0.60, 0.60, 0.65, 1 }
-- "Leave" (merchant-only) button: same warning-red as the close button, kept
-- as its own constant so its meaning is self-documenting where it's used
-- below, even though the color values are identical today.
local COLOR_LEAVE    = COLOR_CLOSE

local function point_in_rect(x, y, r)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Reminder-area height for an order panel: one row per rule.
local function order_reminder_h(rule_count)
    return RULE_PAD + rule_count * RULE_ROW_H + RULE_PAD
end

-- ── Rule evaluation ───────────────────────────────────────────────────────────

-- Count items in the panel that carry `tag`.
local function count_with_tag(panel_items, tag)
    local n = 0
    for _, it in ipairs(panel_items) do
        if Item.has_tag(it, tag) then n = n + 1 end
    end
    return n
end

-- Evaluate one rule against panel_items. Returns "pass", "fail", or "warn"
-- (no_more rule exactly at the limit). Empty panel returns "fail" for all.
local function eval_rule(rule, panel_items)
    if rule.kind == "at_least" then
        local n = count_with_tag(panel_items, rule.tag)
        return n >= rule.n and "pass" or "fail"
    elseif rule.kind == "no_more" then
        local n = count_with_tag(panel_items, rule.tag)
        if n > rule.n then return "fail" end
        if n == rule.n then return "warn" end
        return "pass"
    elseif rule.kind == "no" then
        local n = count_with_tag(panel_items, rule.tag)
        return n == 0 and "pass" or "fail"
    elseif rule.kind == "specific" then
        for _, it in ipairs(panel_items) do
            if it.type_id == rule.type_id then return "pass" end
        end
        return "fail"
    elseif rule.kind == "all_unique" then
        local seen = {}
        for _, it in ipairs(panel_items) do
            if seen[it.type_id] then return "fail" end
            seen[it.type_id] = true
        end
        return "pass"
    end
    return "pass"
end

-- Human-readable description of a rule.
local function rule_label(rule, item_defs_ref)
    if rule.kind == "at_least" then
        return "At least " .. rule.n .. " \xc3\x97 " .. rule.tag
    elseif rule.kind == "no_more" then
        return "No more than " .. rule.n .. " \xc3\x97 " .. rule.tag
    elseif rule.kind == "no" then
        return "No " .. rule.tag
    elseif rule.kind == "specific" then
        local def = item_defs_ref and item_defs_ref[rule.type_id]
        local name = def and def.name or rule.type_id
        return "Must include: " .. name
    elseif rule.kind == "all_unique" then
        return "All dishes unique"
    end
    return rule.kind
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
    self.should_serve    = false
    self.should_skip     = false
    self._dragging_panel = false
    -- Program merchant: tracks how many machines from each program have been
    -- placed on the floor (used for program completion tracking).
    self._machines_placed  = {}

    local panel = item.panel
    self.grid_w = panel.cols * panel.cell_size
    self.grid_h = panel.rows * panel.cell_size

    -- Reminder height: dynamic for orders (scales with rule count); small
    -- header for restock panels (shows per-item cost).
    self._reminder_h = 0
    if item.kind == "order" then
        self._reminder_h = order_reminder_h(#(item.order_rules or {}))
    end

    -- Button row sizing: any def.actions plus one more slot for "Leave" when
    -- this is a merchant-kind item, or two more slots ("Serve" + "Skip")
    -- when this is an order-kind item. Neither "Leave" nor "Serve"/"Skip"
    -- are def.actions entries (there's no matching action def to look up
    -- for any of them) - they're additive to the same row/centering math.
    -- kind == "merchant" and kind == "order" are mutually exclusive, so a
    -- simple branch is fine.
    local actions = (self.def and self.def.actions) or {}
    local extra_buttons = 0
    if item.kind == "merchant" or item.kind == "restock" or item.kind == "program" then
        extra_buttons = 1
    elseif item.kind == "order" then
        extra_buttons = 2
    end
    local button_count = #actions + extra_buttons
    self._button_total_w = button_count * BUTTON_W + math.max(0, button_count - 1) * BUTTON_GAP

    -- Overall backdrop size: wide enough for the grid or button row (plus
    -- margins), or the title bar (name + close button), whichever is widest.
    local title_text = (self.def and self.def.name) or item.type_id
    local title_text_w = love.graphics.getFont():getWidth(title_text)
    -- title_min_bg_w is a full bg_w: 8px left pad + text + gap + close + right gap
    local title_min_bg_w = 8 + title_text_w + CLOSE_GAP + CLOSE_SIZE + CLOSE_GAP
    self.bg_w = math.max(self.grid_w + MARGIN * 2, self._button_total_w + MARGIN * 2, title_min_bg_w)
    self.bg_h = TITLE_H + MARGIN + self._reminder_h + self.grid_h + BUTTON_GAP + BUTTON_H + MARGIN

    -- Default position: centered horizontally, sitting just above the
    -- split line so it doesn't overlap the main floor grid.
    local default_x = (config.SCREEN_W - self.bg_w) / 2
    local default_y = math.max(8, config.SPLIT_Y - self.bg_h - 12)

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
    self.grid_y = bg_y + TITLE_H + MARGIN + self._reminder_h

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
    -- purely an ItemPanel-level button for merchant-kind items. "Serve" and
    -- "Skip" are the order-kind equivalent, occupying the next two slots.
    if self.item.kind == "merchant" or self.item.kind == "restock" or self.item.kind == "program" then
        local bx = start_x + slot * (BUTTON_W + BUTTON_GAP)
        self.buttons["Leave"] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
        slot = slot + 1
    elseif self.item.kind == "order" then
        local bx = start_x + slot * (BUTTON_W + BUTTON_GAP)
        self.buttons["Serve"] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
        slot = slot + 1

        bx = start_x + slot * (BUTTON_W + BUTTON_GAP)
        self.buttons["Skip"] = { x = bx, y = by, w = BUTTON_W, h = BUTTON_H }
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

    return #Item.matching_recipes(action, self.item.panel) > 0
end

-- Whether "Serve" is currently clickable: order-kind only, panel has ≥ 1 item
-- and every rule passes (no rule in "fail" state; "warn" is acceptable for
-- no_more since the item is at the limit but not exceeding it).
function ItemPanel:_serve_enabled()
    if self.item.kind ~= "order" then return false end
    local panel_items = self.item.panel:items()
    if #panel_items < 1 then return false end
    for _, it in ipairs(panel_items) do
        if #it.tags == 0 then return false end
    end
    for _, rule in ipairs(self.item.order_rules or {}) do
        if eval_rule(rule, panel_items) == "fail" then return false end
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
        local locked = false
        for _, state in pairs(self.item.action_state or {}) do
            if state.running then locked = true; break end
        end
        if not locked then
            local grid = self.item.grid
            while grid and grid.owner do
                for _, state in pairs(grid.owner.action_state or {}) do
                    if state.running then locked = true; break end
                end
                if locked then break end
                grid = grid.owner.grid
            end
        end
        if not locked then
            self.item.panel:mouse_pressed(x, y)
        end
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

    -- "Serve" / "Skip" (order-kind only, absent otherwise): like "Leave"
    -- above, these only raise flags for the caller (KitchenScene) to act
    -- on - ItemPanel itself never touches the panel's items, the Customer,
    -- or day_state. Serve only fires when enabled; an out-of-range click
    -- still counts as "landed on the button" (absorbed, no-op), same as a
    -- disabled action button below.
    if self.buttons["Serve"] and point_in_rect(x, y, self.buttons["Serve"]) then
        if self:_serve_enabled() then
            self.should_close = true
            self.should_serve = true
        end
        return true
    end

    if self.buttons["Skip"] and point_in_rect(x, y, self.buttons["Skip"]) then
        self.should_close = true
        self.should_skip = true
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
    else
        self.item.panel:clear_hover()
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

    if self.item.kind == "order" and self._reminder_h > 0 then
        local panel_items = self.item.panel:items()
        local rules       = self.item.order_rules or {}
        local base_y      = tb.y + TITLE_H + RULE_PAD

        for i, rule in ipairs(rules) do
            local status = eval_rule(rule, panel_items)
            local color
            if #panel_items == 0 then
                color = COLOR_NEUTRAL
            elseif status == "pass" then
                color = COLOR_PASS
            elseif status == "warn" then
                color = COLOR_WARN
            else
                color = COLOR_FAIL
            end
            local indicator = (status == "pass") and "\xe2\x9c\x93 " or "\xe2\x9c\x97 "
            if status == "warn" then indicator = "\xe2\x97\x90 " end
            if #panel_items == 0 then indicator = "  " end
            love.graphics.setColor(color)
            love.graphics.print(indicator .. rule_label(rule, item_defs), self.bg.x + MARGIN, base_y + (i - 1) * RULE_ROW_H)
        end
    end

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

    -- "Serve" / "Skip" (order-kind only): Serve uses the same
    -- disabled/enabled color split as the action buttons above, since
    -- whether it's clickable depends on the panel's current contents; Skip
    -- is always drawn in the normal enabled color - it isn't a warning
    -- action the way Leave/close are, so it doesn't use COLOR_LEAVE.
    local serve_rect = self.buttons["Serve"]
    if serve_rect then
        local enabled = self:_serve_enabled()
        local color = enabled and (colors.button or { 0.3, 0.55, 0.3, 1 }) or COLOR_DISABLED
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", serve_rect.x, serve_rect.y, serve_rect.w, serve_rect.h)
        love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
        love.graphics.print("Serve", serve_rect.x + 6, serve_rect.y + 6)
    end

    local skip_rect = self.buttons["Skip"]
    if skip_rect then
        love.graphics.setColor(colors.button or { 0.3, 0.55, 0.3, 1 })
        love.graphics.rectangle("fill", skip_rect.x, skip_rect.y, skip_rect.w, skip_rect.h)
        love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
        love.graphics.print("Skip", skip_rect.x + 6, skip_rect.y + 6)
    end

    local cb = self.close_button
    love.graphics.setColor(COLOR_CLOSE)
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print("X", cb.x + cb.w / 2 - 4, cb.y + cb.h / 2 - 8)

    love.graphics.setColor(1, 1, 1, 1)
end

return ItemPanel
