## Undo Inventory Expansion — Milking & Cheese Checklist

- [ ] Task A — `lua/game/config.lua` — revert `GRID_ROWS` from 12 back to 9
- [ ] Task B — `game/scenes/kitchen_scene.lua` — remove the two `can_place` + `grid:place` calls for `milking_center` (col 0, row 9) and `cheese_cave` (col 3, row 9); after the existing container placement, add `container.panel:place(Item.new("milking_center"), 0, 0)` and `container.panel:place(Item.new("cheese_cave"), 3, 0)`
