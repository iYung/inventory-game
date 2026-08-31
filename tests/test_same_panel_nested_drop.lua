-- tests/test_same_panel_nested_drop.lua
-- Regression test: dragging an item onto a nested container when both live
-- in the same parent panel must insert into the nested panel, not snap back.
-- Covers the bug fixed in game/scenes/kitchen_scene.lua where `hover ~= owner`
-- in mouse_released blocked the nested-container path for same-panel drops.

local runner     = require("lua/headless/runner")
local KitchenScene = require("game/scenes/kitchen_scene")
local Item       = require("lua/game/item")
local ItemPanel  = require("lua/game/item_panel")

do
    local ctx = runner.setup(function() return KitchenScene.new() end)
    local scene = ctx.sm.current

    -- Locate the pre-placed floor container (2x2, 6x6 panel).
    local outer
    for _, it in ipairs(scene.grid:items()) do
        if it.type_id == "container" then outer = it; break end
    end
    assert(outer, "on_enter should have placed a container on the floor grid")

    -- Place a nested container (inner) inside the outer panel at (0,0).
    -- The inner container is 2x2, so it occupies (0,0)-(1,1).
    local inner = Item.new("container")
    assert(outer.panel:can_place(inner, 0, 0), "inner container should fit at (0,0) in outer panel")
    outer.panel:place(inner, 0, 0)

    -- Place a raw_chicken inside the outer panel at (3,0), clear of the inner container.
    local chicken = Item.new("raw_chicken")
    assert(outer.panel:can_place(chicken, 3, 0), "raw_chicken should fit at (3,0) in outer panel")
    outer.panel:place(chicken, 3, 0)

    -- Open the outer container's panel.
    scene:_open_panel(ItemPanel.new(outer))

    -- Drag the raw_chicken from its cell in the outer panel.
    local cx, cy = outer.panel:cell_to_world(chicken.cell_col, chicken.cell_row)
    cx, cy = cx + 1, cy + 1
    scene:mouse_pressed(cx, cy)
    assert(outer.panel.dragging == chicken, "should be dragging raw_chicken out of the outer panel")

    -- Drop it directly onto the inner container's cell (also in the outer panel).
    local ix, iy = outer.panel:cell_to_world(inner.cell_col, inner.cell_row)
    ix, iy = ix + 1, iy + 1
    scene:mouse_moved(ix, iy)
    scene:mouse_released(ix, iy)

    assert(outer.panel.dragging == nil, "drag state should be cleared after drop")

    -- The chicken must have entered the inner container's panel.
    assert(chicken.grid == inner.panel,
        "raw_chicken should now belong to the inner container's panel (not snap back)")

    local in_outer = false
    for _, it in ipairs(outer.panel:items()) do
        if it == chicken then in_outer = true end
    end
    assert(not in_outer, "raw_chicken should no longer be a direct child of the outer panel")

    local in_inner = false
    for _, it in ipairs(inner.panel:items()) do
        if it == chicken then in_inner = true end
    end
    assert(in_inner, "raw_chicken should be listed inside the nested container's panel")

    print("PASS: same-panel nested drop: item dropped onto nested container in same parent panel enters that container")
end

print("ALL TESTS PASSED")
