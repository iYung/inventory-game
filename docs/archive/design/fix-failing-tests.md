## Goal

Fix all failing headless tests so the full suite passes under `luajit`.

## Affected files

- `lua/headless/stubs.lua` — must define `love = love or {}` before populating it
- `lua/game/merchant_gen.lua` — wrong MIN_NEW/MAX_NEW/MAX_SLOTS constants
- `tests/test_item.lua` — missing stubs require
- `tests/test_item_panel.lua` — missing stubs require
- `tests/test_customer.lua` — missing stubs require
- `tests/test_overnight.lua` — missing stubs require
- `tests/test_basics.lua` — missing stubs require
- `tests/test_kitchen_scene.lua` — missing stubs require
- `tests/test_same_panel_nested_drop.lua` — missing stubs require

## What changes

### Group A — `love` global nil in headless luajit

When tests run via `luajit tests/test_foo.lua` directly, there is no LÖVE2D
runtime and no `love` global. `stubs.lua` exists to provide a mock `love`
table but it currently does `love.graphics = ...` which crashes when `love`
is nil.

Fix:
1. Add `love = love or {}` at the top of `stubs.lua`.
2. Add `require("lua/headless/stubs")` as the **first** line of every test
   that transitively calls any `love.*` API (the seven tests listed above).

### Group B — merchant_gen constants off-by-one

`merchant_gen.lua` documents "Step 1: 2-3 randomly chosen programs" but
sets `MIN_NEW = 1, MAX_NEW = 2, MAX_SLOTS = 3`. `test_merchant_gen.lua`
asserts `min_new >= 2` and total offer in `[2, 4]`.

Fix: change constants to `MIN_NEW = 2`, `MAX_NEW = 3`, `MAX_SLOTS = 4`.
This makes the code match both its own comment and the test expectation.

## What stays the same

- `stubs.lua` mock behavior is unchanged; adding `love = love or {}` only
  makes it safe to run outside LÖVE2D — within LÖVE2D, `love` is already a
  table and the assignment is a no-op.
- No test logic is changed; only the missing `require` lines are added.
- merchant_gen offer shape is otherwise unchanged (shuffle, dedup, etc.).

## Open questions

None — root causes confirmed by reading source and running the suite.
