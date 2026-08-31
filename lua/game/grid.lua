-- lua/game/grid.lua
-- Generic cell-grid: occupancy, placement/collision, drag, rotate.
-- Used both for the main floor grid and for an item's inner panel grid.
--
-- Cells are 0-indexed (col/row run 0..cols-1 / 0..rows-1) so that footprint
-- offsets ({dx,dy} pairs, see item.lua contract) can be added directly to an
-- anchor cell without an off-by-one.
--
-- Grid does NOT know about love.mouse - mouse_pressed/moved/released take
-- already-resolved world-space x/y (same space as origin_x/origin_y).

local Grid = {}
Grid.__index = Grid

function Grid.new(cols, rows, cell_size, origin_x, origin_y)
    local self = setmetatable({}, Grid)
    self.cols      = cols
    self.rows      = rows
    self.cell_size = cell_size
    self.origin_x  = origin_x or 0
    self.origin_y  = origin_y or 0

    self._items = {} -- items currently placed/tracked on this grid

    self.dragging          = nil -- item currently being dragged, or nil
    self.drag_orig_col     = nil
    self.drag_orig_row     = nil
    self.drag_preview_col  = nil
    self.drag_preview_row  = nil
    self.drag_cursor_x     = nil -- raw world-space cursor pos while dragging
    self.drag_cursor_y     = nil
    self.drag_offset_x     = nil -- px offset from cursor to sprite top-left
    self.drag_offset_y     = nil

    -- Set by an external owner (the scene) to show a drop-preview for an
    -- item that's being dragged on a DIFFERENT grid but is currently
    -- hovering over this one - see preview_override()/clear_preview_override().
    self._preview_override_item = nil
    self._preview_override_col  = nil
    self._preview_override_row  = nil

    self._hover_col = nil
    self._hover_row = nil

    return self
end

-- Positions the dragging item's sprite so the cursor stays at the same
-- relative point within the sprite as where the user originally clicked.
-- Item:draw() skips its own cell-based repositioning while
-- `item.grid.dragging == item`, deferring to whatever position is set here.
function Grid:_position_dragging_sprite()
    if not self.dragging or not self.dragging.sprite then return end
    if not self.drag_cursor_x or not self.drag_offset_x then return end
    local s = self.dragging.sprite
    s.x = self.drag_cursor_x - self.drag_offset_x
    s.y = self.drag_cursor_y - self.drag_offset_y
end

-- Returns the snap target (col, row) for the item's top-left: rounds the
-- sprite's current pixel position to the nearest cell boundary. The sprite
-- is already positioned by the click offset, so rounding its top-left is
-- equivalent to center-based snapping without the floor-on-boundary problem.
function Grid:_snap_cell()
    local item = self.dragging
    if item and item.sprite then
        local s = item.sprite
        local col = math.floor((s.x - self.origin_x) / self.cell_size + 0.5)
        local row = math.floor((s.y - self.origin_y) / self.cell_size + 0.5)
        return col, row
    end
    return self:world_to_cell(self.drag_cursor_x, self.drag_cursor_y)
end

-- Coordinate conversion ----------------------------------------------------

function Grid:cell_to_world(col, row)
    return self.origin_x + col * self.cell_size,
           self.origin_y + row * self.cell_size
end

function Grid:world_to_cell(x, y)
    return math.floor((x - self.origin_x) / self.cell_size),
           math.floor((y - self.origin_y) / self.cell_size)
end

-- Whether world-space (x,y) falls within this grid's own cell area (not the
-- surrounding panel backdrop, if any - just the grid rectangle itself).
function Grid:_point_in_bounds(x, y)
    return x >= self.origin_x and x < self.origin_x + self.cols * self.cell_size
       and y >= self.origin_y and y < self.origin_y + self.rows * self.cell_size
end

-- Query ---------------------------------------------------------------------

function Grid:items()
    return self._items
end

-- Returns the item occupying (col,row), or nil.
function Grid:item_at(col, row)
    for _, it in ipairs(self._items) do
        for _, off in ipairs(it:footprint()) do
            if it.cell_col + off[1] == col and it.cell_row + off[2] == row then
                return it
            end
        end
    end
    return nil
end

-- Returns true if `item` could be placed with its anchor at (col,row):
-- every footprint cell must be in-bounds and unoccupied by any OTHER item
-- currently tracked on this grid.
function Grid:can_place(item, col, row)
    for _, off in ipairs(item:footprint()) do
        local c, r = col + off[1], row + off[2]
        if c < 0 or c >= self.cols or r < 0 or r >= self.rows then
            return false
        end
        local occupant = self:item_at(c, r)
        if occupant and occupant ~= item then
            return false
        end
    end
    return true
end

-- Mutation --------------------------------------------------------------

