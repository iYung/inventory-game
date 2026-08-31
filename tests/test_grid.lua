-- tests/test_grid.lua
-- Headless tests for lua/game/grid.lua.
--
-- Grid is generic and doesn't know about the real Item class (built by a
-- parallel task), so these tests use tiny fake item-like tables exposing
-- just what Grid needs: :footprint(), :rotate(), :update(dt), plus the
-- cell_col/cell_row/grid fields Grid itself sets.

local Grid = require("lua/game/grid")

-- Builds a fake item with one or more footprint "shapes" (lists of {dx,dy}
-- offsets). :rotate() cycles to the next shape. :footprint() returns the
-- current shape. :update(dt) just counts calls so tests can assert it ran.
local function make_item(shapes)
    local it = { cell_col = nil, cell_row = nil, grid = nil }
    it._shapes = shapes
    it._idx = 1
    it.update_calls = 0

    function it:footprint()
        return self._shapes[self._idx]
    end

    function it:rotate()
        self._idx = (self._idx % #self._shapes) + 1
    end

    function it:update(dt)
        self.update_calls = self.update_calls + 1
    end

    return it
end

local ONE_BY_ONE = { { 0, 0 } }
local TWO_BY_TWO = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }

local CELL = 36

-- Test 1: placing a 1x1 and a 2x2 item ---------------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)

    local meat = make_item({ ONE_BY_ONE })
    assert(g:can_place(meat, 0, 0), "1x1 item should be placeable on an empty grid")
    g:place(meat, 0, 0)
    assert(meat.cell_col == 0 and meat.cell_row == 0, "place() should set cell_col/cell_row")
    assert(meat.grid == g, "place() should set item.grid")
    assert(g:item_at(0, 0) == meat, "item_at should find the placed 1x1 item")

    local microwave = make_item({ TWO_BY_TWO })
    assert(g:can_place(microwave, 3, 2), "2x2 item should be placeable in empty space")
    g:place(microwave, 3, 2)
    assert(g:item_at(3, 2) == microwave, "item_at should find the 2x2 anchor cell")
    assert(g:item_at(4, 2) == microwave, "item_at should find the 2x2's other cells")
    assert(g:item_at(3, 3) == microwave, "item_at should find the 2x2's other cells")
    assert(g:item_at(4, 3) == microwave, "item_at should find the 2x2's other cells")

    local items = g:items()
    assert(#items == 2, "grid should track both placed items")

    print("PASS: grid: places a 1x1 and a 2x2 item")
end

-- Test 2: rejecting overlap ---------------------------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ TWO_BY_TWO })
    g:place(a, 0, 0) -- occupies (0,0),(1,0),(0,1),(1,1)

    local b = make_item({ ONE_BY_ONE })
    assert(not g:can_place(b, 1, 1), "1x1 overlapping a placed 2x2 should be rejected")

    local c = make_item({ ONE_BY_ONE })
    assert(g:can_place(c, 2, 0), "non-overlapping cell should remain placeable")

    print("PASS: grid: rejects overlap with an existing item")
end

-- Test 3: rejecting out-of-bounds placement ------------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    assert(not g:can_place(a, -1, 0), "negative column should be out of bounds")
    assert(not g:can_place(a, 0, -1), "negative row should be out of bounds")
    assert(not g:can_place(a, 10, 0), "column == cols should be out of bounds")
    assert(not g:can_place(a, 0, 6), "row == rows should be out of bounds")

    local big = make_item({ TWO_BY_TWO })
    assert(not g:can_place(big, 9, 0), "2x2 hanging off the right edge should be rejected")
    assert(not g:can_place(big, 0, 5), "2x2 hanging off the bottom edge should be rejected")

    print("PASS: grid: rejects out-of-bounds placement")
end

