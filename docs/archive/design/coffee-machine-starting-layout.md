## Goal
Add a `coffee_machine` appliance to the main floor grid and pre-stock the container with `roasted_coffee_bean` items so the coffee-making workflow is accessible from the moment the game starts.

## Affected files
- `game/scenes/kitchen_scene.lua` — `on_enter` starting layout

## What changes
- **Coffee machine on the floor grid**: Place one `coffee_machine` (2×2 footprint) at cell `(4, 2)`–`(5, 3)`. This spot is currently unoccupied: potatoes sit at `(2,2)` and `(3,2)`, the container at `(0,3)`–`(1,4)`, and the coop at `(2,4)`–`(3,5)` — so `(4,2)`, `(5,2)`, `(4,3)`, `(5,3)` are all free.
- **Roasted coffee beans in the container**: Pre-place two `roasted_coffee_bean` items inside the container's 6×6 panel (at `(0,0)` and `(1,0)`) so the player can immediately pull them out to brew coffee.

## What stays the same
- All existing starting items (microwave, fryer, pot, pump, potatoes, broccoli, raw chicken, container, coop, incubator, cow, meat_machine, chickens, barn, gardens) remain at their current positions.
- `item_defs.lua` is not touched — both `coffee_machine` and `roasted_coffee_bean` are already defined there.
- No test files need updating unless the test suite explicitly checks that certain cells are free.

## Open questions
None — cell availability was confirmed by cross-referencing the `on_enter` placement list.
