-- test_basics.lua
-- Minimal example demonstrating the headless test infrastructure.
--
-- There's no player/WASD movement in this game (static scene, mouse-only
-- interaction), so this just exercises the basic tick loop against a fresh
-- KitchenScene.

local runner = require("lua/headless/runner")

-- Test 1: a fresh KitchenScene can be ticked without error.
-- scene_factory receives (input, sm) from runner.setup but KitchenScene.new()
-- takes no arguments; simply ignore the args and return a new scene.
local ctx = runner.setup(function(input, sm)
    return require("game/scenes/kitchen_scene").new()
end)

runner.tick(ctx.input, ctx.sm, 10)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after tick")
print("PASS: scene ticks without error")

print("ALL TESTS PASSED")
