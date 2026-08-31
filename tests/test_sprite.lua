local Sprite = require("lua/core/sprite")

do
    local s = Sprite.new(0, 0, 32, 32)
    assert(s.no_bg == false, "no_bg should default to false")
    print("PASS: sprite: no_bg defaults to false")
end

do
    local s = Sprite.new(10, 20, 64, 48)
    s.no_bg = true
    assert(s.no_bg == true, "no_bg should be settable to true")
    print("PASS: sprite: no_bg can be set to true")
end

do
    local a = Sprite.new(0, 0, 32, 32)
    local b = Sprite.new(0, 0, 32, 32)
    b.no_bg = true
    assert(a.no_bg == false, "no_bg on one instance should not affect another")
    print("PASS: sprite: no_bg is per-instance")
end

print("ALL TESTS PASSED")
