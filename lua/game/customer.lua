-- lua/game/customer.lua
--
-- Adapted from ../wip/lua/game/customer.lua for the cooking-inventory game.
-- Keeps the walk-in / wait / talk / walk-out state machine and the
-- typewriter dialogue-bubble reveal logic; drops everything specific to
-- wip's plant art (plant_type, color-replace shader, SpriteSet idle/walk
-- animation swap, 9-slice image bubble, sound). The customer body is a
-- single static placeholder `Sprite` (solid color rectangle, no image) and
-- the speech bubble is drawn as a plain rectangle with printed text.

local Sprite = require("lua/core/sprite")
local config = require("lua/game/config")
local Grid   = require("lua/game/grid")
local Item   = require("lua/game/item")

local U  = config.U
local CW = 2 * U -- customer body width
local CH = 4 * U -- customer body height

local REVEAL_SPEED = 40 -- characters per second
local PAD          = 10
local MIN_BOX_W    = 100
local MAX_BOX_W    = 320
local TAIL_H        = 12
local BUBBLE_GAP    = 8 -- gap between bubble box and customer sprite

local DEFAULT_COLOR = { 0.85, 0.55, 0.30, 1 }
local BUBBLE_BG      = { 1, 1, 1, 0.95 }
local BUBBLE_TEXT    = { 0.08, 0.07, 0.10, 1 }

-- Walking animation (placeholder art: no sprite frames, so the "animation"
-- is a procedural bob + a pair of swinging leg rectangles beneath the body).
local WALK_STEP_SPEED     = 9    -- radians/sec of the step cycle
local WALK_BOB_AMPLITUDE  = 3    -- px of vertical bounce
local WALK_LEG_SWING      = 5    -- px each leg swings fore/aft
local LEG_W, LEG_H        = 7, 16
local LEG_GAP             = 8    -- half-distance between the two legs
local LEG_COLOR           = { 0.12, 0.10, 0.09, 1 }

local Customer = {}
Customer.__index = Customer

