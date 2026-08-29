-- game/scenes/kitchen_scene.lua
--
-- Top-level scene for the cooking-inventory game: owns the main floor Grid,
-- the day/customer loop (DayState + CustomerQueue), the single on-stage
-- Customer, and an optional open ItemPanel. Static scene (no camera
-- movement) split at config.SPLIT_Y into a top-half customer stage and a
-- bottom-half inventory grid.
--
-- See docs/design/cooking-inventory-game.md and
-- docs/checklists/cooking-inventory-game.md (Wave 3 / Task F) for the
-- integration contract this file implements.

local Scene         = require("lua/core/scene")
local config         = require("lua/game/config")
local Grid           = require("lua/game/grid")
local Item           = require("lua/game/item")
local item_defs      = require("lua/game/data/item_defs")
local ItemPanel       = require("lua/game/item_panel")
local Customer        = require("lua/game/customer")
local CustomerQueue   = require("lua/game/customer_queue")
local DayState        = require("lua/game/day_state")

local DOUBLE_CLICK_WINDOW = 0.35

local NEXT_DAY_BTN = {
    x = config.SCREEN_W - 170,
    y = config.SPLIT_Y - 56,
    w = 150,
    h = 40,
}

local KitchenScene = {}
KitchenScene.__index = KitchenScene

function KitchenScene.new()
    local self = Scene.new(config.SCREEN_W, config.SCREEN_H)
    setmetatable(self, KitchenScene)
    -- All draw/hit-test code in this scene works in absolute top-left-origin
    -- screen coordinates (grid origin, customer x/y, HUD text at 16,16, ...).
    -- Camera:attach() always translates by (w/2, h/2) before subtracting the
    -- camera position, so the camera must sit at screen-center for that
    -- translation to net out to zero and leave (0,0) at the top-left corner.
    self.camera.x = config.SCREEN_W / 2
    self.camera.y = config.SCREEN_H / 2
    return self
end

-- Setup -----------------------------------------------------------------

function KitchenScene:on_enter()
    self.grid = Grid.new(
        config.GRID_COLS, config.GRID_ROWS, config.U,
        config.GRID_ORIGIN_X, config.GRID_ORIGIN_Y
    )

    -- Starting layout: one microwave (2x2, top-left area) and three raw meat
    -- items (1x1) placed to its right. Manually verified non-overlapping:
    -- microwave occupies (0,0)-(1,1); meat sits at (2,0), (3,0), (4,0).
    local microwave = Item.new("microwave")
    assert(self.grid:can_place(microwave, 0, 0), "microwave starting cell should be free")
    self.grid:place(microwave, 0, 0)

    local meat_cells = { { 2, 0 }, { 3, 0 }, { 4, 0 } }
    for _, cell in ipairs(meat_cells) do
        local meat = Item.new("raw_meat")
        assert(self.grid:can_place(meat, cell[1], cell[2]), "raw_meat starting cell should be free")
        self.grid:place(meat, cell[1], cell[2])
    end

    self.day_state = DayState.new()
    self.day_state:start_day(config.CUSTOMERS_PER_DAY)
    self.queue = CustomerQueue.new(config.CUSTOMERS_PER_DAY)

    local target_x = config.SCREEN_W / 2
    local exit_x    = config.SCREEN_W + 150
    local y         = config.SPLIT_Y / 2
    self.customer = Customer.new(target_x, exit_x, y)
    self.customer:show(self.queue:next())

    self.panel = nil

    self._last_click_time = nil
    self._last_click_col  = nil
    self._last_click_row  = nil
end

-- Frame tick --------------------------------------------------------------

function KitchenScene:update(dt)
    self.grid:update(dt)

    local was_active = self.customer:active()
    self.customer:update(dt)

    if was_active and not self.customer:active() and self.queue:has_next() then
        self.customer:show(self.queue:next())
    end
end

-- Helpers -----------------------------------------------------------------

local function point_in_rect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Whether (x,y) lands on the customer's on-screen body.
function KitchenScene:_customer_hit(x, y)
    local c = self.customer
    if not c:active() then return false end
    local s = c.sprite
    return x >= s.x and x <= s.x + s.width and y >= s.y and y <= s.y + s.height
end

