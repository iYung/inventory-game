## Cooking Methods Checklist

Source design doc: `docs/design/cooking-methods.md`.

Sequencing legend: **Wave 1** tasks have no dependencies on each other and can
run fully in parallel. **Wave 2** tasks depend on specific Wave 1 tasks
(named inline) and must not start until those are done. **Wave 3** is tests,
sequenced after the code they cover.

---

### Wave 1 — independent, run in parallel

- [x] **Task 1 — `lua/game/data/item_defs.lua`** — Add the new items and
  update the microwave, per the design doc's "New items" and "Microwave
  changes" sections.
  - Add these top-level entries to the `item_defs` table (exact shapes from
    the design doc; colors below are suggestions in the existing `{r,g,b,a}`
    0-1 float style — the exact color values are not load-bearing, just keep
    each one visually distinct from existing items):
    ```lua
    potato = {
        name = "Potato",
        footprint = { { 0, 0 } },
        color = { 0.85, 0.75, 0.55, 1 },
    },

    water = {
        name = "Water",
        footprint = { { 0, 0 } },
        color = { 0.40, 0.65, 0.90, 1 },
    },

    fries = {
        name = "Fries",
        footprint = { { 0, 0 } },
        color = { 0.95, 0.75, 0.25, 1 },
        tags = { "Greasy" },
    },

    baked_potato = {
        name = "Baked Potato",
        footprint = { { 0, 0 } },
        color = { 0.70, 0.55, 0.35, 1 },
        tags = { "Filling" },
    },

    beef_stew = {
        name = "Beef Stew",
        footprint = { { 0, 0 }, { 1, 0 }, { 2, 0 } },
        color = { 0.60, 0.40, 0.25, 1 },
        tags = { "Filling", "Protein" },
    },

    fryer = {
        name = "Fryer",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color = { 0.35, 0.35, 0.40, 1 },
        has_panel = true,
        panel_cols = 1,
        panel_rows = 1,
        actions = {
            { name = "Fry", duration = 3.0, requires = { potato = 1 }, produces = { fries = 1 } },
        },
    },

    dutch_oven = {
        name = "Dutch Oven",
        footprint = { { 0, 0 }, { 1, 0 } },
        color = { 0.25, 0.25, 0.30, 1 },
        has_panel = true,
        panel_cols = 3,
        panel_rows = 1,
        -- No `actions` field: the dutch oven is never clicked/cooked
        -- directly — see the microwave's new `container` recipe below.
    },
    ```
  - Update the existing `microwave` entry: change `panel_cols = 1` to
    `panel_cols = 2` (`panel_rows` stays `1`), and replace its single
    `actions[1].recipes` list (currently `raw_meat`/`broccoli`) with:
    ```lua
    recipes = {
        { requires = { raw_meat = 1 }, produces = { cooked_meat = 1 } },
        { requires = { broccoli = 1 }, produces = { steamed_broccoli = 1 } },
        { requires = { potato = 1 },   produces = { baked_potato = 1 } },
        {
            container = "dutch_oven",
            requires  = { potato = 1, water = 1, raw_meat = 1 },
            produces  = { beef_stew = 1 },
        },
    },
    ```
  - Update the file's header comment (currently documents the plain
    `recipes` shape) to add a paragraph documenting the new `container`
    field: a recipe with `container = "<type_id>"` is only satisfied when an
    item of that type_id is sitting in the acting item's own panel AND that
    item's own panel satisfies `requires`; on completion, `requires` is
    removed from and `produces` is placed into the **container item's
    panel**, not the acting item's panel. See `lua/game/item.lua`'s
    `matching_recipes` (Task 2) for the implementation this documents.
  - Do not touch `lua/game/item.lua`, `lua/game/item_panel.lua`, or any
    other file — this task is data-only.

