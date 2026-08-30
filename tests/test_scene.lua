local Scene        = require("lua/core/scene")
local KitchenScene = require("game/scenes/kitchen_scene")

-- Test 1: Scene.new(w, h) passes dimensions to its camera
do
    local s = Scene.new(800, 600)
    assert(s.camera ~= nil,    "Scene.new should create a camera")
    assert(s.camera._w == 800, "camera._w should be 800, got " .. tostring(s.camera._w))
    assert(s.camera._h == 600, "camera._h should be 600, got " .. tostring(s.camera._h))
    print("PASS: scene: Scene.new(w, h) threads dimensions to camera")
end

-- Test 2: Scene.new creates a drawer
do
    local s = Scene.new(1280, 720)
    assert(s.drawer ~= nil, "Scene.new should create a drawer")
    print("PASS: scene: Scene.new creates a drawer")
end

-- Test 3: KitchenScene inherits drawer and camera from Scene
do
    local ks = KitchenScene.new()
    assert(ks.drawer ~= nil,        "KitchenScene should have a drawer from Scene")
    assert(ks.camera ~= nil,        "KitchenScene should have a camera from Scene")
    assert(ks.camera._w == 1280,    "KitchenScene camera._w should be 1280")
    assert(ks.camera._h == 720,     "KitchenScene camera._h should be 720")
    print("PASS: scene: KitchenScene inherits drawer and camera from Scene")
end

print("ALL TESTS PASSED")
