# Customer Order Panel

## Goal

Replace the drag-item-onto-customer gesture for food-order customers with a
click-to-open panel, consistent with how every other interactive thing in the
game (microwave, fryer, dutch oven, merchant stock) already works: click it,
a panel opens with a grid and a button row at the bottom.

Concretely: clicking a waiting order customer opens a panel showing a
reminder of what tag the order wants, a 3x3 grid the player drags candidate
item(s) into, and **Serve** / **Skip** buttons at the bottom.

## Affected files

- `lua/game/customer.lua` — order-kind customers gain a 3x3 `panel` Grid
  and `type_id` (mirrors what merchant-kind customers already have)
- `lua/game/item_panel.lua` — new "order" kind support: reminder text drawn
  between the title bar and grid, `Serve`/`Skip` buttons in place of `Leave`
- `game/scenes/kitchen_scene.lua` — click-to-open-panel for order customers
  (mirrors the existing merchant click handling); Serve/Skip results wired
  into `day_state` + `customer:serve()`/`dismiss()`; the drag-onto-customer
  serve/dismiss block is deleted
- `lua/game/item.lua` — adds a shared `Item.has_tag(item, tag)` helper (today
  duplicated as a local function in `kitchen_scene.lua`, needed by both
  `kitchen_scene.lua` and the new `item_panel.lua` Serve-enablement check)
- `lua/game/config.lua` — adds `ORDER_PANEL_COLS`/`ORDER_PANEL_ROWS` (3x3),
  alongside the existing `MERCHANT_PANEL_COLS`/`ROWS`
- `lua/game/data/item_defs.lua` — adds a non-placeable `order_customer` def
  (`name` only, same pattern as the existing `merchant` def) so `ItemPanel`
  has something to look up for the title bar
- `tests/test_kitchen_scene.lua` — the two drag-onto-customer serve/dismiss
  tests become click-to-open + Serve/Skip button tests

## What changes

- Order customers get a `panel` Grid (3x3), created in `Customer:show()`,
  the same way merchant customers already get theirs (just a different size)
- Clicking a waiting order customer whose greeting message has finished
  revealing opens/focuses their order panel (identical mechanism to the
  existing merchant-click-opens-panel case; while the greeting is still
  typewriter-revealing, a click still just advances/skips it, same as today)
- The order panel shows:
  - Title bar: "Customer"
  - Reminder text: what tag the order is asking for (e.g. `Order: Protein`)
  - A 3x3 grid
  - `Serve` and `Skip` buttons on the bottom row
- Player drags the candidate item (from the floor grid or another open
  panel) into the grid, same drag mechanics as dropping into the microwave
  or merchant stock panel
- **Serve**: enabled only when the grid holds *exactly one* item and that
  item carries the requested tag (same greyed-out-when-disabled treatment as
  the microwave's Cook button — any other combination, including one right
  item plus a second item of any kind, leaves it disabled). Clicking it
  consumes that item, calls `customer:serve()`, records the serve in
  `day_state`, and closes the panel.
- **Skip**: always enabled. Clicking it returns any item(s) currently in the
  grid to the floor grid (first-fit placement each), calls
  `customer:dismiss()` with a new "skip" message distinct from the existing
  wrong-item message, records the dismiss, and closes the panel.
- Dragging an item directly onto the customer's sprite body no longer does
  anything special — that gesture is removed. A drop there just fails to
  place (same as dropping on any other non-grid area) and the item snaps
  back to where it was picked up.
- Merchant customers are untouched: still open on click the same way, still
  use stock grid + `Leave`.

## What stays the same

- Greeting/after-message typewriter bubble, and click-to-advance/skip-reveal
  while a message is still being revealed
- `talking_after` / `after_messages` flow after a successful serve
- `Customer:dismiss(message)` mechanism itself (only a new call site — the
  Skip button — and a new message string are added; the existing wrong-item
  message path is simply unreachable now since Serve stays disabled whenever
  the grid doesn't hold exactly one matching item)
- `DayState:record_serve` / `record_dismiss` semantics
- `CustomerQueue` config generation (tags, greeting messages)
- Merchant stock panel and `Leave` button behavior, including its
  should_close/should_leave flags

## Open questions

Resolved before writing this doc:

- **Item selection inside the panel** — a grid in the panel (drag the item
  in, then click Serve), not a still-drag-onto-customer or
  serve-whatever's-currently-held approach.
- **Panel grid size** — 3x3 (not a single 1x1 slot), matching the visual
  weight of the other item panels.
- **Serve with multiple items in the grid** — disabled unless the grid
  holds exactly one item and it matches the requested tag, rather than
  serving/consuming whichever items happen to be sitting in a larger grid.
- **Skip behavior** — dismiss with a distinct "skipped" message (not silent
  like the merchant's Leave), and any item(s) sitting in the grid are
  returned to the main floor inventory rather than being consumed.