- [x] **Task 2 — `lua/game/item.lua`** — Rework the recipe-matching engine
  to (a) fire every satisfied recipe in one action press instead of just the
  first match, and (b) support `container` recipes (a nested container item,
  e.g. a loaded dutch oven, sitting inside the acting item's panel). This is
  the dependency root for Tasks 5, 7, and 8 below — write it against the
  recipe shape Task 1 introduces (`requires`/`produces`, optionally a
  `container = "<type_id>"` field), even though Task 1 may not have landed
  yet.
  - Replace the existing `local function matching_recipe(action, counts)`
    (currently ~line 143) with the following pieces:
    - `local function satisfies(requires, counts)` — extracted from
      `matching_recipe`'s inner loop: returns `true` iff every
      `type_id = needed` pair in `requires` has `(counts[type_id] or 0) >=
      needed`. (`requires` may be nil — treat as "always satisfied", same as
      the current code's `pairs(recipe.requires or {})`.)
    - `local function find_item_of_type(panel, type_id)` — returns the
      first item in `panel:items()` whose `type_id == type_id`, or `nil`.
    - `local function matching_recipes(action, panel)` (plural, replaces
      `matching_recipe`; note the signature change from `(action, counts)`
      to `(action, panel)` — it now computes counts itself) — returns a
      list of `{ recipe = <recipe>, target_item = <item-or-nil> }` for
      *every* recipe on `action` currently satisfied by `panel`'s contents:
      ```lua
      local function matching_recipes(action, panel)
          local counts = count_panel_items(panel)
          local matches = {}
          for _, recipe in ipairs(action_recipes(action)) do
              if recipe.container then
                  local container_item = find_item_of_type(panel, recipe.container)
                  if container_item and satisfies(recipe.requires, count_panel_items(container_item.panel)) then
                      matches[#matches + 1] = { recipe = recipe, target_item = container_item }
                  end
              elseif satisfies(recipe.requires, counts) then
                  matches[#matches + 1] = { recipe = recipe, target_item = nil }
                  for type_id, needed in pairs(recipe.requires or {}) do
                      counts[type_id] = counts[type_id] - needed
                  end
              end
          end
          return matches
      end
      ```
      Note a container recipe's own requirements are checked against (and
      never deducted from) `counts` — only the container's own panel counts
      — so a container recipe can never double-claim an ingredient sitting
      loose in the acting item's panel, and vice versa.
  - Update `Item:start_action(name)`: replace
    `local recipe = matching_recipe(action, count_panel_items(self.panel))`
    / `if not recipe then return false end` with
    `local matches = matching_recipes(action, self.panel)` /
    `if #matches == 0 then return false end`, and change the stored state to
    `self.action_state[name] = { running = true, elapsed = 0, matches = matches }`
    (was `recipe = recipe`).
  - Update `complete_action(self, def, recipe)` (currently ~line 222):
    rename its third parameter to `matches` and iterate it:
    ```lua
    local function complete_action(self, def, matches)
        for _, match in ipairs(matches) do
            local recipe      = match.recipe
            local target_item = match.target_item
            local target_panel = target_item and target_item.panel or self.panel
            local target_def   = target_item and item_defs[target_item.type_id] or def

            for type_id, count in pairs(recipe.requires or {}) do
                remove_matching(target_panel, type_id, count)
            end

            for type_id, count in pairs(recipe.produces or {}) do
                for _ = 1, count do
                    local new_item = Item.new(type_id)
                    place_first_fit(target_panel, new_item, target_def.panel_cols, target_def.panel_rows)
                end
            end
        end
    end
    ```
  - Update the one call site in `Item:update` (currently
    `complete_action(self, def, state.recipe)`) to
    `complete_action(self, def, state.matches)`.
  - Export the new engine function so `lua/game/item_panel.lua` (Task 5)
    can reuse the exact same matching logic instead of re-implementing it:
    add `Item.matching_recipes = matching_recipes` right before the final
    `return Item` at the bottom of the file (after `matching_recipes` is
    defined, so the reference resolves).
  - Do not touch `lua/game/item_panel.lua`, `game/scenes/kitchen_scene.lua`,
    or `lua/game/data/item_defs.lua` in this task.

- [x] **Task 3 — `game/scenes/kitchen_scene.lua` (double-click/right-click
  generalization)** — Generalize the "open a container's panel" gesture so
  it works on an item sitting inside any currently-open panel's own grid,
  not just the main floor grid (this is what will let a player double-click
  the dutch oven while it's sitting inside the already-open microwave
  panel). This task does **not** touch `on_enter` (that's Task 6) and does
  **not** depend on Task 1/Task 2 — write and test it using only items that
  already exist (`microwave`, `raw_meat`) plus a manually-constructed
  second `has_panel` item if you need one to stand in for "a container
  sitting inside another open panel's grid" (e.g. temporarily place another
  `microwave` instance into an open microwave's panel for the purposes of a
  manual sanity check — the real dutch-oven-in-microwave scenario is
  exercised later by Task 9's test, once Task 1 exists).
  - Add a new field `self._last_click_grid = nil` alongside the existing
    `self._last_click_time/_last_click_col/_last_click_row = nil` lines in
    `on_enter` (~line 101-103) — double-click matching must now also check
    that the second click landed on the *same grid* as the first, not just
    the same col/row (two different grids can share col/row coordinates).
  - Add a private helper method, e.g.:
    ```lua
    -- Checks (x,y) against `grid` for the double-click-to-open-panel
    -- gesture: if a has_panel item sits at that cell AND this is a second
    -- click within DOUBLE_CLICK_WINDOW on the same cell of the same grid,
    -- opens/focuses its panel and returns true (caller should stop, not
    -- fall through to that grid's normal drag-start handling). Otherwise
    -- records this click's bookkeeping and returns false.
    function KitchenScene:_try_double_click_open(grid, x, y)
        local col, row = grid:world_to_cell(x, y)
        local item      = grid:item_at(col, row)
        local now        = love.timer.getTime()

        if item then
            local def = item_defs[item.type_id]
            if def and def.has_panel then
                local is_double_click = self._last_click_time
                    and (now - self._last_click_time) <= DOUBLE_CLICK_WINDOW
                    and self._last_click_grid == grid
                    and self._last_click_col == col
                    and self._last_click_row == row

                if is_double_click then
                    self:_open_or_focus_panel(item)
                    self._last_click_time = nil
                    self._last_click_grid = nil
                    self._last_click_col  = nil
                    self._last_click_row  = nil
                    return true
                end
            end
        end

        self._last_click_time = now
        self._last_click_grid = grid
        self._last_click_col  = col
        self._last_click_row  = row
        return false
    end
    ```
  - In `mouse_pressed`, inside the existing topmost-first panel loop (the
    block starting `for i = #self.panels, 1, -1 do ... if panel:_point_in_bg(x, y) then`),
    insert a check right after `self:_bring_to_front(panel)` and before the
    existing `panel:mouse_pressed(x, y)` call: if `panel:_point_in_grid(x, y)`
    is true, call `if self:_try_double_click_open(panel.item.panel, x, y) then return end`.
    This must run *before* `panel:mouse_pressed(x, y)` — otherwise the first
    click of the double-click would already have been consumed as a
    drag-start by the panel's own grid.
  - Remove the old main-floor-only double-click block (currently the
    `local col, row = self.grid:world_to_cell(x, y) ... self.grid:mouse_pressed(x, y)`
    section near the bottom of `mouse_pressed`) and replace it with:
    `if self:_try_double_click_open(self.grid, x, y) then return end`
    followed by the existing `self.grid:mouse_pressed(x, y)` call.
  - Generalize `mouse_right_pressed` the same way: currently, a right-click
    landing on any open panel's backdrop is an unconditional no-op. Change
    it so a right-click landing specifically inside an open panel's own
    grid (`panel:_point_in_grid(x, y)`, checked topmost-first) opens/focuses
    the `has_panel` item under the cursor on *that* grid, while a
    right-click on the rest of that panel's backdrop (title bar, buttons,
    dead space) remains a no-op exactly as today. A right-click that misses
    every open panel falls through to the existing main-floor-grid
    behavior, unchanged. Concretely:
    ```lua
    function KitchenScene:mouse_right_pressed(x, y)
        for i = #self.panels, 1, -1 do
            local panel = self.panels[i]
            if panel:_point_in_bg(x, y) then
                if panel:_point_in_grid(x, y) then
                    self:_open_container_at(panel.item.panel, x, y)
                end
                return
            end
        end

        self:_open_container_at(self.grid, x, y)
    end
    ```
    with a small shared helper (used only by right-click, since it has no
    timing/double-click logic):
    ```lua
    function KitchenScene:_open_container_at(grid, x, y)
        local col, row = grid:world_to_cell(x, y)
        local item      = grid:item_at(col, row)
        if not item then return end
        local def = item_defs[item.type_id]
        if not (def and def.has_panel) then return end
        self:_open_or_focus_panel(item)
    end
    ```
  - Verify by reasoning through existing `tests/test_kitchen_scene.lua`
    Test 8 and Test 13 (main-floor double-click / right-click, panel
    dedup/bring-to-front) that this refactor preserves their behavior
    exactly — those tests are not modified by this task (they're main-floor
    only, so `_hover_grid`-equivalent routing still resolves to `self.grid`
    for every click they make). Do not edit the test files in this task —
    that's Task 9.

- [x] **Task 4 — `lua/game/customer_queue.lua`** — In
  `make_merchant_cfg()`'s `stock` table (currently
  `{ "raw_meat", "raw_meat", "broccoli" }`), add `"water"` and `"potato"` as
  two more entries (exact count/order not load-bearing, just make sure both
  new type ids appear at least once so a merchant visit can sell them).

