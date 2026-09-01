-- lua/game/book_panel.lua
-- Panel for book items: shows a title bar (draggable), close button, and a
-- centered content image. Interface-compatible with ItemPanel so KitchenScene
-- can store BookPanel and ItemPanel instances in the same self.panels list.

local config    = require("lua/game/config")
local item_defs = require("lua/game/data/item_defs")

local BookPanel = {}
BookPanel.__index = BookPanel

local MARGIN     = 16
local TITLE_H    = 28
local CLOSE_SIZE = 22
local CLOSE_GAP  = 6
local IMG_W      = 160
local IMG_H      = 120

local COLOR_TITLE = { 0.20, 0.20, 0.26, 1 }
local COLOR_CLOSE = { 0.75, 0.25, 0.25, 1 }

local function point_in_rect(x, y, r)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function BookPanel.new(item)
    local def = item_defs[item.type_id]
    assert(def and def.has_book_panel,
        "BookPanel.new: item '" .. tostring(item.type_id) .. "' has no has_book_panel")

    local self = setmetatable({}, BookPanel)
    self.item            = item
    self.def             = def
    self.should_close    = false
    self.should_leave    = false
    self.should_serve    = false
    self.should_skip     = false
    self._dragging_panel = false

    -- Try to load the content image; fall back to a solid-color placeholder.
    local img_path = "assets/images/books/" .. def.book_image .. ".png"
    local ok, img = pcall(love.graphics.newImage, img_path)
    self._image       = ok and img or nil
    self._fallback_color = def.color or { 0.5, 0.5, 0.5, 1 }

    self.bg_w = IMG_W + MARGIN * 2
    self.bg_h = TITLE_H + MARGIN + IMG_H + MARGIN

    local default_x = (config.SCREEN_W - self.bg_w) / 2
    local default_y = math.max(8, config.SPLIT_Y - self.bg_h - 12)
    self:_layout(default_x, default_y)

    return self
end

function BookPanel:_layout(bg_x, bg_y)
    self.bg = { x = bg_x, y = bg_y, w = self.bg_w, h = self.bg_h }

    self.title_bar = { x = bg_x, y = bg_y, w = self.bg_w, h = TITLE_H }

    self.close_button = {
        x = bg_x + self.bg_w - CLOSE_SIZE - CLOSE_GAP,
        y = bg_y + (TITLE_H - CLOSE_SIZE) / 2,
        w = CLOSE_SIZE,
        h = CLOSE_SIZE,
    }

    self._img_x = bg_x + MARGIN
    self._img_y = bg_y + TITLE_H + MARGIN
end

function BookPanel:_point_in_bg(x, y)
    return point_in_rect(x, y, self.bg)
end

function BookPanel:_point_in_grid(x, y)
    return false
end

function BookPanel:mouse_pressed(x, y)
    if point_in_rect(x, y, self.close_button) then
        self.should_close = true
        return true
    end

    if point_in_rect(x, y, self.title_bar) then
        self._dragging_panel = true
        self._drag_offset_x  = x - self.bg.x
        self._drag_offset_y  = y - self.bg.y
        return true
    end

    return false
end

function BookPanel:mouse_moved(x, y)
    if self._dragging_panel then
        self:_layout(x - self._drag_offset_x, y - self._drag_offset_y)
    end
end

function BookPanel:mouse_released(x, y)
    self._dragging_panel = false
end

function BookPanel:draw(skip_dragging)
    local colors = config.COLORS or {}

    love.graphics.setColor(colors.panel_bg or { 0.1, 0.1, 0.13, 0.95 })
    love.graphics.rectangle("fill", self.bg.x, self.bg.y, self.bg.w, self.bg.h)
    love.graphics.setColor(colors.panel_border or { 0.45, 0.45, 0.55, 1 })
    love.graphics.rectangle("line", self.bg.x, self.bg.y, self.bg.w, self.bg.h)

    local tb = self.title_bar
    love.graphics.setColor(COLOR_TITLE)
    love.graphics.rectangle("fill", tb.x, tb.y, tb.w, tb.h)
    love.graphics.setColor(colors.panel_border or { 0.45, 0.45, 0.55, 1 })
    love.graphics.rectangle("line", tb.x, tb.y, tb.w, tb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print(self.def.name or self.item.type_id, tb.x + 8, tb.y + 6)

    if self._image then
        local iw = self._image:getWidth()
        local ih = self._image:getHeight()
        local sx = IMG_W / iw
        local sy = IMG_H / ih
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self._image, self._img_x, self._img_y, 0, sx, sy)
    else
        love.graphics.setColor(self._fallback_color)
        love.graphics.rectangle("fill", self._img_x, self._img_y, IMG_W, IMG_H)
    end

    local cb = self.close_button
    love.graphics.setColor(COLOR_CLOSE)
    love.graphics.rectangle("fill", cb.x, cb.y, cb.w, cb.h)
    love.graphics.setColor(colors.button_text or { 1, 1, 1, 1 })
    love.graphics.print("X", cb.x + cb.w / 2 - 4, cb.y + cb.h / 2 - 8)

    love.graphics.setColor(1, 1, 1, 1)
end

return BookPanel
