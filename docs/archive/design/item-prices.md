# Item Buy/Sell Prices

## Goal

Replace per-merchant and per-customer price logic with per-item `buy_price` and `sell_price` fields defined in `item_defs.lua`. Show the relevant price in the hover tooltip: `buy_price` when hovering an item inside a merchant panel, `sell_price` everywhere else (floor grid, order panel, container panels).

## Affected files

- `lua/game/data/item_defs.lua` — add `buy_price` and `sell_price` to consumable/ingredient item entries
- `lua/game/grid.lua` — `draw_labels()` gains an optional `context` param (`"merchant"` or nil) to show the right price line
- `lua/game/item_panel.lua` — pass `"merchant"` context to the inner grid's `draw_labels()` call when the panel belongs to a merchant-kind customer
- `game/scenes/kitchen_scene.lua` — pass context through to the grid/panel draw_labels calls on the floor grid and other panels

## What changes

### 1. `item_defs.lua`
Add two optional number fields to every item that has a price:
```lua
buy_price  = 5,   -- what the player pays to acquire it from a merchant
sell_price = 8,   -- what the player earns when serving/selling it
```

**All items own their prices** — this includes machines. Machine items (fryer, microwave, pump, etc.) get a `buy_price` that replaces the `cost` field currently living in `program_defs.lua`. Ingredient/consumable items (raw_chicken, potato, etc.) get both fields. Sentinel items (`merchant`, `order_customer`, `book`) get neither.

`program_defs.lua` loses its `cost` field; any code that reads `def.cost` for purchase pricing must instead read the `buy_price` off the machine item's def in `item_defs`.

The existing `config.RESTOCK_ITEM_COST = 5` flat rate is replaced by each item's own `buy_price`; items without one fall back to that constant so nothing breaks during migration.

### 2. `grid.lua` — `draw_labels(context)`
`Grid:draw_labels()` currently shows `item.label` (name) and `item.tags`. Add a third optional line for price:
- If `context == "merchant"` and the hovered item's def has `buy_price`, show `"$<buy_price>"` in a distinct color (e.g. gold).
- Otherwise, if the def has `sell_price`, show `"$<sell_price>"` in green.
- If neither applies, show nothing (same as today).

`draw_labels` already receives the item from the grid's `_hover_col/_hover_row` — no structural change needed, just an extra optional parameter threaded through.

### 3. `item_panel.lua` — merchant context
`ItemPanel:draw()` calls `self.item.panel:draw(skip_dragging)` but does NOT call `draw_labels` itself — that's called at the scene level. The scene already knows which panel is open and its kind. The fix is in the scene, not item_panel.

However, `ItemPanel` exposes `self.item.kind` which the scene can read. No change needed to `item_panel.lua` itself.

### 4. `kitchen_scene.lua` — threading context
The scene calls `grid:draw_labels()` (and the equivalent on open panels' inner grids) at the end of its draw pass. It must:
- Check if the cursor is currently hovering over a merchant-kind panel's inner grid.
- Pass `"merchant"` to `draw_labels()` in that case; pass `nil` (default) otherwise.

## What stays the same

- `program_defs.lua` structure is otherwise unchanged (id, name, machines, extras, inputs, tags_unlocked, requires).
- `config.RESTOCK_ITEM_COST` remains as a flat fallback for items that don't yet have an explicit `buy_price`.
- The restock panel's "$ X per item" header text in `item_panel.lua` stays (or can be updated to show per-item prices in a follow-up).
- The tooltip box layout in `grid.lua` is unchanged except for the optional extra price line.
- All drag, drop, grid, and action mechanics are untouched.

## Open questions

None — the scope is clear.
