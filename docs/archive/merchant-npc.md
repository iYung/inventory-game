## Merchant NPC Checklist

Design doc: `docs/design/merchant-npc.md`.

### Decisions from review (proceeding with the doc's proposals)

- The plain **X** close button just hides the panel; **Leave** is the only
  thing that ends a merchant's visit.
- Placeholder stock `{"raw_meat", "raw_meat", "cooked_meat"}`, panel size
  3x1 — not load-bearing.
- No after-messages for merchants, just a one-line greeting.
- Exactly one random slot per day's queue is a merchant (position random,
  count always exactly 1).

### Shared contracts (read before starting — the real files, once they
exist, are authoritative if anything here turns out ambiguous)

**`Customer` additions** (`lua/game/customer.lua`): `self.kind` (`"order"`
default, `"merchant"`), `self.panel` (nil unless merchant — a `Grid` sized
`config.MERCHANT_PANEL_COLS x config.MERCHANT_PANEL_ROWS`, cell size
`config.U`, populated via first-fit `Item.new(type_id)` placement from
`cfg.stock`, a list of item type-id strings), `self.type_id` (nil unless
merchant — `"merchant"`, used by `ItemPanel` for its def/title lookup).
`Customer:show(cfg)` reads `cfg.kind` (default `"order"` — every existing
call site that omits it must keep behaving exactly as today).

**`CustomerQueue`**: `CustomerQueue.new(total)` builds `total` configs; a
`math.random(1, total)` pick determines which single slot is
`{ kind = "merchant", name = "Merchant", messages = { "Fresh stock, take a look!" }, stock = { "raw_meat", "raw_meat", "cooked_meat" }, walk_speed = 80 }`
— every other slot is the existing default order config, unchanged.

**`ItemPanel` Leave button**: when `item.kind == "merchant"`, lay out one
extra button ("Leave") in the button row (alongside any `def.actions` —
none for a merchant, so it's the only one), styled distinctly (e.g. a
red/warning color like the close button, not the normal green action
color). Clicking it sets `self.should_close = true` (existing flag) AND a
new `self.should_leave = true` flag. `ItemPanel` itself does nothing else
with `should_leave` — it's `KitchenScene`'s job to act on it.

**`item_defs.merchant`**: `{ name = "Merchant" }` — nothing else, never
placed via `Item.new`.

**`config.lua`**: add `MERCHANT_PANEL_COLS = 3`, `MERCHANT_PANEL_ROWS = 1`.

Tasks are grouped into waves; within a wave, tasks run in parallel against
the contracts above (not against each other's real files). Don't start a
wave until the previous one is fully checked off.

---

#### Wave 0 (done up front by the orchestrating session, not a task)

- [x] `lua/game/config.lua` — add `MERCHANT_PANEL_COLS`/`MERCHANT_PANEL_ROWS`
- [x] `lua/game/data/item_defs.lua` — add the `merchant` entry

---

#### Wave 1 (parallel)

- [x] Task A — `lua/game/customer.lua`, `tests/test_customer.lua` —
  implement the `kind`/`panel`/`type_id` additions to `Customer` per the
  contract above. Test: `show()` with `cfg.kind == "merchant"` populates
  `panel` (a `Grid` of the right size, containing the right stock items,
  first-fit placed) and `type_id == "merchant"`; `show()` with `kind`
  omitted (every existing test config) leaves `panel`/`type_id` nil and
  behaves exactly as before (regression guard — existing tests in this file
  must keep passing unmodified in spirit, even if you need to touch them to
  add the new coverage alongside).
- [x] Task B — `lua/game/customer_queue.lua`, its test coverage inside
  `tests/test_day_loop.lua` — implement the random-merchant-slot mixing per
  the contract above. Test: for several values of `total` (e.g. 1, 3, 5),
  building a `CustomerQueue` and draining it via `next()` yields exactly one
  config with `kind == "merchant"` and the rest with `kind == "order"` (or
  no `kind` field / default — check what Task A's `Customer:show` actually
  treats as the default and make sure your "order" configs match, e.g. by
  either setting `kind = "order"` explicitly or omitting it, whichever the
  existing `make_default_cfg()` does — don't gratuitously change existing
  order-config shape). Since the slot is random, don't assert *which* index
  is the merchant — assert the count and that repeated runs aren't always
  the same index (or just assert the count invariant across multiple `total`
  values, that's sufficient).
- [x] Task C — `lua/game/item_panel.lua`, its test coverage inside
  `tests/test_item_panel.lua` — implement the Leave button per the contract
  above. Since `Customer` may not exist with the new fields yet when you
  start (parallel task), build a small fake table in your own tests with
  `.kind = "merchant"`, `.panel = Grid.new(...)`, `.type_id = "merchant"`
  (real `Grid` — that already exists; you do NOT need the real `Customer`).
  Test: a merchant-kind item's panel has a "Leave" button; clicking it sets
  `should_close` and `should_leave` both true; a non-merchant item's panel
  (the existing microwave test setup) has no Leave button at all
  (`panel.buttons` — or wherever you store it — has no `"Leave"` entry, and
  clicking where it would be does nothing).

#### Wave 2 (sequential, after Wave 1 is fully checked off — integration)

- [x] Task D — `game/scenes/kitchen_scene.lua`, `main.lua`,
  `tests/test_kitchen_scene.lua` — wire it all together per the design
  doc's `game/scenes/kitchen_scene.lua` and `main.lua` sections. Read the
  real `Customer`/`CustomerQueue`/`ItemPanel` files Wave 1 produced first —
  they're authoritative over this checklist's contract summary if anything
  differs. Specifically: `mouse_pressed` branches merchant-click (arrived,
  no panel already open) to `self.panel = ItemPanel.new(self.customer)`
  instead of the dialogue-advance path; `mouse_released`'s
  serve/dismiss-on-drop branch additionally requires
  `self.customer.kind ~= "merchant"`; after forwarding a press/release to
  an open panel, also check `self.panel.should_leave` — if set, call
  `self.customer:dismiss()` and `self.day_state:record_dismiss()` (in
  addition to whatever `should_close` handling already exists). Add
  `math.randomseed(os.time())` to `main.lua`'s `love.load()`. Add a test
  exercising a full merchant visit: since the queue's merchant slot is
  random, either force it deterministically for the test (e.g. construct
  the scene, then directly overwrite `scene.queue` with a
  `CustomerQueue`-shaped table you control, or poke `scene.customer:show()`
  with a merchant cfg directly — your call on whichever is less brittle
  given the real files) and drive: click opens the panel, drag a stock item
  onto the main floor grid (assert it lands there, comes out of the
  merchant's panel), click Leave, customer walks out,
  `day_state.customers_served` increments with currency unchanged.

---

### Verification (Phase 4, not a checklist task)

- All headless tests green (`love . --headless`)
- Every box above checked
- `README.md` updated if it documents game mechanics that now need the
  merchant mentioned (check its current content first — don't add a section
  if the existing README doesn't go into this level of gameplay detail)
- This checklist archived to `docs/archive/merchant-npc.md`, design doc
  archived to `docs/archive/design/merchant-npc.md`