-- Removes `item` from this grid's internal list without touching
-- item.grid/cell_col/cell_row. Internal helper used while starting a drag.
function Grid:_unlist(item)
    for i, it in ipairs(self._items) do
        if it == item then
            table.remove(self._items, i)
            return
        end
    end
end

-- Places `item` with its anchor at (col,row): sets item.cell_col/cell_row
-- and item.grid, and records it in this grid's item list (idempotent).
function Grid:place(item, col, row)
    item.cell_col = col
    item.cell_row = row
    item.grid     = self

    for _, it in ipairs(self._items) do
        if it == item then return end
    end
    table.insert(self._items, item)
end

-- Places `item` at the first free cell it fits at (row-major scan: row 0
-- left-to-right, then row 1, ...), if any. Returns true and places it, or
-- returns false (leaving the grid untouched) if nothing fits.
function Grid:place_first_fit(item)
    for row = 0, self.rows - 1 do
        for col = 0, self.cols - 1 do
            if self:can_place(item, col, row) then
                self:place(item, col, row)
                return true
            end
        end
    end
    return false
end

-- Fully removes `item` from this grid (list + item.grid reference).
function Grid:remove(item)
    self:_unlist(item)
    if item.grid == self then
        item.grid = nil
    end
end

-- Drag flow -------------------------------------------------------------

