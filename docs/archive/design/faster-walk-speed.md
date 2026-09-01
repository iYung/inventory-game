# Faster Walk Speed

## Goal
Make customers and merchants walk to/from the counter faster, reducing dead time between interactions.

## Affected files
- `lua/game/config.lua` — add `WALK_SPEED` constant
- `lua/game/customer_queue.lua` — reference `config.WALK_SPEED` instead of hardcoded `80`

## What changes
- A new `config.WALK_SPEED = 160` constant is added (up from the hardcoded 80 px/sec in use today).
- The three `walk_speed` fields in `customer_queue.lua` (`make_restock_cfg`, `make_program_cfg`, `make_order_cfg`) each change from the literal `80` to `config.WALK_SPEED`.
- `customer.lua` already falls back to `cfg.walk_speed or 80`; the fallback stays as-is since the queue always supplies it.

## What stays the same
- All movement logic in `Customer:update(dt)` is unchanged — it simply consumes `self.speed` at whatever value the config supplies.
- Walk animation parameters (`WALK_STEP_SPEED`, `WALK_BOB_AMPLITUDE`, `WALK_LEG_SWING`) are unchanged.
- No test fixtures hardcode `80`; tests that construct customers pass `walk_speed` directly or leave it nil (uses fallback), so no test changes are needed.

## Open questions
None.
