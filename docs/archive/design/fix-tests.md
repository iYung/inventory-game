## Goal

Fix the one failing test in the suite. `tests/test_day_loop.lua:13` asserts `q1.total >= 4 and q1.total <= 6` for day 1, but the implementation (`lua/game/customer_queue.lua`) generates `lo=3, hi=3` for days 1–4, so `total` is always 3. The assertion is wrong.

## Affected files

- `tests/test_day_loop.lua` — stale assertion on line 13

## What changes

Update the day-1 smoke-test assertion in `test_day_loop.lua` to match the actual range `[3, 3]`, consistent with what `test_customer_queue.lua` documents and the implementation produces.

## What stays the same

- `lua/game/customer_queue.lua` — the implementation is correct and matches `test_customer_queue.lua`
- All other test files and game code — unaffected

## Open questions

None. The authoritative range is documented in `test_customer_queue.lua` (line 8: `{ day = 1, lo = 3, hi = 3 }`) and matches the implementation.
