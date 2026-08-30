local _visual_test = nil
local _visual_mode = false
do
    local headless, visual, test_file = false, false, nil
    for _, v in ipairs(arg or {}) do
        if     v == "--headless" then headless = true
        elseif v == "--visual"   then visual   = true
        elseif (headless or visual) and not test_file and v:sub(1, 1) ~= "-" then
            test_file = v
        end
    end
    if headless then
        require("lua/headless/stubs")
        require("lua/headless/runner").run(test_file)
        return
    end
    if visual then
        _visual_test = test_file
        _visual_mode = true
    end
end

love.graphics.setDefaultFilter("nearest", "nearest")

local SceneManager = require("lua/core/scene_manager")
local KitchenScene = require("game/scenes/kitchen_scene")

local LOGICAL_W, LOGICAL_H = 1280, 720
local canvas

local manager

function love.load()
    math.randomseed(os.time())

    love.window.setIcon(love.image.newImageData("assets/images/icon.png"))

    canvas = love.graphics.newCanvas(LOGICAL_W, LOGICAL_H)
    canvas:setFilter("nearest", "nearest")

    manager = SceneManager.new(LOGICAL_W, LOGICAL_H)
    manager:switch(KitchenScene.new())
end

function love.update(dt)
    manager:update(dt)
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0)
    manager:draw()
    love.graphics.setCanvas()

    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

-- Converts a window-space coordinate (as reported by love.mouse* callbacks)
-- into the 1280x720 logical canvas space, inverting the scale/letterbox
-- transform used above in love.draw().
local function to_logical(x, y)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    return (x - ox) / scale, (y - oy) / scale
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    if manager.current and manager.current.mouse_pressed then
        local lx, ly = to_logical(x, y)
        manager.current:mouse_pressed(lx, ly)
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    if manager.current and manager.current.mouse_released then
        local lx, ly = to_logical(x, y)
        manager.current:mouse_released(lx, ly)
    end
end

function love.mousemoved(x, y)
    if manager.current and manager.current.mouse_moved then
        local lx, ly = to_logical(x, y)
        manager.current:mouse_moved(lx, ly)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        if manager.current and manager.current.rotate_dragged then
            manager.current:rotate_dragged()
        end
    end
end