-- Places `item` into the first free cell of `panel` (row-major scan, same
-- pattern as item.lua's private place_first_fit). Returns true if placed.
local function place_first_fit(panel, item)
    for row = 0, panel.rows - 1 do
        for col = 0, panel.cols - 1 do
            if panel:can_place(item, col, row) then
                panel:place(item, col, row)
                return true
            end
        end
    end
    return false
end

function Customer.new(target_x, exit_x, y)
    local self = setmetatable({}, Customer)

    self.state    = "idle"
    self.x        = exit_x
    self.y        = y
    self.target_x = target_x
    self.exit_x   = exit_x
    self.speed    = 80

    self.sprite = Sprite.new(0, 0, CW, CH)
    self.sprite.color   = DEFAULT_COLOR
    self.sprite.visible = false

    self.kind            = "order"
    self.panel           = nil
    self.type_id         = nil

    self.name            = "Customer"
    self.requested_tag   = nil
    self.messages        = {}
    self.msg_index       = 1
    self.done_talking    = true
    self.dismissed       = false
    self.after_messages  = {}
    self.after_msg_index = 1
    self.done_after      = true

    self.reveal_index = 0
    self.reveal_t      = 0
    self._full_text    = ""

    self._walk_t = 0

    return self
end

-- Resets and starts the customer walking in with a new order.
-- cfg: { name, messages, after_messages, requested_tag, walk_speed, color }
function Customer:show(cfg)
    cfg = cfg or {}

    self.kind = cfg.kind or "order"

    self.panel    = nil
    self.type_id  = nil
    if self.kind == "merchant" then
        self.type_id = "merchant"
        self.panel   = Grid.new(config.MERCHANT_PANEL_COLS, config.MERCHANT_PANEL_ROWS, config.U, 0, 0)
        for _, type_id in ipairs(cfg.stock or {}) do
            place_first_fit(self.panel, Item.new(type_id))
        end
    elseif self.kind == "order" then
        self.type_id = "order_customer"
        self.panel   = Grid.new(config.ORDER_PANEL_COLS, config.ORDER_PANEL_ROWS, config.U, 0, 0)
    end

    self.name            = cfg.name or "Customer"
    self.requested_tag   = cfg.requested_tag
    self.messages        = cfg.messages or {}
    self.msg_index       = 1
    self.done_talking    = #self.messages == 0
    self.dismissed       = false
    self.after_messages  = cfg.after_messages or {}
    self.after_msg_index = 1
    self.done_after      = #self.after_messages == 0

    self._full_text   = self.messages[self.msg_index] or ""
    self.reveal_index = 0
    self.reveal_t      = 0

    self.speed = cfg.walk_speed or 80
    if cfg.color then self.sprite.color = cfg.color end

    self.x = self.exit_x
    self.state          = "walking_in"
    self.sprite.visible = true
    self._walk_t         = 0
end

-- Whether the speech bubble should currently be shown: once actually
-- waiting (not while still walking in) with an unfinished pre-serve
-- message, or while showing an after-message (always waiting/settled by
-- the time that happens, since it's set in serve()).
function Customer:bubble_visible()
    if self.state == "talking_after" then return true end
    return self.state == "waiting" and not self.done_talking
end

-- Advances to the next pre-serve message (or marks pre-serve talk done).
function Customer:advance()
    if self.done_talking then return end
    if not self:line_complete() then
        self:skip_reveal()
        return
    end
    if self.msg_index < #self.messages then
        self.msg_index = self.msg_index + 1
    else
        self.done_talking = true
    end
    if not self.done_talking then
        self._full_text   = self.messages[self.msg_index] or ""
        self.reveal_index = 0
        self.reveal_t      = 0
    end
end

function Customer:line_complete()
    if self.state == "talking_after" then
        return self.reveal_index >= #self._full_text
    end
    return self.done_talking or self.reveal_index >= #self._full_text
end

function Customer:skip_reveal()
    self.reveal_index = #self._full_text
    self.reveal_t      = #self._full_text / REVEAL_SPEED
end

-- Happy path: item matched the request. Shows after_messages if any,
-- otherwise walks straight out.
function Customer:serve()
    if not self.done_after then
        self.state           = "talking_after"
        self.after_msg_index = 1
        self._full_text      = self.after_messages[1]
        self.reveal_index    = 0
        self.reveal_t         = 0
    else
        self.state = "walking_out"
    end
end

-- Advances to the next after-message (or finishes talking and walks out).
function Customer:advance_after()
    if self.done_after then return end
    if not self:line_complete() then
        self:skip_reveal()
        return
    end
    if self.after_msg_index < #self.after_messages then
        self.after_msg_index = self.after_msg_index + 1
        self._full_text      = self.after_messages[self.after_msg_index]
        self.reveal_index    = 0
        self.reveal_t         = 0
    else
        self.done_after = true
        self.state       = "walking_out"
    end
end

-- Failure path: wrong item (or explicit send-away). With no message, skips
-- straight to walking_out as before (used for e.g. a merchant's Leave
-- button, where "rejection" doesn't apply). With a message, shows it first
-- using the same talking_after/typewriter mechanism serve() uses for its
-- after_messages, so a wrong-item drop reads as a clear rejection instead
-- of silently walking off indistinguishably from a successful serve.
function Customer:dismiss(message)
    if message then
        self.after_messages  = { message }
        self.after_msg_index = 1
        self.done_after       = false
        self.state            = "talking_after"
        self._full_text       = message
        self.reveal_index     = 0
        self.reveal_t          = 0
    else
        self.done_after = true
        self.state       = "walking_out"
    end
    self.done_talking = true
    self.dismissed     = true
end

function Customer:arrived()
    return self.state == "waiting"
end

function Customer:active()
    return self.state ~= "idle"
end

function Customer:update(dt)
    if self.state == "walking_in" then
        self.x = self.x + self.speed * dt
        if self.x >= self.target_x then
            self.x     = self.target_x
            self.state = "waiting"
        end
    elseif self.state == "walking_out" then
        self.x = self.x - self.speed * dt
        if self.x <= self.exit_x then
            self.x               = self.exit_x
            self.state           = "idle"
            self.sprite.visible = false
        end
    end

    if self:bubble_visible() then
        local prev_index  = self.reveal_index
        self.reveal_t      = self.reveal_t + dt
        self.reveal_index = math.min(
            #self._full_text,
            math.floor(self.reveal_t * REVEAL_SPEED)
        )
        if prev_index ~= self.reveal_index then
            -- (character revealed; no sound in this repo)
        end
    end

    local moving = self.state == "walking_in" or self.state == "walking_out"
    if moving then
        self._walk_t = self._walk_t + dt
    else
        self._walk_t = 0
    end

    local bob = moving and math.abs(math.sin(self._walk_t * WALK_STEP_SPEED)) * WALK_BOB_AMPLITUDE or 0

    self.sprite.scale_x = (self.state == "walking_out") and -1 or 1
    self.sprite.x = self.x - CW / 2
    self.sprite.y = self.y - CH / 2 - bob
end

-- Foot offset (fore/aft swing) for each leg while walking; 0 when standing
-- still. The two legs are always in opposite phase.
function Customer:_leg_swing()
    if self.state ~= "walking_in" and self.state ~= "walking_out" then
        return 0
    end
    return math.sin(self._walk_t * WALK_STEP_SPEED) * WALK_LEG_SWING
end

function Customer:draw()
    if self.state == "idle" then return end

    local swing = self:_leg_swing()
    if swing ~= 0 then
        local leg_y = self.sprite.y + self.sprite.height - LEG_H * 0.5
        love.graphics.setColor(LEG_COLOR)
        love.graphics.rectangle("fill", self.x - LEG_GAP - LEG_W / 2 + swing, leg_y, LEG_W, LEG_H)
        love.graphics.rectangle("fill", self.x + LEG_GAP - LEG_W / 2 - swing, leg_y, LEG_W, LEG_H)
        love.graphics.setColor(1, 1, 1, 1)
    end

    self.sprite:draw()
end

-- Draws the speech bubble as a plain rectangle with the currently revealed
-- text on top, wrapped to MAX_BOX_W. Call separately from draw() so the
-- scene can control draw order (e.g. all bodies, then all bubbles).
function Customer:draw_bubble()
    if not self:bubble_visible() then return end

    local font = love.graphics.getFont()

    -- reveal_index counts bytes; clamp to a UTF-8 character boundary so
    -- string.sub never returns a string that ends mid-multibyte-sequence.
    local idx = self.reveal_index
    while idx > 0 and (string.byte(self._full_text, idx) or 0) >= 0x80
                  and (string.byte(self._full_text, idx) or 0) <  0xC0 do
        idx = idx - 1
    end
    if (string.byte(self._full_text, idx) or 0) >= 0xC0 then
        idx = idx - 1
    end

    local text_h   = font:getHeight()
    local _, lines = font:getWrap(self._full_text, MAX_BOX_W - PAD * 2)
    local widest_line_width = 0
    for _, line in ipairs(lines) do
        local lw = font:getWidth(line)
        if lw > widest_line_width then widest_line_width = lw end
    end

    local box_w = math.min(MAX_BOX_W, math.max(MIN_BOX_W, widest_line_width + PAD * 2))
    local box_h = text_h * #lines + PAD * 2
    local box_x = self.x - box_w / 2
    local box_y = self.sprite.y - box_h - TAIL_H - BUBBLE_GAP

    -- Build rendered_lines by walking the wrap points with a byte offset,
    -- so partial words never cause line-break flicker.
    local rendered_lines = {}
    local remaining = idx
    for _, line in ipairs(lines) do
        if remaining <= 0 then break end
        local trimmed = line:match("^(.-)%s*$") or line
        local visible = math.min(remaining, #trimmed)
        rendered_lines[#rendered_lines + 1] = string.sub(trimmed, 1, visible)
        remaining = remaining - #line
    end

    love.graphics.setColor(BUBBLE_BG)
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 6, 6)

    -- Small triangular tail pointing down toward the customer.
    local tail_cx = self.x
    love.graphics.polygon(
        "fill",
        tail_cx - TAIL_H / 2, box_y + box_h,
        tail_cx + TAIL_H / 2, box_y + box_h,
        tail_cx,               box_y + box_h + TAIL_H
    )

    love.graphics.setColor(BUBBLE_TEXT)
    for i, line in ipairs(rendered_lines) do
        love.graphics.print(line, box_x + PAD, box_y + PAD + (i - 1) * text_h)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Customer