---

### Wave 2 — depends on Wave 1

- [x] **Task 5 — `lua/game/item_panel.lua`** — *Depends on Task 2* (needs
  `Item.matching_recipes` to exist). Update `is_action_enabled` to reuse the
  same container-aware recipe-matching logic Task 2 added to
  `lua/game/item.lua`, instead of its own local duplicate (which only
  checks a flat `requires` and knows nothing about `container` recipes —
  today it would incorrectly report a loaded-dutch-oven-in-microwave Cook
  button as disabled).
  - Add `local Item = require("lua/game/item")` alongside the file's
    existing requires at the top.
  - Remove the local `count_panel_items` and `action_recipes` helper
    functions (currently ~lines 151-169) — they become dead code once
    `is_action_enabled` no longer needs them (confirm nothing else in the
    file calls them before deleting).
  - Replace the body of `is_action_enabled(name)` with:
    ```lua
    function ItemPanel:is_action_enabled(name)
        local action = find_action(self.def, name)
        if not action then return false end

        local state = self.item.action_state and self.item.action_state[name]
        if state and state.running then
            return false
        end

        return #Item.matching_recipes(action, self.item.panel) > 0
    end
    ```
    (Keep the local `find_action` helper — it's unrelated, still needed.)
  - Do not change anything else in the file (button layout, draw, drag
    forwarding, Leave-button logic are all untouched).

- [x] **Task 6 — `game/scenes/kitchen_scene.lua` (starting floor layout)**
  — *Depends on Task 1* (needs `fryer`, `dutch_oven`, and `potato` to exist
  in `item_defs`). In `on_enter`, after the existing broccoli-placement
  block (~line 81), add:
  - One `fryer` (2x2 footprint) placed at cells `(5,0)-(6,1)` — i.e. anchor
    `(5,0)`.
  - One `dutch_oven` (2x1 footprint) placed at cells `(7,0)-(8,0)` — i.e.
    anchor `(7,0)`.
  - Two `potato` items (1x1 each) placed at `(2,2)` and `(3,2)`.
  - Follow the exact existing pattern used for `meat_cells`/`broccoli_cells`
    just above: build the item with `Item.new(type_id)`, assert
    `self.grid:can_place(item, col, row)` before placing (with a message
    string following the existing style, e.g. `"fryer starting cell should
    be free"`), then `self.grid:place(item, col, row)`. These specific
    cells are chosen to be clear of the existing microwave `(0,0)-(1,1)`,
    meat `(2,0),(3,0),(4,0)`, and broccoli `(2,1),(3,1)` footprints, and to
    fit inside the 10x6 grid (`config.GRID_COLS = 10`, `config.GRID_ROWS =
    6`) — exact cells are not otherwise load-bearing.
  - Do not touch `mouse_pressed`/`mouse_right_pressed`/any other method in
    this file — that's Task 3's territory, done separately.

---

### Gap found during Wave 1 (fixed out-of-band, not a numbered task)

- [x] `tests/test_day_loop.lua` asserted merchant stock contained exactly
  `raw_meat`/`broccoli` (2 unique types). Task 4 legitimately adds
  `water`/`potato` to that stock per the design doc, which broke this
  assertion. No checklist task owned this file; updated the assertion
  in-place to expect 4 stock types (`raw_meat`, `broccoli`, `water`,
  `potato`) instead of loosening/removing the check.

### Wave 3 — tests, depend on the code they cover

- [x] **Task 7 — `tests/test_item.lua`** — *Depends on Tasks 1 and 2.* Add
  new `do ... end` test blocks (following the file's existing style —
  direct `Item.new`/`panel:place` calls, `assert` with descriptive
  messages, a `print("PASS: ...")` at the end of each block) covering:
  1. **Container recipe, happy path.** Build a `microwave` and a
     `dutch_oven`; place the dutch oven into the microwave's panel at
     `(0,0)` (fits since the microwave's panel is now 2 cols wide and the
     dutch oven's footprint is 2x1). Load the dutch oven's own panel (3
     cols) with one `potato`, one `water`, and one `raw_meat` at cells
     `(0,0)`, `(1,0)`, `(2,0)`. Call `microwave:start_action("Cook")` and
     assert it returns `true`. Call `microwave:update(3.5)` (past the
     3.0s duration). Assert the dutch oven's own panel (`dutch_oven.panel:items()`)
     now contains exactly one item with `type_id == "beef_stew"`, and that
     the microwave's own panel (`microwave.panel:items()`) is unchanged —
     still contains exactly the one `dutch_oven` item, itself untouched
     (not consumed).
  2. **Container recipe, not satisfied.** Same setup, but the dutch oven's
     panel is missing one ingredient (e.g. no `water`). Assert
     `microwave:start_action("Cook")` returns `false` and
     `microwave.action_state["Cook"]` stays `nil`.
  3. **Container recipe requires the container to actually be present.**
     A microwave with `potato`+`water`+`raw_meat` placed loose (not inside
     a dutch oven) directly in the microwave's own 2-cell panel does not
     satisfy the container recipe — assert `start_action("Cook")` returns
     `false` in this case (there being no `dutch_oven` item in the
     microwave's panel for `find_item_of_type` to find). Note the
     microwave's panel is only 2 cells, so this scenario places 2 of the 3
     ingredients or otherwise fits within that constraint — the point of
     the test is "no dutch oven present" not "not enough room."
  4. **Multiple recipes fire in one press.** Place one `raw_meat` and one
     `broccoli` together in the microwave's panel (both fit now that
     `panel_cols == 2`). Call `start_action("Cook")`, assert `true`, then
     `update(3.5)`. Assert the panel now contains exactly two items: one
     `cooked_meat` and one `steamed_broccoli` (both recipes fired from the
     single press).
  5. **New simple potato recipe still works.** One `potato` in the
     microwave's panel; `start_action("Cook")` returns `true`; after
     `update(3.5)`, panel contains one `baked_potato`.
  6. **Fryer recipe.** A `fryer` item's panel holds one `potato`;
     `fryer:start_action("Fry")` returns `true`; after
     `fryer:update(3.5)`, its panel contains one `fries` item.
  - Do not modify any existing test block in this file — all of the above
    are additions.

- [x] **Task 8 — `tests/test_item_panel.lua`** — *Depends on Tasks 1, 2,
  and 5.* Add new `do ... end` blocks (matching the file's existing style)
  covering `is_action_enabled("Cook")` around the container-recipe
  scenarios, mirroring the setups in Task 7:
  1. A microwave with a fully-loaded dutch oven (potato+water+raw_meat) in
     its own panel, dutch oven sitting in the microwave's panel: wrap the
     microwave in `ItemPanel.new(microwave)` and assert
     `panel:is_action_enabled("Cook") == true`.
  2. Same setup but the dutch oven is only partially loaded (e.g. missing
     `raw_meat`): assert `is_action_enabled("Cook") == false`.
  3. A dutch oven fully loaded but sitting loose on the main floor grid
     (not inside the microwave's panel) does not enable the microwave's
     Cook button: assert `is_action_enabled("Cook") == false` for a fresh
     microwave with nothing in its own panel.
  4. Sanity check that the plain (non-container) recipes still work through
     the new `Item.matching_recipes`-backed `is_action_enabled`: one
     `potato` alone in the microwave's panel enables Cook (new
     potato->baked_potato recipe).
  - Do not modify any existing test block in this file.

- [x] **Task 9 — `tests/test_kitchen_scene.lua`** — *Depends on Tasks 1, 2,
  3, and 6* (needs `dutch_oven`/`microwave` panel changes, the engine
  rework, and the generalized double-click/right-click gesture all in
  place). Add a new numbered test block (follow the file's existing
  numbering/style — `do ... end`, `runner.setup`, descriptive asserts,
  trailing `print("PASS: ...")`) covering:
  1. Open a microwave's panel (`scene.panels = { ItemPanel.new(microwave) }`,
     same pattern as the file's existing Test 2/Test 4). Place a
     `dutch_oven` item directly into the microwave's panel at `(0,0)`
     (`microwave.panel:place(dutch_oven, 0, 0)` — no need to drive it
     through a drag for this test).
  2. Simulate a double-click on the dutch oven's cell *within the open
     microwave panel* (two `mouse_pressed`+`mouse_released` pairs at the
     same world coordinates, computed via
     `microwave.panel:cell_to_world(0, 0)` plus a small offset, same
     pattern as the existing main-floor double-click test). Assert this
     opens a *second* panel: `#scene.panels == 2` and the new topmost panel
     (`scene.panels[2]`) has `.item == dutch_oven`.
  3. In a fresh scene setup, repeat the same placement and instead
     right-click once (`scene:mouse_right_pressed(x, y)`) on the dutch
     oven's cell inside the open microwave panel; assert it opens the dutch
     oven's panel in one click, same assertions as above.
  4. Regression check: right-clicking elsewhere on the open microwave
     panel's backdrop (e.g. its title bar) with nothing else set up still
     does nothing (`#scene.panels` unchanged) — confirms Task 3's
     generalization didn't loosen the "backdrop dead space is a no-op"
     rule for right-click.
  - Do not modify any existing numbered test block in this file — Task 3's
    design note explicitly requires existing main-floor double-click/
    right-click tests (Test 8, Test 13) to keep passing unchanged; this
    task only adds new coverage for the nested-panel case.
  - Separately (still this task, since it's the same file and same "run
    the suite" checkpoint): check whether Task 1's microwave `panel_cols =
    2` change breaks any existing assertion in this file that hardcodes the
    microwave's panel as 1x1 — in particular, existing Test 12 currently
    asserts `microwave12.panel.cols == 1 and microwave12.panel.rows == 1`.
    Update that assertion to `microwave12.panel.cols == 2 and
    microwave12.panel.rows == 1` (the surrounding comment/message text
    should be updated to match — the microwave's *floor footprint* is still
    2x2, only its *internal panel* width changed from 1 to 2). Leave every
    other existing assertion in the file as-is unless running the full
    suite after Tasks 1-6 land surfaces another failure traceable to the
    panel resize (e.g. a comment in `tests/test_item_panel.lua` Test 6
    describing the microwave's panel as "a single cell (1x1)" is now
    slightly inaccurate but not a real path change — do not modify
    `test_item_panel.lua` from this task; that file is already covered by
    Task 8).
  - One more known stale spot from the panel resize, confirmed by running
    the suite after Tasks 1-6 landed — fix as part of this task: **Test 14**
    ("dragging an item onto the microwave inserts it into the panel if
    there's room, else snaps back") assumes the microwave's panel is 1x1
    and therefore "full" after one item lands in it (see its comment above
    the second drag: "The microwave's panel is 1x1 and now full"). That's
    no longer true at 2x1 capacity — the second raw_meat now has room and
    would actually land in the panel instead of snapping back, which would
    make the existing assertions (`meatB.grid == scene14.grid`, unchanged
    cell) fail for a real behavioral reason, not a stale-label reason.
    Update this test to still cover BOTH outcomes at the new capacity: drop
    two items (fills both of the microwave's 2 panel cells - both should
    land in the panel), then attempt a THIRD drop the same way and assert
    THAT one snaps back (no room left). Update the surrounding comments to
    describe 2-cell capacity instead of 1x1.
    (Note: Task 6 already relocated the fryer/dutch_oven starting-floor
    placement itself, from the checklist's original `(5,0)`/`(7,0)` to
    `(6,0)`/`(8,0)`, to avoid colliding with this file's existing test
    fixtures at `(5,0)`/`(5,3)` — that collision is already resolved, no
    action needed here.)
