## Coffee Machine Starting Layout Checklist

- [x] Task A — `game/scenes/kitchen_scene.lua` — In `on_enter`, after the container is placed at `(0,3)`, place a `coffee_machine` (2×2) at `(4,2)` with an `assert(can_place)` guard, matching the pattern used for every other appliance.
- [x] Task B — `game/scenes/kitchen_scene.lua` — After placing the coffee machine, pre-stock the container's panel with two `roasted_coffee_bean` items at `(0,0)` and `(1,0)` using `container.panel:place(Item.new("roasted_coffee_bean"), col, row)`, matching how the barn is pre-stocked with cows.