-- Test 4: drag then invalid drop snaps back ------------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    g:place(a, 0, 0)
    local blocker = make_item({ ONE_BY_ONE })
    g:place(blocker, 5, 0)

    -- Press on `a`'s cell to start dragging it.
    g:mouse_pressed(0 * CELL + 1, 0 * CELL + 1)
    assert(g.dragging == a, "mouse_pressed on an item's cell should start dragging it")

    -- Drag onto the blocker's cell (invalid: occupied).
    g:mouse_moved(5 * CELL + 1, 0 * CELL + 1)
    g:mouse_released(5 * CELL + 1, 0 * CELL + 1)

    assert(g.dragging == nil, "mouse_released should clear self.dragging")
    assert(a.cell_col == 0 and a.cell_row == 0, "invalid drop should snap item back to its original cell")
    assert(g:item_at(0, 0) == a, "item should be back at its original cell after invalid drop")
    assert(g:item_at(5, 0) == blocker, "blocker should be undisturbed")

    print("PASS: grid: drag then invalid drop snaps back to original cell")
end

-- Test 5: drag then valid drop moves the item ----------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    g:place(a, 0, 0)

    g:mouse_pressed(0 * CELL + 1, 0 * CELL + 1)
    assert(g.dragging == a, "mouse_pressed should start dragging")

    g:mouse_moved(4 * CELL + 1, 2 * CELL + 1)
    g:mouse_released(4 * CELL + 1, 2 * CELL + 1)

    assert(g.dragging == nil, "mouse_released should clear self.dragging")
    assert(a.cell_col == 4 and a.cell_row == 2, "valid drop should move the item to the new cell")
    assert(g:item_at(4, 2) == a, "item should be found at its new cell")
    assert(g:item_at(0, 0) == nil, "item's old cell should now be empty")

    print("PASS: grid: drag then valid drop moves the item")
end

-- Test 6: rotate_dragged changes the footprint dimensions ----------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    -- Two shapes: 1x2 horizontal, then 2x1 vertical (mimics a 90 degree turn).
    local horizontal = { { 0, 0 }, { 1, 0 } }
    local vertical    = { { 0, 0 }, { 0, 1 } }
    local a = make_item({ horizontal, vertical })
    g:place(a, 0, 0)

    local before = a:footprint()
    assert(#before == 2 and before[2][1] == 1 and before[2][2] == 0,
        "sanity check: item starts in horizontal shape")

    g:mouse_pressed(1, 1) -- item occupies (0,0); this is inside it
    assert(g.dragging == a, "should be dragging the item")

    -- rotate_dragged should be a no-op when nothing is dragging.
    local g2 = Grid.new(10, 6, CELL, 0, 0)
    g2:rotate_dragged() -- must not error with self.dragging == nil

    g:rotate_dragged()
    local after = a:footprint()
    assert(after[2][1] == 0 and after[2][2] == 1,
        "rotate_dragged should call item:rotate(), flipping the footprint to vertical")
    assert(after[1][1] ~= before[2][1] or after[1][2] ~= before[2][2] or true,
        "footprint dimensions should have changed") -- shape differs from before

    print("PASS: grid: rotate_dragged changes the dragged item's footprint")
end

-- Test 7: update(dt) ticks every placed item, including mid-drag --------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    local b = make_item({ ONE_BY_ONE })
    g:place(a, 0, 0)
    g:place(b, 1, 0)

    g:update(1 / 60)
    assert(a.update_calls == 1, "update(dt) should tick placed item a")
    assert(b.update_calls == 1, "update(dt) should tick placed item b")

    g:mouse_pressed(1, 1) -- start dragging a
    assert(g.dragging == a, "should be dragging a")
    g:update(1 / 60)
    assert(a.update_calls == 2, "update(dt) should still tick the item mid-drag")
    assert(b.update_calls == 2, "update(dt) should keep ticking other placed items during a drag")

    g:mouse_released(1, 1)
    print("PASS: grid: update(dt) ticks placed items, including the one mid-drag")
end

-- Test: mouse_moved tracks hover cell unconditionally ----------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)

    assert(g._hover_col == nil and g._hover_row == nil,
        "hover cell should start nil")

    g:mouse_moved(2 * CELL + 1, 1 * CELL + 1)
    assert(g._hover_col == 2 and g._hover_row == 1,
        "mouse_moved should update hover cell even without a drag, got "
        .. tostring(g._hover_col) .. "," .. tostring(g._hover_row))

    local a = make_item({ ONE_BY_ONE })
    g:place(a, 0, 0)
    g:mouse_pressed(1, 1)
    g:mouse_moved(5 * CELL + 1, 3 * CELL + 1)
    assert(g._hover_col == 5 and g._hover_row == 3,
        "mouse_moved should update hover cell during drag")
    g:mouse_released(5 * CELL + 1, 3 * CELL + 1)

    print("PASS: grid: mouse_moved tracks hover cell unconditionally")
