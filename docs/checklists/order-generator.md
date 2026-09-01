## Order Generator & Merchant System Checklist

Tasks are ordered by dependency — each one builds on the last.

---

### Data layer

- [x] Task 01 — `lua/game/data/program_defs.lua` — Create the file. Define all 11 programs as a keyed table. Each entry has: `id`, `name`, `cost`, `machines` (type_ids; all must reach floor to complete program), `extras` (type_ids shown in merchant panel at $5 flat, don't count toward completion), `inputs` (ingredient type_ids used by RestockGen), `tags_unlocked`, `requires`. `stock` field is unused.

- [x] Task 02 — `lua/game/program_state.lua` — Create `ProgramState` class. `ProgramState.new(starting_id)` marks one program as owned from the start. Methods: `owns(id) → bool`, `buy(id)` (marks owned, caller deducts currency), `available_tags() → set` (union of `tags_unlocked` across owned programs, keyed `tag → true`), `available_outputs() → list` (all `type_id`s producible from owned machines — read `produces` keys from `item_defs` actions and `overnight_actions` on owned machine type_ids). No dependency on generators yet.

---

> **PR checkpoint 1** — after Tasks 01–02. Data definitions and program state in place, fully testable in isolation before any generator or UI work.

---

### Generators

- [x] Task 03 — `lua/game/restock_gen.lua` — Create `RestockGen`. Single function: `RestockGen.stock(program_state) → list of {type_id, quantity}`. Implementation: collect the union of `inputs` from all owned programs (from `program_defs`), randomly pick up to 5 distinct type_ids from that pool, assign each a random quantity (1–4). Returns the list. If pool has fewer than 5 items, take all.

- [x] Task 04 — `lua/game/merchant_gen.lua` — Create `MerchantGen`. Single function: `MerchantGen.offer(program_state) → list of program def tables`. Step 1: collect programs not yet owned whose `requires` are all satisfied — pick 1–2 randomly. Step 2: collect already-owned programs — pick enough to fill up to 3 total slots. Returns the combined list (1–3 entries).

- [x] Task 05 — `lua/game/order_gen.lua` — Create `OrderGen`. Single function: `OrderGen.generate(day, program_state) → order config table`. Implement item-count scaling (1–2 / 1–4 / 1–5 by day range), rule-count scaling (1–2 / 1–4), weighted rule-kind pool, rule generation loop (at_least / no_more / no / specific / all_unique), post-generation satisfiability validation (drop last rule and retry once if unsatisfiable). Returns `{ order_rules, order_item_count, payout }`. Payout = `item_count × 10 + (rule_count - 1) × 5`.

---

> **PR checkpoint 2** — after Tasks 03–05. All three generators done and independently testable. No game code changed yet — safe to review generator logic before wiring anything up.

---

### State

- [x] Task 06 — `lua/game/day_state.lua` — Update `record_serve` signature to `record_serve(items, payout)`: `items` is a list of type_id strings (increments `sold_items` for each), `payout` is the integer to add to `currency` (replaces the hardcoded `+10`). No other changes.

---

### Config & queue

- [x] Task 07 — `lua/game/config.lua` — Update `ORDER_PANEL_COLS = 4`, `ORDER_PANEL_ROWS = 4`. Update `MERCHANT_PANEL_COLS = 6`, `MERCHANT_PANEL_ROWS = 4`. Remove `CUSTOMERS_PER_DAY` fixed constant (now computed per-day in the queue).

- [x] Task 08 — `lua/game/customer_queue.lua` — Rework `CustomerQueue.new(day, program_state)` (remove `total` param; compute total as `math.random(4, 6)` internally). Build slot list: always include one restock merchant slot (random position) using `RestockGen.stock`; on even days also include one program merchant slot (different random position) using `MerchantGen.offer`; fill remaining slots with `OrderGen.generate`. Remove `assign_traits`, `make_default_cfg`, and `make_merchant_cfg`. Add `make_restock_cfg(program_state)` and `make_program_cfg(program_state)`. Expose `self.total` so callers can pass it to `DayState:start_day`.

---

### Customer model

- [x] Task 09 — `lua/game/customer.lua` — In `Customer:show(cfg)`: remove `loved_tags`, `liked_tags`, `disliked_tags`. Add `self.order_rules = cfg.order_rules or {}` and `self.order_item_count = cfg.order_item_count or 1`. Add support for `cfg.kind = "restock"` (same panel mechanic as current merchant but uses restock stock list) and `cfg.kind = "program"` (new — panel will be handled in Task 11). The `type_id` for restock kind is `"merchant"`, for program kind is `"merchant"` (reuses existing icon). Customer data model only — no rendering changes here.

---

> **PR checkpoint 3** — after Tasks 06–09. State, config, queue, and customer model all updated. Game runs with the new data flow but UI still renders the old way — a good integration point before any panel work.

---

### UI — order panel

- [x] Task 10 — `game/scenes/kitchen_scene.lua` — Update the order panel to 4×4. Above the grid, render the rule list: one row per rule showing a human-readable description and a live green/red indicator. Recalculate pass/fail for all rules on every drag event. `no_more` rule shows amber when at the limit, red when exceeded. Display the order's payout amount. Update Serve button logic: enable only when all rules pass AND panel has ≥ 1 item. Update the serve call: pass `items` (list of type_ids in panel) and `payout` (from order config) to `DayState:record_serve`. Remove all `loved_tags`/`liked_tags`/`disliked_tags` rendering.

---

### UI — merchant panels

- [x] Task 11 — `game/scenes/kitchen_scene.lua` — Implement the restock merchant panel (kind = "restock"): render the 6×4 grid stocked from `RestockGen` output. Show per-item cost label on each cell. On drag-to-floor: check `day_state.currency >= item_cost`; if yes deduct and place; if no reject with a visual shake/dim. "Leave" closes as before.

- [x] Task 12 — `game/scenes/kitchen_scene.lua` + `lua/game/customer.lua` + `lua/game/item_panel.lua` — Program merchant panel: shows each program's `machines` + `extras` in a shared row (no section headers visible to player). Machines tagged `program_id`; extras tagged `is_extra`. Cost charged on first machine drag; all machines placed → `program_state:buy`. Extras cost $5 flat per drag. Panel col-advances by item footprint width; shrinks to fit content. Restock merchant always slot 1; program merchant on even days.

---

### Starting layout

- [x] Task 13 — `game/scenes/kitchen_scene.lua` — Update the starting layout to only place the `fryer` program's machines (remove pump, microwave, coffee machine, container, and other non-fryer machines from the initial grid). Place fryer + its starter stock. `ProgramState.new("fryer")` is constructed here and passed to `CustomerQueue` and order panel logic.

---

> **PR checkpoint 4** — after Tasks 10–13. Full feature playable end-to-end: new order panel with rules, both merchant types, and the fryer-only starting layout. Final PR after tests pass.

---

### Tests

- [x] Task 14 — `tests/test_program_state.lua` — Tests for `ProgramState`: starts with one program owned, `owns()` returns correct values, `buy()` marks owned, `available_tags()` returns union across owned programs, prerequisite graph not yet tested here (that's MerchantGen's job).

- [x] Task 15 — `tests/test_restock_gen.lua` — Tests for `RestockGen.stock`: returns ≤ 5 items, all returned type_ids are in the inputs pool of owned programs, quantities are in [1,4].

- [x] Task 16 — `tests/test_merchant_gen.lua` — Tests for `MerchantGen.offer`: returns 2–4 entries, new-program entries all have prerequisites satisfied and are not yet owned, repurchase entries are all owned, total ≤ 4.

- [x] Task 17 — `tests/test_order_gen.lua` — Tests for `OrderGen.generate`: item count within correct range for given day, rule count within range, no rule references a tag outside `available_tags`, generated order is satisfiable (a valid item combination exists), payout formula correct.

- [x] Task 18 — `tests/test_customer_queue.lua` — Tests for reworked queue: total is 4–6, always contains exactly one restock merchant, even days contain exactly one program merchant, odd days contain no program merchant, all other slots are order customers.