function Grid:mouse_pressed(x, y)
    local col, row = self:world_to_cell(x, y)
    local item = self:item_at(col, row)
    if item then
        self.dragging      = item
        self.drag_orig_col = item.cell_col
        self.drag_orig_row = item.cell_row
        -- Take it out of collision bookkeeping so can_place checks against
        -- OTHER items don't reject its own current cells during preview.
        self:_unlist(item)
        self.drag_cursor_x, self.drag_cursor_y = x, y
        -- Pixel offset: keeps the grabbed point under the cursor visually.
        -- Sync sprite position from its cell before computing offset (mirrors
        -- Item:draw's cell-to-world sync, so tests without draw calls work too).
        if item.sprite and item.cell_col and item.cell_row then
            item.sprite.x, item.sprite.y = self:cell_to_world(item.cell_col, item.cell_row)
        end
        if item.sprite then
            self.drag_offset_x = x - item.sprite.x
            self.drag_offset_y = y - item.sprite.y
        else
            self.drag_offset_x = 0
            self.drag_offset_y = 0
        end
        self:_position_dragging_sprite()
    end
    if self.dragging then
        self.drag_preview_col, self.drag_preview_row = self:_snap_cell()
    end
end

function Grid:mouse_moved(x, y)
    self._hover_col, self._hover_row = self:world_to_cell(x, y)
    if not self.dragging then return end
    self.drag_cursor_x, self.drag_cursor_y = x, y
    self:_position_dragging_sprite()
    self.drag_preview_col, self.drag_preview_row = self:_snap_cell()
end

function Grid:mouse_released(x, y)
    if not self.dragging then return end
    local item = self.dragging

    local col, row = self:_snap_cell()
    self.drag_preview_col, self.drag_preview_row = col, row

    if self:can_place(item, col, row) then
        self:place(item, col, row)
    else
        self:place(item, self.drag_orig_col, self.drag_orig_row)
    end

    self.dragging         = nil
    self.drag_orig_col    = nil
    self.drag_orig_row    = nil
    self.drag_preview_col = nil
    self.drag_preview_row = nil
    self.drag_cursor_x    = nil
    self.drag_cursor_y    = nil
    self.drag_offset_x    = nil
    self.drag_offset_y    = nil
end

-- Shows a drop-preview for `item` at world (x,y) on THIS grid's own
-- coordinate system, even though `item` isn't this grid's self.dragging
-- (it belongs to some other grid that's currently mid-drag). Used by the
-- scene when a cross-grid drag's cursor is hovering over a grid other than
-- the one that owns the drag, so the preview always snaps to whichever
-- grid it would actually land on - not the origin grid's coordinate system.
function Grid:preview_override(item, x, y)
    self._preview_override_item = item
    self._preview_override_col, self._preview_override_row = self:world_to_cell(x, y)
end

function Grid:clear_preview_override()
    self._preview_override_item = nil
    self._preview_override_col  = nil
    self._preview_override_row  = nil
end

function Grid:clear_hover()
    self._hover_col = nil
    self._hover_row = nil
end

-- Rotates the currently-dragged item in place. No validity check - validity
-- is only enforced at drop time. Re-centers the sprite afterward since
-- rotating can change its width/height.
function Grid:rotate_dragged()
    if self.dragging then
        self.dragging:rotate()
        -- After rotation the sprite dimensions change; reset offset to center
        -- so the item pivots around the cursor rather than jumping.
        local s = self.dragging.sprite
        if s then
            self.drag_offset_x = s.width  / 2
            self.drag_offset_y = s.height / 2
        end
        self:_position_dragging_sprite()
    end
end

-- Frame tick --------------------------------------------------------------

-- Ticks every item tracked on this grid, including the item mid-drag (which
-- is not in self._items while dragging, so it's ticked separately here).
function Grid:update(dt)
    for _, item in ipairs(self._items) do
        item:update(dt)
    end
    if self.dragging then
        self.dragging:update(dt)
    end
end

-- Draw ------------------------------------------------------------------

-- Cell span (cols, rows) of an item's current footprint's bounding box, used
-- to size the drag-preview outline to match the actual item rather than a
-- single cell.
local function footprint_extent(item)
    local max_dx, max_dy = 0, 0
    for _, off in ipairs(item:footprint()) do
        if off[1] > max_dx then max_dx = off[1] end
        if off[2] > max_dy then max_dy = off[2] end
    end
    return max_dx + 1, max_dy + 1
end

-- skip_dragging: if true, don't draw self.dragging here even though it's
-- mid-drag - used when the caller wants to draw the actively-dragged item
-- itself, separately, on top of every other draw layer (e.g. above other
-- scene elements like the customer or an open item panel).
function Grid:draw(skip_dragging)
    local config = require("lua/game/config")
    local colors = config.COLORS or {}

    if colors.grid_bg then
        love.graphics.setColor(colors.grid_bg)
        love.graphics.rectangle(
            "fill", self.origin_x, self.origin_y,
            self.cols * self.cell_size, self.rows * self.cell_size
        )
    end

    if colors.grid_cell then
        love.graphics.setColor(colors.grid_cell)
        for c = 0, self.cols - 1 do
            for r = 0, self.rows - 1 do
                local x, y = self:cell_to_world(c, r)
                love.graphics.rectangle(
                    "line", x, y, self.cell_size, self.cell_size
                )
            end
        end
    end

    -- Drop preview: drawn UNDER every item (including the dragged one, drawn
    -- below) and sized to the dragged item's actual footprint, not a fixed
    -- single cell. Prefer this grid's own drag (self.dragging) over an
    -- external override - the two are never both set for the same grid in
    -- practice (a grid is either actively dragging its own item, or
    -- previewing someone else's drag hovering over it, never both).
    local preview_item, preview_col, preview_row
    if self.dragging and self.drag_preview_col then
        preview_item, preview_col, preview_row = self.dragging, self.drag_preview_col, self.drag_preview_row
    elseif self._preview_override_item and self._preview_override_col then
        preview_item, preview_col, preview_row =
            self._preview_override_item, self._preview_override_col, self._preview_override_row
    end

    if preview_item and colors.grid_line and self:can_place(preview_item, preview_col, preview_row) then
        local w_cells, h_cells = footprint_extent(preview_item)
        local x, y = self:cell_to_world(preview_col, preview_row)
        love.graphics.setColor(colors.grid_line)
        love.graphics.rectangle(
            "line", x, y, w_cells * self.cell_size, h_cells * self.cell_size
        )
    end

    love.graphics.setColor(1, 1, 1, 1)

    for _, item in ipairs(self._items) do
        if item.draw then item:draw() end
    end

    if self.dragging and self.dragging.draw and not skip_dragging then
        self.dragging:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draws the name+tag label for the hovered or dragged item on this grid.
-- Must be called AFTER all other draw layers (panels, buttons, HUD) so the
-- label is never occluded by UI drawn on top of Grid:draw().
function Grid:draw_labels()
    local item_to_label
    if self.dragging then
        item_to_label = self.dragging
    elseif self._hover_col and self._hover_row then
        item_to_label = self:item_at(self._hover_col, self._hover_row)
    end
    if not item_to_label then return end
    if not item_to_label.label or item_to_label.label == "" then return end
    if not item_to_label.sprite then return end

    local font = love.graphics.getFont()
    local th = font:getHeight()
    local tag_str = (item_to_label.tags and #item_to_label.tags > 0)
        and table.concat(item_to_label.tags, ", ") or nil
    local nw = font:getWidth(item_to_label.label)
    local tw = tag_str and font:getWidth(tag_str) or 0
    local box_w = math.max(nw, tw) + 6
    local box_h = th * (tag_str and 2 or 1) + 4
    local lx = item_to_label.sprite.x + item_to_label.sprite.width / 2
    local ly = item_to_label.sprite.y - box_h - 3

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", lx - box_w / 2, ly, box_w, box_h)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print(item_to_label.label, lx - nw / 2, ly + 2)
    if tag_str then
        love.graphics.setColor(0.95, 0.85, 0.45, 0.95)
        love.graphics.print(tag_str, lx - tw / 2, ly + th + 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Grid
