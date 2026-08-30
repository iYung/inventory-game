## Goal

Add a second kind of stage visitor: a **merchant**. Unlike a food customer,
a merchant doesn't request an item — clicking them opens a panel showing
their stock, and the player drags items out of it into their own floor
grid. Buying/payment is explicitly out of scope for this pass (items are
free to take).

## Affected files

- `lua/game/customer.lua` — gains a `kind` field (`"order"` default vs
  `"merchant"`), a `panel` field (their stock `Grid`, merchant-only), and a
  `type_id` field (`"merchant"`, used to look up display info)
- `lua/game/data/item_defs.lua` — new `merchant` entry (name only, used by
  `ItemPanel`'s title bar — never placed on a `Grid` via `Item.new`)
- `lua/game/item_panel.lua` — gains a "Leave" button, shown only when the
  wrapped thing is merchant-kind
- `lua/game/customer_queue.lua` — a day's queue now mixes one merchant
  config in among the food-order configs
- `lua/game/config.lua` — merchant stock panel dimensions
- `game/scenes/kitchen_scene.lua` — click-to-open-panel for a merchant
  (instead of dialogue-advance), skip serve/dismiss-on-drop for merchants,
  handle the Leave button
- `main.lua` — seed `math.random` once at startup (first use of randomness
  in this codebase)

## What changes

### Why this reuses almost everything already built

The existing `ItemPanel` (built for the microwave) is already generic: it
wraps *any* object exposing `.panel` (a `Grid`), `.type_id` (for its title
and def lookup), and optionally `.action_state`/`def.actions`. It doesn't
care whether that object is an `Item` sitting on the floor grid or
something else entirely. Likewise `KitchenScene`'s cross-grid drag/transfer
logic (`transfer_drag`, the "draw whichever item is dragged on top" logic,
`rotate_dragged`) only ever touches `self.panel.item.panel` — a `Grid` —
and never assumes it came from an `Item`.

So a merchant's stock panel doesn't need any new panel/grid/drag machinery
at all: `Customer` just needs to grow the same three fields (`panel`,
`type_id`, plus `kind` to distinguish it), and `ItemPanel.new(self.customer)`
works as-is. The only genuinely new UI piece is the "Leave" button (a
merchant has no `def.actions` to click, but does need an explicit way to
end the visit per your answer).

### `lua/game/customer.lua`

- `Customer.new(...)`: add `self.kind = "order"`, `self.panel = nil`,
  `self.type_id = nil` (both only populated for merchants, in `show()`).
- `Customer:show(cfg)`: read `cfg.kind` (defaults to `"order"` if absent, so
  every existing call site/config keeps working unchanged). When
  `cfg.kind == "merchant"`:
  - `self.type_id = "merchant"`
  - `self.panel = Grid.new(config.MERCHANT_PANEL_COLS, config.MERCHANT_PANEL_ROWS, config.U, 0, 0)`
    (origin doesn't matter — `ItemPanel` repositions it on open, exactly like
    it already does for an `Item`'s container panel)
  - Populate that grid with `Item.new(type_id)` for each entry in
    `cfg.stock` (a list of item type-id strings), first-fit placed
  - `requested_type` stays `nil` — nothing can be dropped "on" a merchant to
    serve them, there's no order to fulfill
  - `after_messages` stays empty — a merchant has no "thank you" line;
    `messages` can still hold a one-line greeting, shown once they arrive,
    using the dialogue system completely unchanged
  - When not a merchant, `self.panel`/`self.type_id` stay `nil`, matching
    today's behavior exactly

No changes to the state machine, movement, bubble, or dialogue-advance
logic — a merchant walks in/waits/walks out exactly like a food customer.

### `lua/game/data/item_defs.lua`

Add:
```lua
merchant = { name = "Merchant" }
```
Just enough for `ItemPanel`'s `self.def = item_defs[item.type_id]` /
title-bar text lookup. No `footprint`/`has_panel`/`actions` — a merchant is
never wrapped in `Item.new`, so those fields are never read for it.

### `lua/game/item_panel.lua`

- `ItemPanel.new(item)`: if `item.kind == "merchant"`, lay out one more
  button — "Leave" — in the same button row as any `def.actions` (there are
  none for a merchant, so it's the only button). Styled distinctly (a
  red/warning color, like the existing close button) so it doesn't read as
  a cook-style action.
- `ItemPanel:mouse_pressed`: clicking "Leave" sets both `self.should_close`
  (existing flag — hides the panel) and a new `self.should_leave` flag.
  `KitchenScene` is what actually acts on `should_leave` (see below) —
  `ItemPanel` itself has no idea what "leaving" means for a merchant.
- The existing close (X) button is untouched and still works for a
  merchant's panel — it just hides the panel UI without ending the visit
  (so you can back out, drag more items around, and click the merchant
  again to reopen it). "Leave" is the only thing that actually sends them
  away. *(Flagging this as a judgment call in Open Questions below — happy
  to make X also end the visit if you'd rather there be one exit, not two.)*

### `lua/game/customer_queue.lua`

- `CustomerQueue.new(total)` now builds `total` configs where exactly one
  random slot (`math.random(1, total)`) is a merchant config instead of a
  food-order config. Guarantees exactly one merchant per day, every day,
  regardless of `total` — deterministic *count*, random *position* in the
  queue.
- Merchant config: `{ kind = "merchant", name = "Merchant", messages = { "Fresh stock, take a look!" }, stock = { "raw_meat", "raw_meat", "cooked_meat" }, walk_speed = 80 }`.
  Stock contents are a placeholder starting assortment — trivial to change
  later since it's just a list of existing item type ids.

### `lua/game/config.lua`

Add `MERCHANT_PANEL_COLS = 3`, `MERCHANT_PANEL_ROWS = 1` (enough for the
3-item starter stock, 1x1 items).

### `game/scenes/kitchen_scene.lua`

- `mouse_pressed`: when a click lands on the active customer
  (`self.customer:active() and self:_customer_hit(x, y)`), branch on kind
  *before* the existing dialogue-advance logic:
  - merchant, arrived, and no panel already open → open one:
    `self.panel = ItemPanel.new(self.customer)`
  - otherwise (an `"order"` customer, or a merchant whose panel is already
    open and this click is just landing on their body again) → fall
    through to the existing advance()/advance_after() dialogue logic
    unchanged
- `mouse_released`: the serve/dismiss-on-drop branch (dropping a dragged
  item on the customer's body) now also requires
  `self.customer.kind ~= "merchant"` — dropping an item on a merchant is a
  no-op for this pass (no selling), the item just falls through to normal
  grid drop handling (snaps back if there's nowhere valid to land)
- After forwarding a press/release to `self.panel` (same place the existing
  `should_close` check already lives), also check `self.panel.should_leave`:
  if set, call `self.customer:dismiss()` (already does exactly what's
  needed — immediate `walking_out`, no after-message) and
  `self.day_state:record_dismiss()` (merchant visit still counts toward the
  day's served total per your answer, no currency either way — reuses the
  existing method as-is rather than adding a same-behavior alias)

### `main.lua`

Add `math.randomseed(os.time())` in `love.load()` — first thing in this
codebase to use randomness, so it needs seeding for the merchant slot pick
to actually vary run to run. Guarded so headless tests (which construct
`CustomerQueue` directly, not through `love.load()`) aren't affected either
way.

### Tests

- `test_customer_queue.lua`-equivalent coverage (currently inside
  `test_day_loop.lua`): a day's queue of N always contains exactly one
  merchant config among N-1 order configs, regardless of N
- `test_customer.lua`: `show()` with `cfg.kind == "merchant"` populates
  `panel`/`type_id` and the stock items; a default/omitted `kind` still
  behaves exactly as today (regression guard)
- `test_item_panel.lua`: Leave button only appears for merchant-kind items;
  clicking it sets `should_leave`; a non-merchant panel (the microwave) has
  no Leave button at all
- `test_kitchen_scene.lua`: full flow — force-spawn a merchant, click opens
  their panel, drag a stock item onto the main floor grid, click Leave,
  merchant walks out, `customers_served` increments with no currency change

## What stays the same

- `lua/game/grid.lua`, `lua/game/item.lua` — completely untouched, no new
  concepts needed there
- Every food-customer code path (drag-to-serve, dismiss-on-mismatch,
  dialogue advance, day/Next-Day loop) — unchanged for `kind == "order"`
- `DayState` — untouched, `record_dismiss()` reused as-is for a merchant
  leaving

## Open questions

1. **Does the plain X close button also end a merchant's visit**, or does
   it just hide the panel (current proposal) while "Leave" is the only real
   exit? Proposal above keeps them distinct (X = peek away, Leave = done).
2. **Stock contents** (`raw_meat, raw_meat, cooked_meat`) and panel size
   (3x1) are placeholder guesses, not load-bearing — easy to tune later.
3. **Merchant greeting message** is a single placeholder line; there's no
   "thank you"/after-message concept for them at all in this design (no
   after_messages, since nothing was "delivered"). Confirm that's fine for
   now.
4. Confirmed from your answers: merchant replaces one random slot per day
   (not a separate always-on character, not always-first); stock is fixed
   per visit with an explicit Leave button (not click-away-to-dismiss).
