## Cooking Inventory Game Checklist

Design doc: `docs/design/cooking-inventory-game.md`.

### Shared contracts (read this before starting any task — do not deviate without a good reason, and if you must, note it clearly in your summary)

**Footprint**: a list of `{dx, dy}` integer cell offsets relative to an item's
anchor cell, e.g. 1x1 = `{{0,0}}`, 2x2 = `{{0,0},{1,0},{0,1},{1,1}}`. Rotating
90° maps `(dx,dy) -> (-dy,dx)` then the result is re-normalized so the minimum
dx/dy is 0 again (keeps footprints anchored to a positive-offset origin cell).

**`lua/game/config.lua`** already exists (written up front, treat as fixed):
`U` (cell size px), `GRID_COLS`, `GRID_ROWS`, `GRID_ORIGIN_X`, `GRID_ORIGIN_Y`
(top-left of the bottom-half grid), `SPLIT_Y` (360, top/bottom divider),
`SCREEN_W`/`SCREEN_H` (1280/720), plus a small placeholder color palette.

**`lua/game/item_defs.lua`** (data, keyed by type id string) shape per entry:
`{ name, footprint, color, has_panel, panel_cols, panel_rows, actions }`.
`actions` (only on containers) is a list of
`{ name, requires = {type_id = count, ...}, produces = {type_id = count, ...}, duration }`.
MVP content: `raw_meat` (1x1), `cooked_meat` (1x1), `microwave` (2x2,
`has_panel=true`, `panel_cols=2, panel_rows=1`, one action `"Cook"`:
requires `{raw_meat=1}`, produces `{cooked_meat=1}`, duration `3.0`).

**`lua/game/item.lua`** (`Item`) API: `Item.new(type_id)`; fields `type_id`,
`rotation` (0/1/2/3 quarter-turns), `cell_col`/`cell_row` (nil until placed),
`sprite` (placeholder colored-rect `Sprite`, sized to the rotated footprint's
bounding box * `U`), `panel` (an `Item` — no, a `Grid` instance if
`has_panel`, else nil), `action_state` (per-action `{elapsed, running}`, keyed
by action name). Methods: `Item:footprint()` (rotated, normalized cells),
`Item:rotate()` (rotation = (rotation+1)%4, refreshes sprite size),
`Item:update(dt)` (ticks any running action timer; on completion, decrements
matching `requires` items from `self.panel` and adds new `Item.new(output)`
per `produces`, using the freed cells), `Item:start_action(name)` (validates
`requires` against current panel contents, starts timer if valid, no-op
otherwise), `Item:draw()`.