-- Clears grid-drag bookkeeping without running Grid:mouse_released's normal
-- place-back-on-the-grid logic (the item is being consumed, not dropped).
local function clear_drag(grid, item)
    grid:remove(item)
    grid.dragging          = nil
    grid.drag_orig_col     = nil
    grid.drag_orig_row     = nil
    grid.drag_preview_col  = nil
    grid.drag_preview_row  = nil
end

-- Mouse / keyboard wiring --------------------------------------------------

function KitchenScene:mouse_pressed(x, y)
    if self.panel then
        self.panel:mouse_pressed(x, y)
        if self.panel.should_close then
            self.panel = nil
        end
        return
    end

    if self.day_state:day_complete() and point_in_rect(x, y, NEXT_DAY_BTN) then
        self.day_state:advance_day()
        self.day_state:start_day(config.CUSTOMERS_PER_DAY)
        self.queue = CustomerQueue.new(config.CUSTOMERS_PER_DAY)
        self.customer:show(self.queue:next())
        return
    end

    -- Double-click detection: a second press within DOUBLE_CLICK_WINDOW on
    -- the same cell of an item whose def has has_panel=true opens its panel
    -- instead of starting a drag.
    local col, row = self.grid:world_to_cell(x, y)
    local item      = self.grid:item_at(col, row)
    local now        = love.timer.getTime()

    if item then
        local def = item_defs[item.type_id]
        if def and def.has_panel then
            local is_double_click = self._last_click_time
                and (now - self._last_click_time) <= DOUBLE_CLICK_WINDOW
                and self._last_click_col == col
                and self._last_click_row == row

            if is_double_click then
                self.panel = ItemPanel.new(item)
                self._last_click_time = nil
                self._last_click_col  = nil
                self._last_click_row  = nil
                return
            end
        end
    end

    self._last_click_time = now
    self._last_click_col  = col
    self._last_click_row  = row

    self.grid:mouse_pressed(x, y)
end

function KitchenScene:mouse_moved(x, y)
    if self.panel then
        self.panel:mouse_moved(x, y)
    else
        self.grid:mouse_moved(x, y)
    end
end

function KitchenScene:mouse_released(x, y)
    -- Dropping a dragged main-grid item onto the waiting customer serves or
    -- dismisses them, consuming the item either way, instead of placing it
    -- back on the grid.
    if self.grid.dragging and self.customer:arrived() and self:_customer_hit(x, y) then
        local item = self.grid.dragging
        clear_drag(self.grid, item)

        if item.type_id == self.customer.requested_type then
            self.customer:serve()
            self.day_state:record_serve()
        else
            self.customer:dismiss()
            self.day_state:record_dismiss()
        end
        return
    end

    if self.panel then
        self.panel:mouse_released(x, y)
        return
    end

    self.grid:mouse_released(x, y)
end

function KitchenScene:rotate_dragged()
    if self.panel and self.panel.item.panel.dragging then
        self.panel.item.panel:rotate_dragged()
    elseif self.grid.dragging then
        self.grid:rotate_dragged()
    end
end

-- Draw ----------------------------------------------------------------------

function KitchenScene:draw()
    self.camera:attach()

    local colors = config.COLORS or {}

    if colors.stage_bg then
        love.graphics.setColor(colors.stage_bg)
        love.graphics.rectangle("fill", 0, 0, config.SCREEN_W, config.SPLIT_Y)
    end

    self.grid:draw()

    love.graphics.setColor(1, 1, 1, 1)
    self.customer:draw()
    self.customer:draw_bubble()

    if self.day_state:day_complete() then
        love.graphics.setColor(colors.button or { 0.3, 0.55, 0.3, 1 })
        love.graphics.rectangle("fill", NEXT_DAY_BTN.x, NEXT_DAY_BTN.y, NEXT_DAY_BTN.w, NEXT_DAY_BTN.h)
        love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
        love.graphics.print("Next Day", NEXT_DAY_BTN.x + 10, NEXT_DAY_BTN.y + 10)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Day " .. self.day_state.day, 16, 16)
    love.graphics.print(
        "Customers: " .. self.day_state.customers_served .. "/" .. self.day_state.customers_total,
        16, 36
    )
    love.graphics.print("$" .. self.day_state.currency, 16, 56)

    if self.panel then
        self.panel:draw()
    end

    self.camera:detach()
end

return KitchenScene