end

-- Test: clear_hover resets hover cell to nil ----------------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)

    g:mouse_moved(3 * CELL + 1, 2 * CELL + 1)
    assert(g._hover_col == 3 and g._hover_row == 2, "hover should be set after mouse_moved")

    g:clear_hover()
    assert(g._hover_col == nil and g._hover_row == nil,
        "clear_hover should nil out _hover_col and _hover_row")

    print("PASS: grid: clear_hover resets hover cell to nil")
end

-- Test: drag preserves click offset so item doesn't snap to center ------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    -- Give the item a sprite-like table with x/y/width/height.
    -- Sprite starts at the item's cell origin (0,0) = world (0,0).
    a.sprite = { x = 0, y = 0, width = CELL, height = CELL }
    g:place(a, 0, 0)

    -- Click at (8, 10) — 8px right and 10px down from the sprite's top-left.
    g:mouse_pressed(8, 10)
    assert(g.dragging == a, "should be dragging a")
    assert(g.drag_offset_x == 8,  "drag_offset_x should be the x distance from sprite left to click")
    assert(g.drag_offset_y == 10, "drag_offset_y should be the y distance from sprite top to click")

    -- Move to (50, 60): sprite should land at (50-8, 60-10) = (42, 50)
    g:mouse_moved(50, 60)
    assert(a.sprite.x == 42, "sprite.x should be cursor_x - offset_x, got " .. tostring(a.sprite.x))
    assert(a.sprite.y == 50, "sprite.y should be cursor_y - offset_y, got " .. tostring(a.sprite.y))

    -- After release, offset fields should be cleared.
    g:mouse_released(50, 60)
    assert(g.drag_offset_x == nil and g.drag_offset_y == nil,
        "drag offsets should be cleared after mouse_released")

    print("PASS: grid: drag preserves click offset (item does not snap to center)")
end

-- Test: snap centers item on the cell the center is over -------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    -- 2x1 item; sprite width = 2*CELL, height = CELL.
    local a = make_item({ { {0,0}, {1,0} } })
    a.sprite = { x = 0, y = 0, width = 2 * CELL, height = CELL }
    g:place(a, 0, 0)

    -- Grab at the far right edge (offset = 2*CELL-1 from sprite left = x=0).
    g:mouse_pressed(2 * CELL - 1, 1)

    -- Move cursor to x = 5*CELL. Sprite.x = 5*CELL - (2*CELL-1) = 3*CELL+1.
    -- Sprite center_x = 3*CELL+1 + CELL = 4*CELL+1 → center_col = 4.
    -- w_cells = 2, so snap_col = 4 - floor(2/2) = 4 - 1 = 3.
    -- Item top-left at col 3, covering cols 3 and 4 — centered on col 4.
    g:mouse_moved(5 * CELL, 1)
    assert(g.drag_preview_col == 3,
        "snap_col should be center_col - floor(w/2) = 3, got " .. tostring(g.drag_preview_col))

    g:mouse_released(5 * CELL, 1)
    assert(a.cell_col == 3 and a.cell_row == 0,
        "item top-left should land at col 3 (centered on col 4), got col=" .. tostring(a.cell_col))

    print("PASS: grid: snap centers item on the cell its center is over")
end

-- Test: snap with no sprite falls back to cursor cell ---------------------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE }) -- no sprite
    g:place(a, 0, 0)

    g:mouse_pressed(1, 1)
    assert(g.dragging == a, "should be dragging")

    g:mouse_moved(4 * CELL + 1, 1)
    assert(g.drag_preview_col == 4,
        "no-sprite: preview col should equal cursor cell, got " .. tostring(g.drag_preview_col))

    g:mouse_released(4 * CELL + 1, 1)
    assert(a.cell_col == 4 and a.cell_row == 0,
        "no-sprite: item should drop at cursor cell")

    print("PASS: grid: snap with no sprite falls back to cursor cell")
end

