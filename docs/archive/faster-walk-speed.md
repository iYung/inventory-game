## Faster Walk Speed Checklist

- [x] Task A — `lua/game/config.lua` — add `config.WALK_SPEED = 160` constant
- [x] Task B — `lua/game/customer_queue.lua` — replace all three `walk_speed = 80` literals with `config.WALK_SPEED` (in `make_restock_cfg`, `make_program_cfg`, `make_order_cfg`)
