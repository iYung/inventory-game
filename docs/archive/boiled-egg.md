## Boiled Egg Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `boiled_egg` item definition
  (1×1 footprint, color ~(0.95, 0.90, 0.75, 1), tags = {"Protein"}) and add a
  new container recipe to the microwave's Cook action:
  `{ container = "pot", requires = { water = 1, egg = 1 }, produces = { boiled_egg = 1 } }`.
  Follow the exact same pattern as the existing soup/onion_soup container recipes.
  No other files change in this task.

- [x] Task B — `tests/test_overnight.lua` or new `tests/test_boiled_egg.lua` —
  Add a test: place water and egg into a pot's panel, place the pot into the
  microwave's panel, call `microwave:start_action("Cook")`, call
  `microwave:update(3.0)`, assert the pot's panel contains a boiled_egg. Follow
  the same pattern as existing action tests in the test suite. Run the tests to
  confirm they pass.
