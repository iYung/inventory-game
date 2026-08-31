## Chicken & Coop Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add five new item definitions:
  `chicken` (1×1, brownish color), `egg` (1×1, pale cream), `coop` (2×2,
  has_panel 2×2, overnight_actions: requires {chicken=1}, produces {egg=1},
  nights=1), `meat_machine` (2×2, has_panel 2×1, actions: "Process" duration
  1.0s, requires {chicken=1}, produces {raw_meat=1}), `incubator` (1×1,
  has_panel 1×1, overnight_actions: requires {egg=1}, produces {chicken=1},
  nights=2). No other files change in this task.

- [x] Task B — `lua/game/item.lua` — Add `Item:overnight_tick()` method and the
  overnight-action engine. Add `self.overnight_state = {}` initialisation in
  `Item.new`. In `overnight_tick()`: iterate `def.overnight_actions`; if panel
  requirements are met, increment `self.overnight_state[i].nights_elapsed`
  (initialise to 0 if nil); if not met, reset to 0; when nights_elapsed >=
  nights, consume requires from panel (use existing `remove_matching`), produce
  produces into panel (use existing `place_first_fit`), reset counter. Depends
  on Task A being complete first.

- [x] Task C — `game/scenes/kitchen_scene.lua` (starting layout only) — Add a
  coop, meat_machine, incubator, and a few chickens to `on_enter`. Choose
  cells clear of all existing items (microwave 0,0–1,1; meat 2,0–4,0;
  broccoli 2,1–3,1; fryer 6,0–7,1; pot 8,0–9,0; potatoes 2,2–3,2; broccoli_garden
  0,3–1,4; onion_garden 4,2–5,3). Suggested: coop at (0,5), meat_machine at
  (2,5), incubator at (4,5), two chickens on the floor at (6,5) and (7,5).
  Depends on Task A being complete first.

- [x] Task D — `game/scenes/kitchen_scene.lua` (day advance wiring) — In the
  summary "Continue" handler inside `mouse_pressed`, after the existing
  `refill_daily` loop, add a second loop calling `item:overnight_tick()` on
  every floor item. Depends on Task B being complete first.

- [x] Task E — `tests/test_item.lua` (or new `tests/test_overnight.lua`) — Add
  tests: (1) coop with a chicken produces an egg after one overnight_tick;
  (2) incubator with an egg produces a chicken only after two overnight_ticks,
  not one; (3) incubator resets progress if the egg is removed between ticks
  (panel emptied, tick called, egg re-added, tick called — chicken does NOT
  appear); (4) meat_machine "Process" action consumes chicken and produces
  raw_meat. Depends on Tasks A and B being complete first.