**`lua/game/grid.lua`** (`Grid`) — generic, used for both the main floor grid
and an item's inner panel grid. API: `Grid.new(cols, rows, cell_size,
origin_x, origin_y)`; `Grid:can_place(item, col, row)`; `Grid:place(item, col,
row)` (sets `item.cell_col/row` and `item.grid = self`); `Grid:remove(item)`;
`Grid:items()`; `Grid:item_at(col, row)`; `Grid:cell_to_world(col,row)` /
`Grid:world_to_cell(x,y)`; `Grid:mouse_pressed(x,y)` (starts a drag if an item
occupies that world position — sets `self.dragging`); `Grid:mouse_moved(x,y)`
(updates drag preview position, tracked in grid cell space via
`world_to_cell`); `Grid:mouse_released(x,y)` (attempts to drop at the preview
cell via `can_place`; on failure snaps back to the item's original cell);
`Grid:rotate_dragged()` (rotates `self.dragging` in place, no validity check
until drop); `Grid:update(dt)` (calls `item:update(dt)` for every item, so
that panel grids nested inside items also tick when the outer grid ticks —
outer grid's `update` should NOT separately walk into `item.panel`, that's
`Item:update`'s job. `Item:update` itself must call `self.panel:update(dt)`
if it has one, so timers inside a closed panel keep running); `Grid:draw()`
(draws grid background cells, all items, and a drag preview highlight).
Double-click detection is NOT part of Grid — it's the scene's job (see task
below); Grid only knows about drag.

Tasks below are grouped into **waves**. Tasks within a wave can run in
parallel (fully specified by the contracts above). Do not start a wave until
the previous wave's tasks are all checked off.

---

#### Wave 0 (done up front, not a task — `lua/game/config.lua` already exists)

---

#### Wave 1 (parallel)

- [x] Task A — `lua/game/grid.lua`, `tests/test_grid.lua` — implement `Grid`
  per the contract above. Test: placing a 1x1 and a 2x2 item, rejecting
  overlap, rejecting out-of-bounds, drag-then-invalid-drop snaps back to
  original cell, drag-then-valid-drop moves the item, `rotate_dragged`
  changes footprint dimensions.
- [x] Task B — `lua/game/item.lua`, `lua/game/data/item_defs.lua`,
  `tests/test_item.lua` — implement `Item` and the MVP item defs
  (`raw_meat`, `cooked_meat`, `microwave`) per the contract above. Test:
  rotate cycles through 4 states and back to original footprint,
  `start_action` no-ops without required items in `panel`, `start_action`
  with required items present starts the timer, `update(dt)` past `duration`
  transforms the item(s) in `panel` from `raw_meat` to `cooked_meat` in
  place (same cell(s)).
- [x] Task C — `lua/game/customer.lua`, `tests/test_customer.lua` — adapt
  `../wip/lua/game/customer.lua`'s state machine (`idle -> walking_in ->
  waiting -> walking_out -> idle`) and pre/post message speech-bubble
  typewriter reveal. Strip plant-specific bits (plant_type, color-replace
  shader, plant image swap in the bubble); replace the sprite with a
  placeholder colored-rect `Sprite` (via `lua/core/sprite.lua`, no images).
  Add a `requested_type` field (an item type id string, e.g.
  `"cooked_meat"`) set via `Customer:show(cfg)` alongside `cfg.messages` /
  `cfg.after_messages` as today. Keep `Customer:serve()` /
  `Customer:dismiss()` semantics from wip (serve = happy path with
  after-messages then walk out; dismiss = walk out immediately, no
  after-messages) — the scene will call `serve()` on a correct item drop and
  `dismiss()` on an incorrect one. Test: full state walk (idle -> walking_in
  -> waiting -> serve -> walking_out -> idle), dismiss short-circuits
  straight to walking_out.

#### Wave 2 (parallel, after Wave 1 is fully checked off)

- [x] Task D — `lua/game/item_panel.lua`, `tests/test_item_panel.lua` — a
  popup that wraps an `Item`'s `panel` `Grid` plus its `actions` as buttons.
  Read the actual `Item`/`Grid` APIs from the files Task A/B produced (the
  contract above should match, but the real files are the source of truth).
  API: `ItemPanel.new(item)` (errors if `item.panel` is nil);
  `ItemPanel:mouse_pressed/moved/released(x,y)` forward into `item.panel`
  when `x,y` fall inside the panel's grid bounds, otherwise check the action
  button rects; `ItemPanel:is_action_enabled(name)` (checks the action's
  `requires` against current panel contents); clicking an enabled button
  calls `item:start_action(name)`; `ItemPanel:draw()` draws the panel grid,
  its items, and one button per action (dimmed/disabled look when
  `is_action_enabled` is false, a simple fill/progress bar over the button
  while `item.action_state[name].running` is true, computed from
  `elapsed/duration`). Test: button disabled with empty panel, enabled once
  a matching item is dragged in, clicking starts the timer, panel contents
  update after the timer completes (via `item:update`).
- [x] Task E — `lua/game/customer_queue.lua`, `lua/game/day_state.lua`,
  `tests/test_day_loop.lua` — `DayState.new()` tracks `day` (starts at 1),
  `customers_served`, `customers_total`, `currency` (starts at 0).
  `CustomerQueue.new(total)` holds an ordered list of `total` customer
  configs (MVP: all the same — name "Customer", `requested_type =
  "cooked_meat"`, a pre-message asking for it, an after-message thanking
  the player) and an index; `CustomerQueue:next()` returns the next config
  or nil when exhausted; `CustomerQueue:has_next()`. `DayState:record_serve()`
  increments `customers_served` and `currency` (e.g. +10);
  `DayState:record_dismiss()` increments `customers_served` only (no
  currency); `DayState:day_complete()` returns `customers_served >=
  customers_total`; `DayState:advance_day()` increments `day`, resets
  `customers_served` to 0, and returns a fresh `CustomerQueue.new(...)` for
  the new day (total is a fixed constant for MVP, e.g. 3 — put it in
  `config.lua` as `CUSTOMERS_PER_DAY` and add it there in this task since it
  wasn't needed until now). Test: queue exhausts after N `next()` calls,
  `day_complete()` false then true after N `record_serve`/`record_dismiss`
  calls, `advance_day()` resets counters and bumps `day`.

#### Wave 3 (sequential, after Wave 2 is fully checked off — integration)

- [x] Task F — `game/scenes/kitchen_scene.lua`, update `main.lua`, remove
  `game/player.lua` and `game/scenes/game_scene.lua`, add a `love.mouse`
  stub to `lua/headless/stubs.lua`, replace `tests/test_scene.lua` and
  `tests/test_basics.lua` (they currently require the deleted
  `game/scenes/game_scene.lua` / exercise `Player` — repoint them at
  `KitchenScene` instead, keeping the spirit of what they check: `Scene.new`
  dimension threading still covered by `test_scene.lua` testing
  `KitchenScene`'s inherited `camera`/`drawer`, and `test_basics.lua`
  ticking a fresh `KitchenScene` without error via `runner.setup`).
  `kitchen_scene.lua` extends `Scene` (1280x720, static camera, no
  `follow`), owns: a main `Grid` (from `config.lua` dims) pre-populated at
  `on_enter` with one `microwave` and a few `raw_meat` items (placement
  positions your judgment, just must not overlap); a `DayState` +
  `CustomerQueue` (via `DayState:advance_day()`-style setup for day 1); one
  active `Customer` on the top half, spawned via its `:show(cfg)` when the
  previous one finishes walking out (or immediately on `on_enter` for the
  first); a "Next Day" `Sprite`+click-region button drawn only when
  `day_state:day_complete()` is true, which on click calls
  `day_state:advance_day()` and spawns the first customer of the new day;
  an open `ItemPanel` (nil unless a container item was double-clicked).
  Wire `love.mousepressed(x, y, button)`, `love.mousereleased(x, y,
  button)`, `love.mousemoved(x, y)` in `main.lua` to forward
  canvas-scaled coordinates to `manager.current` (add thin
  `KitchenScene:mouse_pressed/moved/released(x,y)` methods that: (1) if an
  `ItemPanel` is open, forward there first, with a click outside its bounds
  closing it; (2) else if a click lands inside the "Next Day" button rect
  and it's visible, advance the day; (3) else if a click lands on the
  active `Customer` while `waiting`, and the main grid currently has a
  dragged item at release time matching the customer's `requested_type`,
  call `customer:serve()`, remove the item from the grid, and
  `day_state:record_serve()`; if it doesn't match, `customer:dismiss()` +
  `day_state:record_dismiss()`; (4) else forward to the main `Grid`'s
  mouse methods. Wire a `love.keypressed(key)` case for `"r"` that calls
  `manager.current:rotate_dragged()` (thin forward to the main grid or open
  panel's grid, whichever currently has an active drag) alongside the
  existing `"escape"` quit handler — don't remove that one.
  Add/adjust a headless test exercising the full loop: place is skipped (grid
  already covers that) but add one `tests/test_kitchen_scene.lua` that ticks
  a fresh `KitchenScene`, drives a serve through direct method calls (not
  real mouse events — call `scene:mouse_pressed/released` with computed
  coordinates), and asserts `day_state.currency` increased and
  `customers_served` incremented.

---

### Verification (Phase 4, not a checklist task — see design doc "Tests" section)

- All headless tests green (`love . --headless`)
- Every box above checked
- `README.md` updated to mention the new scene / how to play
- This checklist archived to `docs/archive/cooking-inventory-game.md`,
  design doc archived to `docs/archive/design/cooking-inventory-game.md`
