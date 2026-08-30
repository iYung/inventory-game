## Cow & Beef Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Make all data changes:
  (1) Add `cow` def (2×2 footprint {0,0},{1,0},{0,1},{1,1}, color ~{0.45,0.28,0.15,1}).
  (2) Add `raw_beef` def (1×1, color ~{0.65,0.15,0.15,1}).
  (3) Add `steak` def (1×1, color ~{0.55,0.25,0.12,1}, tags={"Protein"}).
  (4) Update `meat_machine`: footprint → 3×2 ({0,0},{1,0},{2,0},{0,1},{1,1},{2,1}),
  panel_cols=2, panel_rows=2.
  (5) Update meat_machine Process recipes: `chicken → raw_chicken` quantity to
  `produces={raw_chicken=2}`; add `{requires={cow=1}, produces={raw_beef=4}}`.
  (6) Add microwave Cook flat recipe `{requires={raw_beef=1}, produces={steak=1}}`.
  (7) Add microwave Cook pot recipe
  `{container="pot", requires={water=1,potato=1,raw_beef=1}, produces={beef_stew=1}}`.
  (8) Rename `soup` key → `chicken_soup`, name → "Chicken Soup"; update the
  `produces={soup=1}` reference in the microwave pot recipe to `{chicken_soup=1}`.
  No other files change in this task.

- [x] Task B — `game/scenes/kitchen_scene.lua` — Update meat_machine starting
  placement: the footprint is now 3×2 so verify the anchor cell (currently (2,5))
  still fits and doesn't overlap any other item (coop is at (0,4)–(1,5), incubator
  at (4,5), chickens at (6,5)/(7,5)). Adjust the anchor if needed. Also add one
  cow item somewhere on the starting floor (free cell, near the meat machine).
  Depends on Task A.

- [x] Task C — `tests/test_item.lua` and `tests/test_overnight.lua` —
  In `test_item.lua`: rename `"soup"` → `"chicken_soup"` in the one container-recipe
  test (type_id string and comment). In `tests/test_overnight.lua`: update the
  meat_machine test (Test 5) to assert 2 raw_chicken produced (not 1), matching
  the updated `chicken → 2× raw_chicken` recipe. Depends on Task A.