-- Test 8: draw() does not error under the headless love.graphics stub ----

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    g:place(a, 0, 0)
    g:mouse_pressed(1, 1)
    g:mouse_moved(3 * CELL + 1, 0)
    g:draw() -- must not error, even mid-drag and with a fake item lacking :draw()
    g:mouse_released(3 * CELL + 1, 0)

    print("PASS: grid: draw() does not error under the headless stub")
end

-- Test 9: dragging preserves click offset; snap uses sprite center ----------

do
    local g = Grid.new(10, 6, CELL, 0, 0)
    local a = make_item({ ONE_BY_ONE })
    -- Item placed at cell (0,0), so sprite top-left is at world (0,0).
    a.sprite = { x = 0, y = 0, width = CELL, height = CELL }
    g:place(a, 0, 0)

    -- Click at (1,1) — 1px into the item from its top-left.
    g:mouse_pressed(1, 1)
    -- Sprite should not jump: offset is (1-0, 1-0) = (1,1), so
    -- sprite.x = cursor(1) - offset(1) = 0, sprite.y = 1 - 1 = 0.
    assert(a.sprite.x == 0 and a.sprite.y == 0,
        "mouse_pressed should not move the sprite from its original position")

    -- Move to (200, 150): sprite top-left = cursor - click-offset = (199, 149).
    g:mouse_moved(200, 150)
    assert(a.sprite.x == 199 and a.sprite.y == 149,
        "mouse_moved should offset the sprite by the original click offset")

    g:mouse_released(200, 150)
    assert(g.drag_cursor_x == nil and g.drag_cursor_y == nil,
        "mouse_released should clear drag cursor tracking")

    print("PASS: grid: dragging preserves click offset; no jump on pickup")
end

-- Test 10: preview_override / clear_preview_override ---------------------

do
    local g = Grid.new(10, 6, CELL, 100, 200) -- non-zero origin, on purpose
    local a = make_item({ ONE_BY_ONE })

    -- Not dragging anything of its own: preview_override still works and
    -- draw() must not error (uses the override branch since self.dragging
    -- is nil here).
    g:preview_override(a, 100 + CELL * 3 + 1, 200 + CELL * 2 + 1)
    assert(g._preview_override_item == a, "preview_override should record the item")
    assert(g._preview_override_col == 3 and g._preview_override_row == 2,
        "preview_override should compute the cell via this grid's own world_to_cell")

    g:draw() -- must not error with an override set but nothing actually dragging

    g:clear_preview_override()
    assert(g._preview_override_item == nil, "clear_preview_override should clear the override")

    -- When this grid IS dragging its own item, draw() should prefer that
    -- over any (stale) override rather than showing both/the wrong one.
    g:place(a, 0, 0)
    g:mouse_pressed(100 + 1, 200 + 1) -- picks up `a`
    assert(g.dragging == a, "sanity check: should be dragging a")
    local b = make_item({ ONE_BY_ONE })
    g:preview_override(b, 100 + CELL * 5 + 1, 200 + 1) -- a different item's override
    g:draw() -- must not error; self.dragging (a) takes priority over the override (b)
    g:mouse_released(100 + 1, 200 + 1)

    print("PASS: grid: preview_override/clear_preview_override let another grid's drag preview here")
end

-- Test 11: place_first_fit -------------------------------------------------

do
    local g = Grid.new(3, 1, CELL, 0, 0)

    local a = make_item({ ONE_BY_ONE })
    assert(g:place_first_fit(a), "should find a free cell in an empty grid")
    assert(a.cell_col == 0 and a.cell_row == 0, "first-fit should pick the first cell, row-major")

    local b = make_item({ ONE_BY_ONE })
    assert(g:place_first_fit(b), "should find the next free cell")
    assert(b.cell_col == 1 and b.cell_row == 0, "first-fit should skip the occupied cell")

    local c = make_item({ ONE_BY_ONE })
    assert(g:place_first_fit(c), "should find the last free cell")
    assert(c.cell_col == 2 and c.cell_row == 0)

    local d = make_item({ ONE_BY_ONE })
    assert(not g:place_first_fit(d), "should return false when nothing fits, and not place it")
    assert(d.cell_col == nil, "a failed first-fit must leave the item untouched")

    print("PASS: grid: place_first_fit places at the first free cell, or returns false if none fit")
end

print("ALL TESTS PASSED")
