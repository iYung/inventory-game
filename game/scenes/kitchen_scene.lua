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
local ProgramState    = require("lua/game/program_state")

local DOUBLE_CLICK_WINDOW = 0.35
local SKIP_MESSAGE = "Maybe next time!"

local NEXT_DAY_BTN = {
    x = config.SCREEN_W - 170,
    y = config.SPLIT_Y - 56,
    w = 150,
    h = 40,
}

local SUMMARY_BTN = { x = 540, y = 470, w = 200, h = 44 }

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

    -- Starting layout: microwave (0,0), fryer (0,2), starters at (2,0)-(4,0),
    -- broccoli/potato at (5,0)/(6,0), container at (2,2), coffee_machine at (7,2),
    -- garden at (0,4). Cell (5,3) is intentionally left free.
    local microwave = Item.new("microwave")
    self.grid:place(microwave, 0, 0)

    local fryer = Item.new("fryer")
    self.grid:place(fryer, 0, 2)

    local starter = { "raw_chicken", "raw_chicken", "raw_chicken" }
    local col, row = 2, 0
    for _, type_id in ipairs(starter) do
        local it = Item.new(type_id)
        if self.grid:can_place(it, col, row) then
            self.grid:place(it, col, row)
            col = col + 1
            if col >= config.GRID_COLS then col = 0; row = row + 1 end
        end
    end

    self.grid:place(Item.new("broccoli"),       5, 0)
    self.grid:place(Item.new("potato"),         6, 0)
    self.grid:place(Item.new("coffee_machine"), 6, 2)

    local container = Item.new("container")
    self.grid:place(container, 4, 4)
    container.panel:place(Item.new("roasted_coffee_bean"), 0, 0)
    container.panel:place(Item.new("roasted_coffee_bean"), 1, 0)
    container.panel:place(Item.new("milking_center"),      2, 0)
    container.panel:place(Item.new("cheese_cave"),         3, 0)

    self.grid:place(Item.new("garden"),         0, 4)

    self._scene_bg = love.graphics.newImage("assets/images/scene/bg.png")
    self._scene_fg = love.graphics.newImage("assets/images/scene/fg.png")

    self.day_state    = DayState.new()
    self.program_state = ProgramState.new("fryer")
    self.queue = CustomerQueue.new(self.day_state.day, self.program_state)
    self.day_state:start_day(self.queue.total)

    -- Matches ../wip's convention: customers enter from off-screen on one
    -- side and walk toward target_x, then walk back out the way they came.
    -- exit_x sits left of the stage (negative = off-screen left) so
    -- walking_in moves left-to-right, like wip's customers do.
    local target_x = config.SCREEN_W / 2
    local exit_x    = -150
    local y         = 226  -- counter at waist (sill_y=270, belt=(47/72)*CH from top, center=270-(belt-CH/2))
    self.customer = Customer.new(target_x, exit_x, y)
    self.customer:show(self.queue:next())

    -- Any number of item panels can be open at once, ordered back-to-front
    -- (self.panels[#self.panels] is topmost/most-recently-focused).
    self.panels = {}

    self._last_click_time = nil
    self._last_click_grid = nil
    self._last_click_col  = nil
    self._last_click_row  = nil

    self._showing_summary = false
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

-- Returns true when `grid` is the active merchant customer's stock panel
-- (kind "restock" or "program"). Used to guard panel-open and drag actions.
function KitchenScene:_is_merchant_grid(grid)
    if not self.customer:active() then return false end
    local kind = self.customer.kind
    if kind ~= "restock" and kind ~= "program" then return false end
    return grid == self.customer.panel
end

-- Returns true if the player can afford to drag the merchant item at (x,y).
-- Only meaningful when _is_merchant_grid(self.customer.panel) is true.
function KitchenScene:_can_afford_merchant_item(x, y)
    local col, row = self.customer.panel:world_to_cell(x, y)
    local item = self.customer.panel:item_at(col, row)
    if not item then return true end

    if self.customer.kind == "restock" then
        return self.day_state.currency >= config.RESTOCK_ITEM_COST
    elseif self.customer.kind == "program" then
        if item.is_extra then
            return self.day_state.currency >= config.RESTOCK_ITEM_COST
        elseif item.program_id then
            local prog_id = item.program_id
            if self.program_state:owns(prog_id) then return true end
            local src_panel = self:_panel_for(self.customer)
            if src_panel and src_panel._paid_programs[prog_id] then return true end
            for _, p in ipairs(self.customer.offer or {}) do
                if p.id == prog_id then
                    return self.day_state.currency >= p.cost
                end
            end
        end
    end
    return true
end

-- Returns the open ItemPanel whose inner grid matches `grid`, or nil.
function KitchenScene:_open_panel_for_grid(grid)
    for _, panel in ipairs(self.panels) do
        if panel.item.panel == grid then return panel end
    end
    return nil
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
    if self.grid:_point_in_bounds(x, y) then
        return self.grid
    end
    return nil
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
    grid:clear_hover()
end

-- Moves the item currently being dragged on `from_grid` onto `to_grid` at
-- world position (x,y), for dragging an item off the main floor grid into
-- an open item panel (or back out again). Falls back to placing the item
-- back at its pre-drag cell on `from_grid` if `to_grid` can't take it there.
local function transfer_drag(from_grid, to_grid, item, x, y)
    local orig_col, orig_row = from_grid.drag_orig_col, from_grid.drag_orig_row
    clear_drag(from_grid, item)
    to_grid:clear_hover()

    local col, row = to_grid:_snap_cell_for(item)
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
    to_grid:clear_hover()

    if not to_grid:place_first_fit(item) then
        from_grid:place(item, orig_col, orig_row)
    end
end

-- Returns true iff any action on `item` is currently running.
local function any_action_running(item)
    for _, state in pairs(item.action_state or {}) do
        if state.running then return true end
    end
    return false
end

-- Returns true iff any ancestor container of `item` (at any depth) is
-- currently running an action.
local function ancestor_processing(item)
    local grid = item.grid
    while grid and grid.owner do
        if any_action_running(grid.owner) then return true end
        grid = grid.owner.grid
    end
    return false
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
            if ancestor_processing(item) then
                return false
            end
            if self:_is_merchant_grid(grid) then
                return false
            end

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
    if ancestor_processing(item) then return end
    if self:_is_merchant_grid(grid) then return end
    self:_open_or_focus_panel(item)
end

-- Mouse / keyboard wiring --------------------------------------------------

function KitchenScene:mouse_pressed(x, y)
    -- Summary overlay is modal: only the Continue button is live.
    if self._showing_summary then
        if point_in_rect(x, y, SUMMARY_BTN) then
            self.day_state:advance_day()
            self.queue = CustomerQueue.new(self.day_state.day, self.program_state)
            self.day_state:start_day(self.queue.total)
            self.customer:show(self.queue:next())
            for _, item in ipairs(self.grid:items()) do
                item:refill_daily()
            end
            for _, item in ipairs(self.grid:items()) do
                item:overnight_tick()
            end
            self._showing_summary = false
        end
        return
    end

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
                if self:_is_merchant_grid(panel.item.panel)
                   and not self:_can_afford_merchant_item(x, y) then
                    return
                end
            end
            panel:mouse_pressed(x, y)
            -- "Leave" (merchant-only) sets should_close AND should_leave
            -- together on the same click; check should_leave first since
            -- should_close is what actually removes the panel below.
            if panel.should_leave then
                self.customer:dismiss()
                self.day_state:record_dismiss()
            end
            if panel.should_serve then
                local panel_items = panel.item.panel:items()
                local type_ids = {}
                for _, it in ipairs(panel_items) do
                    type_ids[#type_ids + 1] = it.type_id
                    panel.item.panel:remove(it)
                end
                self.customer:serve()
                self.day_state:record_serve(type_ids, self.customer.payout)
            end
            if panel.should_skip then
                local items = {}
                for _, it in ipairs(panel.item.panel:items()) do
                    items[#items + 1] = it
                end
                for _, it in ipairs(items) do
                    panel.item.panel:remove(it)
                    self.grid:place_first_fit(it)
                end
                self.customer:dismiss(SKIP_MESSAGE)
                self.day_state:record_dismiss()
            end
            if panel.should_close then
                self:_close_panel(panel)
            end
            return
        end
    end

    if self:_next_day_ready() and point_in_rect(x, y, NEXT_DAY_BTN) then
        self._showing_summary = true
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
        if (self.customer.kind == "restock" or self.customer.kind == "program" or self.customer.kind == "merchant") and self.customer:arrived() then
            self:_open_or_focus_panel(self.customer)
            return
        end
        if self.customer.kind == "order" and self.customer:arrived() and self.customer.done_talking then
            self:_open_or_focus_panel(self.customer)
            return
        end
        if self.customer.state == "talking_after" then
            self.customer:advance_after()
        elseif self.customer:arrived() then
            self.customer:advance()
            -- If advancing just finished the last greeting line, open the
            -- order panel immediately instead of making the player click again
            -- through a silent "customer stands there" state.
            if self.customer.kind == "order" and self.customer.done_talking then
                self:_open_or_focus_panel(self.customer)
            end
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
        -- No active drag: forward to all grids so hover state and title-bar
        -- panel dragging (_dragging_panel) are updated everywhere.
        self.grid:mouse_moved(x, y)
        for _, panel in ipairs(self.panels) do panel:mouse_moved(x, y) end

        -- Suppress hover for every grid occluded by a higher-z panel so
        -- draw_labels() never renders a label on top of a covering panel.
        -- Walk back-to-front to find the topmost panel whose backdrop covers
        -- (x,y); clear hover for the floor grid and every panel below it.
        local top_cover = nil
        for i = #self.panels, 1, -1 do
            if self.panels[i]:_point_in_bg(x, y) then
                top_cover = self.panels[i]
                break
            end
        end
        if top_cover then
            self.grid:clear_hover()
            for _, panel in ipairs(self.panels) do
                if panel ~= top_cover then
                    panel.item.panel:clear_hover()
                end
            end
        end

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

    -- Dropped onto a has_panel item inside a panel grid (e.g. an item dragged
    -- from the main floor or from inside the same panel and dropped onto a
    -- nested container): same first-fit insertion as the main-floor container
    -- case above. Covers both cross-panel drops (hover != owner) and same-panel
    -- drops (hover == owner) - the latter is the case where both the dragged
    -- item and the target container already live inside the same parent panel.
    -- Only applies when the ancestor container is not currently running.
    if hover ~= nil and hover ~= self.grid then
        local col, row = hover:world_to_cell(x, y)
        local nested = hover:item_at(col, row)
        if nested and nested ~= item and nested.panel and not ancestor_processing(nested) then
            transfer_drag_first_fit(owner, nested.panel, item)
            return
        end
    end

    -- Otherwise: dropped somewhere on a grid (main floor, or any open
    -- panel's) - transfer it there if that's a different grid than it
    -- started on, or just let it resolve normally (place/snap-back) if
    -- dropped back where it came from.
    if hover ~= nil and hover ~= owner then
        -- Never allow dropping onto the merchant's own stock panel.
        if self:_is_merchant_grid(hover) then
            owner:mouse_released(x, y)
            return
        end
        -- Merchant panels: check currency before transferring to the floor.
        if hover == self.grid then
            local src_panel = self:_open_panel_for_grid(owner)
            if src_panel and src_panel.item.kind == "restock" then
                local cost = config.RESTOCK_ITEM_COST
                if self.day_state.currency < cost then
                    owner:mouse_released(x, y)  -- snap back
                    return
                end
                self.day_state.currency = self.day_state.currency - cost
            elseif src_panel and src_panel.item.kind == "program" then
                if item.is_extra then
                    -- Extras: flat restock cost, always buyable, no completion tracking.
                    local cost = config.RESTOCK_ITEM_COST
                    if self.day_state.currency < cost then
                        owner:mouse_released(x, y)
                        return
                    end
                    self.day_state.currency = self.day_state.currency - cost
                elseif item.program_id then
                    local prog_id = item.program_id
                    local prog = nil
                    for _, p in ipairs(src_panel.item.offer or {}) do
                        if p.id == prog_id then prog = p; break end
                    end
                    if prog and not self.program_state:owns(prog_id) then
                        -- Charge full program cost on the first machine drag.
                        if not src_panel._paid_programs[prog_id] then
                            if self.day_state.currency < prog.cost then
                                owner:mouse_released(x, y)
                                return
                            end
                            self.day_state.currency = self.day_state.currency - prog.cost
                            src_panel._paid_programs[prog_id] = true
                        end
                        -- Complete program when every machine has been placed.
                        src_panel._machines_placed[prog_id] = (src_panel._machines_placed[prog_id] or 0) + 1
                        if src_panel._machines_placed[prog_id] >= #prog.machines then
                            self.program_state:buy(prog_id)
                        end
                    end
                end
            end
        end
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

    -- Scene background: sky, treeline, cobblestone street
    if self._scene_bg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._scene_bg, 0, 0)
    elseif colors.stage_bg then
        love.graphics.setColor(colors.stage_bg)
        love.graphics.rectangle("fill", 0, 0, config.SCREEN_W, config.SPLIT_Y)
    end

    -- Bottom half background (below the split line)
    love.graphics.setColor(0.09, 0.10, 0.13, 1)
    love.graphics.rectangle("fill", 0, config.SPLIT_Y, config.SCREEN_W, config.SCREEN_H - config.SPLIT_Y)

    -- Everything below draws its own actively-dragged item (if any) inline,
    -- at its position in that layer's stacking order. Skip that here and
    -- draw whichever item is actually being dragged once, last, on top of
    -- every other layer (customer, panel, HUD) - otherwise e.g. the
    -- customer sprite would occlude an item being dragged up toward them.
    self.grid:draw(true)

    -- Clip customer and fg frame to the top half so a large sprite never
    -- bleeds into the grid area below the split line.
    love.graphics.setScissor(0, 0, config.SCREEN_W, config.SPLIT_Y)

    -- Customer drawn before the foreground frame so the frame occludes their
    -- lower body, creating a sense of depth (counter is in front of them).
    love.graphics.setColor(1, 1, 1, 1)
    self.customer:draw()
    self.customer:draw_bubble()

    -- Foreground frame: metal posts and counter sill, overlaps customer
    if self._scene_fg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._scene_fg, 0, 0)
    end

    love.graphics.setScissor()

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

    -- Labels drawn last so they appear above every other layer: panels,
    -- buttons, HUD, and the dragged item sprite itself.
    for _, grid in ipairs(self:_all_grids()) do
        grid:draw_labels()
    end

    self.camera:detach()

    if self._showing_summary then
        -- backdrop
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, config.SCREEN_W, config.SCREEN_H)

        -- box
        local bx, by, bw, bh = 440, 160, 400, 330
        love.graphics.setColor(0.12, 0.12, 0.16, 1)
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        love.graphics.rectangle("line", bx, by, bw, bh)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Day " .. self.day_state.day .. " Summary", bx + 16, by + 16)

        local ly = by + 52
        local has_sales = false
        for type_id, count in pairs(self.day_state.sold_items) do
            local def = item_defs[type_id]
            local name = def and def.name or type_id
            love.graphics.print(name .. " \xc3\x97 " .. count, bx + 16, ly)
            ly = ly + 22
            has_sales = true
        end
        if not has_sales then
            love.graphics.print("Nothing sold", bx + 16, ly)
            ly = ly + 22
        end

        ly = ly + 10
        love.graphics.print("Revenue: $" .. self.day_state.currency, bx + 16, ly)
        ly = ly + 22
        love.graphics.print(
            "Customers: " .. self.day_state.customers_served .. "/" .. self.day_state.customers_total,
            bx + 16, ly
        )

        -- continue button
        local colors = config.COLORS or {}
        love.graphics.setColor(colors.button or { 0.3, 0.55, 0.3, 1 })
        love.graphics.rectangle("fill", SUMMARY_BTN.x, SUMMARY_BTN.y, SUMMARY_BTN.w, SUMMARY_BTN.h)
        love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
        love.graphics.print(
            "Start Day " .. (self.day_state.day + 1) .. " \xe2\x86\x92",
            SUMMARY_BTN.x + 12, SUMMARY_BTN.y + 14
        )
    end
end

return KitchenScene
