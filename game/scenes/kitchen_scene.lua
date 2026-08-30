-- game/scenes/kitchen_scene.lua
--
-- Top-level scene for the cooking-inventory game: owns the main floor Grid,
-- the day/customer loop (DayState + CustomerQueue), the single on-stage
-- Customer, and any number of simultaneously open ItemPanels (self.panels,
-- back-to-front order). Static scene (no camera movement) split at
-- config.SPLIT_Y into a top-half customer stage and a bottom-half
-- inventory grid.
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

    -- A couple of raw broccoli too, so the Cook recipe that produces
    -- steamed_broccoli / the Healthy tag is actually reachable from the
    -- starting floor layout, not just via the merchant. (2,1)/(3,1) sit
    -- just below the meat row - clear of the microwave's (0,0)-(1,1)
    -- footprint and the meat at (2,0)/(3,0)/(4,0).
    local broccoli_cells = { { 2, 1 }, { 3, 1 } }
    for _, cell in ipairs(broccoli_cells) do
        local broccoli = Item.new("broccoli")
        assert(self.grid:can_place(broccoli, cell[1], cell[2]), "broccoli starting cell should be free")
        self.grid:place(broccoli, cell[1], cell[2])
    end

    -- A fryer (2x2) and a dutch oven (2x1) so both new cooking methods are
    -- reachable from the starting floor, plus a couple of raw potatoes to
    -- feed them. Cells chosen clear of the microwave (0,0)-(1,1), meat
    -- (2,0)/(3,0)/(4,0), and broccoli (2,1)/(3,1) footprints above, and of
    -- (5,0)/(5,3) which tests/test_kitchen_scene.lua relies on being free
    -- on the starting floor.
    local fryer = Item.new("fryer")
    assert(self.grid:can_place(fryer, 6, 0), "fryer starting cell should be free")
    self.grid:place(fryer, 6, 0)

    local dutch_oven = Item.new("dutch_oven")
    assert(self.grid:can_place(dutch_oven, 8, 0), "dutch_oven starting cell should be free")
    self.grid:place(dutch_oven, 8, 0)

    local potato_cells = { { 2, 2 }, { 3, 2 } }
    for _, cell in ipairs(potato_cells) do
        local potato = Item.new("potato")
        assert(self.grid:can_place(potato, cell[1], cell[2]), "potato starting cell should be free")
        self.grid:place(potato, cell[1], cell[2])
    end

    self.day_state = DayState.new()
    self.day_state:start_day(config.CUSTOMERS_PER_DAY)
    self.queue = CustomerQueue.new(config.CUSTOMERS_PER_DAY)

    -- Matches ../wip's convention: customers enter from off-screen on one
    -- side and walk toward target_x, then walk back out the way they came.
    -- exit_x sits left of the stage (negative = off-screen left) so
    -- walking_in moves left-to-right, like wip's customers do.
    local target_x = config.SCREEN_W / 2
    local exit_x    = -150
    local y         = config.SPLIT_Y / 2
    self.customer = Customer.new(target_x, exit_x, y)
    self.customer:show(self.queue:next())

    -- Any number of item panels can be open at once, ordered back-to-front
    -- (self.panels[#self.panels] is topmost/most-recently-focused).
    self.panels = {}

    self._last_click_time = nil
    self._last_click_grid = nil
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

-- Whether `item` carries `tag` among its Item.tags.
local function has_tag(item, tag)
    for _, t in ipairs(item.tags) do
        if t == tag then return true end
    end
    return false
end

-- Whether (x,y) lands on the customer's on-screen body.
function KitchenScene:_customer_hit(x, y)
    local c = self.customer
    if not c:active() then return false end
    local s = c.sprite
    return x >= s.x and x <= s.x + s.width and y >= s.y and y <= s.y + s.height
end

-- Whether the "Next Day" button should show/be clickable: the day's last
-- customer has to have actually left (walked all the way off and gone
-- idle), not just been served/dismissed - day_state:day_complete() flips
-- true the instant that happens, while they're still animating off-screen
-- (walking_out, or talking_after for a served food customer).
function KitchenScene:_next_day_ready()
    return self.day_state:day_complete() and not self.customer:active()
end

-- Multi-panel bookkeeping ---------------------------------------------------
--
-- Any number of item panels (microwave, merchant stock, ...) can be open at
-- once. self.panels is ordered back-to-front; the last entry draws on top
-- and is hit-tested first. At most one Grid total (the main floor grid, or
-- exactly one open panel's inner grid) ever has something mid-drag at a
-- time - only one mouse, one drag - so the helpers below just need to find
-- "the" dragging grid / "the" grid currently under the cursor among all of
-- them, generalizing what used to be hardcoded as "self.grid vs. the one
-- open panel's grid".

-- The panel already open for `item` (an Item on the floor grid, or the
-- merchant Customer), if any - used to avoid opening a duplicate.
function KitchenScene:_panel_for(item)
    for _, panel in ipairs(self.panels) do
        if panel.item == item then return panel end
    end
    return nil
end

local PANEL_CASCADE_OFFSET = 28 -- px, so newly opened panels don't perfectly overlap

function KitchenScene:_open_panel(panel)
    -- Cascade each successively opened panel down-right a bit so they don't
    -- all spawn stacked exactly on top of each other by default (still
    -- freely repositionable by dragging their title bar).
    local offset = PANEL_CASCADE_OFFSET * #self.panels
    if offset > 0 then
        panel:_layout(panel.bg.x + offset, panel.bg.y + offset)
    end
    table.insert(self.panels, panel)
end

function KitchenScene:_close_panel(panel)
    for i, p in ipairs(self.panels) do
        if p == panel then
            table.remove(self.panels, i)
            return
        end
    end
end

-- Moves an already-open panel to the front (end of the list = drawn last =
-- on top, hit-tested first).
function KitchenScene:_bring_to_front(panel)
    self:_close_panel(panel)
    table.insert(self.panels, panel)
end

-- Opens `item`'s panel, or brings its already-open one to front - the
-- shared "show me this item's inventory" action behind a double-click, a
-- right-click, and clicking a merchant.
function KitchenScene:_open_or_focus_panel(item)
    local existing = self:_panel_for(item)
    if existing then
        self:_bring_to_front(existing)
    else
        self:_open_panel(ItemPanel.new(item))
    end
end

-- self.grid plus every open panel's inner Grid, in the same back-to-front
-- order as self.panels.
function KitchenScene:_all_grids()
    local grids = { self.grid }
    for _, panel in ipairs(self.panels) do
        grids[#grids + 1] = panel.item.panel
    end
    return grids
end

-- Whichever single grid (main floor, or an open panel's) currently has an
-- item mid-drag, or nil if nothing is being dragged anywhere right now.
function KitchenScene:_dragging_grid()
    if self.grid.dragging then return self.grid end
    for _, panel in ipairs(self.panels) do
        if panel.item.panel.dragging then return panel.item.panel end
    end
    return nil
end

-- Whichever grid's cell area world position (x,y) is actually over right
-- now: the topmost open panel whose OWN grid (not just its backdrop)
-- contains the point, else the main floor grid by default (out-of-bounds
-- drops there are simply rejected by can_place at drop time, same as
-- always). Panels are checked topmost-first so an overlapping panel in
-- front correctly wins over one (partially) behind it.
function KitchenScene:_hover_grid(x, y)
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        if panel:_point_in_grid(x, y) then
            return panel.item.panel
        end
    end
    return self.grid
end

-- The has_panel item sitting on the main floor grid at world (x,y), if
-- any - used so dropping an ingredient directly onto e.g. the microwave
-- inserts it into the microwave's own panel (first-fit) instead of just
-- failing to place on the main grid (which the microwave already occupies)
-- and snapping back.
function KitchenScene:_container_at(x, y)
    local col, row = self.grid:world_to_cell(x, y)
    local target = self.grid:item_at(col, row)
    if target and target.panel then
        return target
    end
    return nil
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

-- Moves the item currently being dragged on `from_grid` onto `to_grid` at
-- world position (x,y), for dragging an item off the main floor grid into
-- an open item panel (or back out again). Falls back to placing the item
-- back at its pre-drag cell on `from_grid` if `to_grid` can't take it there.
local function transfer_drag(from_grid, to_grid, item, x, y)
    local orig_col, orig_row = from_grid.drag_orig_col, from_grid.drag_orig_row
    clear_drag(from_grid, item)

    local col, row = to_grid:world_to_cell(x, y)
    if to_grid:can_place(item, col, row) then
        to_grid:place(item, col, row)
    else
        from_grid:place(item, orig_col, orig_row)
    end
end

-- Same idea as transfer_drag, but for dropping an item straight onto a
-- container sitting on the main floor grid (e.g. dragging raw meat onto the
-- microwave itself) rather than onto an open panel: there's no cursor cell
-- inside to_grid to target (its origin is only meaningful once its
-- ItemPanel is actually open), so it goes into the first free cell instead.
local function transfer_drag_first_fit(from_grid, to_grid, item)
    local orig_col, orig_row = from_grid.drag_orig_col, from_grid.drag_orig_row
    clear_drag(from_grid, item)

    if not to_grid:place_first_fit(item) then
        from_grid:place(item, orig_col, orig_row)
    end
end

-- Checks (x,y) against `grid` for the double-click-to-open-panel
-- gesture: if a has_panel item sits at that cell AND this is a second
-- click within DOUBLE_CLICK_WINDOW on the same cell of the same grid,
-- opens/focuses its panel and returns true (caller should stop, not
-- fall through to that grid's normal drag-start handling). Otherwise
-- records this click's bookkeeping and returns false.
function KitchenScene:_try_double_click_open(grid, x, y)
    local col, row = grid:world_to_cell(x, y)
    local item      = grid:item_at(col, row)
    local now        = love.timer.getTime()

    if item then
        local def = item_defs[item.type_id]
        if def and def.has_panel then
            local is_double_click = self._last_click_time
                and (now - self._last_click_time) <= DOUBLE_CLICK_WINDOW
                and self._last_click_grid == grid
                and self._last_click_col == col
                and self._last_click_row == row

            if is_double_click then
                self:_open_or_focus_panel(item)
                self._last_click_time = nil
                self._last_click_grid = nil
                self._last_click_col  = nil
                self._last_click_row  = nil
                return true
            end
        end
    end

    self._last_click_time = now
    self._last_click_grid = grid
    self._last_click_col  = col
    self._last_click_row  = row
    return false
end

-- Opens/focuses the has_panel item on `grid` at world (x,y), if any - the
-- shared helper behind right-click's one-click-to-open gesture. No
-- timing/double-click logic (that's _try_double_click_open, used by
-- mouse_pressed only).
function KitchenScene:_open_container_at(grid, x, y)
    local col, row = grid:world_to_cell(x, y)
    local item      = grid:item_at(col, row)
    if not item then return end
    local def = item_defs[item.type_id]
    if not (def and def.has_panel) then return end
    self:_open_or_focus_panel(item)
end

-- Mouse / keyboard wiring --------------------------------------------------

function KitchenScene:mouse_pressed(x, y)
    -- Panels are opaque windows, hit-tested topmost-first. A click landing
    -- anywhere on an open panel's backdrop is claimed by it - even if it
    -- misses every interactive element inside (dead space) - so it never
    -- reaches whatever's behind it (another panel, or the game underneath).
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        if panel:_point_in_bg(x, y) then
            self:_bring_to_front(panel)
            if panel:_point_in_grid(x, y) then
                if self:_try_double_click_open(panel.item.panel, x, y) then return end
            end
            panel:mouse_pressed(x, y)
            -- "Leave" (merchant-only) sets should_close AND should_leave
            -- together on the same click; check should_leave first since
            -- should_close is what actually removes the panel below.
            if panel.should_leave then
                self.customer:dismiss()
                self.day_state:record_dismiss()
            end
            if panel.should_close then
                self:_close_panel(panel)
            end
            return
        end
    end

    if self:_next_day_ready() and point_in_rect(x, y, NEXT_DAY_BTN) then
        self.day_state:advance_day()
        self.day_state:start_day(config.CUSTOMERS_PER_DAY)
        self.queue = CustomerQueue.new(config.CUSTOMERS_PER_DAY)
        self.customer:show(self.queue:next())
        return
    end

    -- A plain click on the customer (not a drag-and-drop, that's handled in
    -- mouse_released) advances their dialogue: steps through pre-serve
    -- messages while waiting, or - crucially - steps through/finishes the
    -- post-serve thank-you message, which is what actually sends a served
    -- customer into walking_out. Without this a served customer just stands
    -- there showing their last line forever.
    if self.customer:active() and self:_customer_hit(x, y) then
        -- A merchant doesn't have dialogue to advance through past their
        -- greeting - clicking their body opens their stock panel instead
        -- (or brings it to front if it's already open, e.g. buried behind
        -- another panel).
        if self.customer.kind == "merchant" and self.customer:arrived() then
            self:_open_or_focus_panel(self.customer)
            return
        end
        if self.customer.state == "talking_after" then
            self.customer:advance_after()
        elseif self.customer:arrived() then
            self.customer:advance()
        end
        return
    end

    -- Double-click detection: a second press within DOUBLE_CLICK_WINDOW on
    -- the same cell of an item whose def has has_panel=true opens its panel
    -- (or brings an already-open one to front) instead of starting a drag.
    if self:_try_double_click_open(self.grid, x, y) then return end

    self.grid:mouse_pressed(x, y)
end

-- Right-click: a one-click shortcut for the double-click-to-open-panel
-- gesture above, on the same targets (a main-grid item with has_panel).
-- Doesn't touch dragging, the customer, or Next Day - a right-click that
-- misses a has_panel item is simply a no-op.
function KitchenScene:mouse_right_pressed(x, y)
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        if panel:_point_in_bg(x, y) then
            if panel:_point_in_grid(x, y) then
                self:_open_container_at(panel.item.panel, x, y)
            end
            return
        end
    end

    self:_open_container_at(self.grid, x, y)
end

function KitchenScene:mouse_moved(x, y)
    local owner = self:_dragging_grid()

    if not owner then
        -- No active drag: every grid's mouse_moved is a no-op, harmless to
        -- forward to all of them unconditionally.
        self.grid:mouse_moved(x, y)
        for _, panel in ipairs(self.panels) do panel:mouse_moved(x, y) end
        return
    end

    -- Update the owning grid normally first - via its own world_to_cell,
    -- this is what keeps the dragged item's sprite following the cursor no
    -- matter which grid is actually being hovered right now (Item:draw()
    -- defers to whatever position Grid:_position_dragging_sprite sets here,
    -- for as long as item.grid.dragging == item).
    owner:mouse_moved(x, y)

    -- Then fix up which single grid's PREVIEW is actually shown: whichever
    -- one the cursor is over, using ITS OWN coordinate system - not
    -- necessarily the owner (ItemPanel:mouse_moved would otherwise keep
    -- forwarding to the owner regardless of cursor position, which is what
    -- made the preview snap to the wrong grid's cell alignment).
    local hover = self:_hover_grid(x, y)
    local item  = owner.dragging

    for _, grid in ipairs(self:_all_grids()) do
        if grid == owner then
            if grid ~= hover then
                grid.drag_preview_col, grid.drag_preview_row = nil, nil
            end
        elseif grid == hover then
            grid:preview_override(item, x, y)
        else
            grid:clear_preview_override()
        end
    end
end

function KitchenScene:mouse_released(x, y)
    -- A panel being dragged by its own title bar takes priority over
    -- everything below, and must go through ItemPanel:mouse_released (not
    -- some inner grid directly) since that's what clears _dragging_panel.
    for _, panel in ipairs(self.panels) do
        if panel._dragging_panel then
            panel:mouse_released(x, y)
            return
        end
    end

    local owner = self:_dragging_grid()

    -- Whatever's being dragged is about to be resolved one way or another
    -- below; clear every grid's cross-grid preview override now so nothing
    -- stale lingers into the next frame's draw before a new mouse_moved
    -- would otherwise refresh it.
    for _, grid in ipairs(self:_all_grids()) do
        grid:clear_preview_override()
    end

    if not owner then
        return
    end

    local item = owner.dragging

    -- Dropping a dragged item - from the main grid or any open panel (e.g.
    -- cooked meat straight out of the microwave, or stock straight out of
    -- a merchant) - onto the waiting customer serves or dismisses them,
    -- consuming the item either way, instead of placing it back wherever
    -- it came from. Not applicable to a merchant (no order to fulfill).
    if self.customer:arrived() and self.customer.kind ~= "merchant" and self:_customer_hit(x, y) then
        clear_drag(owner, item)

        if has_tag(item, self.customer.requested_tag) then
            self.customer:serve()
            self.day_state:record_serve()
        else
            -- A message here (unlike the merchant Leave case below, which
            -- passes none) makes a wrong-item drop read as a clear
            -- rejection instead of the customer just silently walking off
            -- indistinguishably from a successful serve.
            self.customer:dismiss("Sorry, that's not what I ordered!")
            self.day_state:record_dismiss()
        end
        return
    end

    local hover = self:_hover_grid(x, y)

    -- Dropped directly onto a has_panel item's own footprint on the main
    -- floor grid (e.g. raw meat dropped right on the microwave): insert it
    -- into that item's panel (first-fit) instead of failing to place on
    -- the main grid there (which the container already occupies) and
    -- snapping back. Not applicable when already dragging out of that same
    -- panel (nothing to do) or dragging the container onto itself.
    if hover == self.grid then
        local container = self:_container_at(x, y)
        if container and container ~= item and container.panel ~= owner then
            transfer_drag_first_fit(owner, container.panel, item)
            return
        end
    end

    -- Otherwise: dropped somewhere on a grid (main floor, or any open
    -- panel's) - transfer it there if that's a different grid than it
    -- started on, or just let it resolve normally (place/snap-back) if
    -- dropped back where it came from.
    if hover ~= owner then
        transfer_drag(owner, hover, item, x, y)
    else
        owner:mouse_released(x, y)
    end
end

function KitchenScene:rotate_dragged()
    local owner = self:_dragging_grid()
    if owner then owner:rotate_dragged() end
end

-- Draw ----------------------------------------------------------------------

function KitchenScene:draw()
    self.camera:attach()

    local colors = config.COLORS or {}

    if colors.stage_bg then
        love.graphics.setColor(colors.stage_bg)
        love.graphics.rectangle("fill", 0, 0, config.SCREEN_W, config.SPLIT_Y)
    end

    -- Everything below draws its own actively-dragged item (if any) inline,
    -- at its position in that layer's stacking order. Skip that here and
    -- draw whichever item is actually being dragged once, last, on top of
    -- every other layer (customer, panel, HUD) - otherwise e.g. the
    -- customer sprite would occlude an item being dragged up toward them.
    self.grid:draw(true)

    love.graphics.setColor(1, 1, 1, 1)
    self.customer:draw()
    self.customer:draw_bubble()

    if self:_next_day_ready() then
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

    -- Panels draw back-to-front (self.panels is already in that order), so
    -- a panel later in the list correctly overlaps one earlier in it.
    for _, panel in ipairs(self.panels) do
        panel:draw(true)
    end

    local owner = self:_dragging_grid()
    if owner and owner.dragging and owner.dragging.draw then
        owner.dragging:draw()
    end

    self.camera:detach()
end

return KitchenScene
