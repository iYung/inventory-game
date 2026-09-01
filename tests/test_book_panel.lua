-- tests/test_book_panel.lua
-- Headless tests for lua/game/book_panel.lua.

require("lua/headless/stubs")
local Item      = require("lua/game/item")
local BookPanel = require("lua/game/book_panel")
local config    = require("lua/game/config")

-- Test 1: BookPanel.new errors for a non-book item. -------------------------

do
    local chicken = Item.new("raw_chicken")
    local ok, err = pcall(BookPanel.new, chicken)
    assert(ok == false, "BookPanel.new should error for an item without has_book_panel")
    print("PASS: book_panel: BookPanel.new errors for non-book item")
end

-- Test 2: BookPanel.new succeeds for garden_book. ---------------------------

do
    local book = Item.new("garden_book")
    local panel = BookPanel.new(book)
    assert(panel.item == book, "BookPanel should store the item")
    assert(panel.should_close == false, "should_close starts false")
    assert(panel.should_leave == false, "should_leave always false")
    assert(panel.should_serve == false, "should_serve always false")
    assert(panel.should_skip  == false, "should_skip always false")
    print("PASS: book_panel: BookPanel.new succeeds for garden_book")
end

-- Test 3: _point_in_grid always returns false. ------------------------------

do
    local book = Item.new("microwave_book")
    local panel = BookPanel.new(book)
    assert(panel:_point_in_grid(0, 0) == false, "_point_in_grid should always be false")
    assert(panel:_point_in_grid(panel.bg.x + 10, panel.bg.y + 40) == false,
        "_point_in_grid should be false even inside the panel")
    print("PASS: book_panel: _point_in_grid always false")
end

-- Test 4: _point_in_bg hits inside the backdrop rect. ----------------------

do
    local book = Item.new("garden_book")
    local panel = BookPanel.new(book)
    local cx = panel.bg.x + panel.bg.w / 2
    local cy = panel.bg.y + panel.bg.h / 2
    assert(panel:_point_in_bg(cx, cy), "_point_in_bg should be true for center")
    assert(not panel:_point_in_bg(-999, -999), "_point_in_bg should be false outside")
    print("PASS: book_panel: _point_in_bg correctly hit-tests backdrop")
end

-- Test 5: clicking close button sets should_close. -------------------------

do
    local book = Item.new("garden_book")
    local panel = BookPanel.new(book)
    local cb = panel.close_button
    local consumed = panel:mouse_pressed(cb.x + cb.w / 2, cb.y + cb.h / 2)
    assert(consumed == true, "close button click should be consumed")
    assert(panel.should_close == true, "should_close should be set by close button")
    print("PASS: book_panel: close button sets should_close")
end

-- Test 6: title-bar drag moves the panel. ----------------------------------

do
    local book = Item.new("microwave_book")
    local panel = BookPanel.new(book)
    local orig_x = panel.bg.x
    local orig_y = panel.bg.y
    local tb = panel.title_bar
    -- Press on title bar (not close button area - press near left edge)
    panel:mouse_pressed(tb.x + 10, tb.y + tb.h / 2)
    assert(panel._dragging_panel == true, "title bar press should start drag")
    -- Move 20px right, 10px down
    panel:mouse_moved(tb.x + 30, tb.y + tb.h / 2 + 10)
    assert(panel.bg.x ~= orig_x or panel.bg.y ~= orig_y, "panel should move on drag")
    -- Release ends drag
    panel:mouse_released(0, 0)
    assert(panel._dragging_panel == false, "mouse_released should end drag")
    print("PASS: book_panel: title-bar drag moves panel")
end

-- Test 7: microwave_book also constructs correctly. ------------------------

do
    local book = Item.new("microwave_book")
    local panel = BookPanel.new(book)
    assert(panel.item.type_id == "microwave_book")
    assert(panel.bg.w == 160 + 16 * 2, "bg_w should be IMG_W + 2*MARGIN")
    assert(panel.bg.h == 28 + 16 + 120 + 16, "bg_h should be TITLE_H + MARGIN + IMG_H + MARGIN")
    print("PASS: book_panel: microwave_book constructs with correct dimensions")
end
