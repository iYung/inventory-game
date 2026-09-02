## Item Prices Checklist

- [x] Task A — `lua/game/data/item_defs.lua` — Add `buy_price` and `sell_price` fields to item defs. All machine items (fryer, microwave, pump, garden, pot, coop, incubator, meat_machine, barn, milking_center, cheese_cave, coffee_machine, garden_book, microwave_book) get a `buy_price` matching their current `program_defs.cost` (or a sensible value for items that have no program cost). All ingredient/consumable items (raw_chicken, raw_beef, broccoli, potato, water, coffee_bean, onion, egg, chicken, cow, milk, and all cooked outputs) get both `buy_price` and `sell_price`. Sentinel/abstract items (merchant, order_customer, book) get neither.

- [x] Task B — `lua/game/data/program_defs.lua` — Remove the `cost` field from every program entry. Price now lives on each machine item in item_defs.

- [x] Task C — `game/scenes/kitchen_scene.lua` and `lua/game/item_panel.lua` — Replace all `prog.cost` and `config.RESTOCK_ITEM_COST` references with per-item price lookups. Specifically:
  1. `_can_afford_merchant_item` (~line 240): for `restock` kind, use `item_defs[item.type_id].buy_price` (fallback to `config.RESTOCK_ITEM_COST`); for `program` extras, same; for program machines, use `item_defs[item.type_id].buy_price` and drop the `_paid_programs` session-cache check.
  2. The drag-to-floor deduction block (~lines 715–754): charge `item_defs[item.type_id].buy_price` (fallback `config.RESTOCK_ITEM_COST`) per item for restock and extras; for program machines, charge per machine drag (remove the `_paid_programs` first-drag lump-sum logic — each machine is priced individually now). `_machines_placed` tracking for program completion is unchanged.
  3. `item_panel.lua` `ItemPanel.new`: remove `self._paid_programs = {}` (no longer used).
  Depends on Task A.

- [x] Task D — `lua/game/grid.lua` — Add an optional `context` string parameter to `Grid:draw_labels(context)`. After the existing name and tag lines in the tooltip, add a price line: if `context == "merchant"` and `item_defs[item.type_id].buy_price` exists, show `"Buy: $<buy_price>"` in a gold color `{0.95, 0.80, 0.25, 1}`; else if `item_defs[item.type_id].sell_price` exists, show `"Sell: $<sell_price>"` in green `{0.40, 0.90, 0.45, 1}`. Expand `box_h` by `th` for the extra line when a price is shown. Requires `item_defs` to be required at the top of `grid.lua`.

- [x] Task E — `game/scenes/kitchen_scene.lua` — Update the label-drawing loop (~line 840) to pass `"merchant"` context when the grid belongs to a merchant-kind customer. The customer panel grid is `self.customer.panel`; pass `"merchant"` when `self.customer.kind == "restock"` or `self.customer.kind == "program"` or `self.customer.kind == "merchant"`. All other grids pass no context (nil). Depends on Task D.
