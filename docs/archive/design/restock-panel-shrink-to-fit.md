## Goal

Make the restock merchant panel shrink to fit its actual stock content after populating,
mirroring what the program merchant panel already does. A minimum of 4 rows is enforced
so the panel never feels too small even with a thin stock list.

## Affected files

- `lua/game/customer.lua` — where the restock panel is created and populated

## What changes

After the `for _, entry in ipairs(cfg.stock or {}) do … end` loop that fills the restock
panel, compute the highest occupied row across all placed items and trim `self.panel.rows`
down to `math.max(MIN_RESTOCK_ROWS, max_occupied_row + 1)`.

`MIN_RESTOCK_ROWS = 4` (hard-coded constant in `customer.lua`, not added to `config`
since it's purely a display detail of this one panel).

Finding the highest occupied row: iterate `self.panel._items`; for each item, its anchor
is `item.cell_row` and its footprint height is derived from `item:footprint()` (same
approach as the `item_size` helper already used in the program block). The highest row
that any item occupies is `item.cell_row + footprint_height - 1`; the required row count
is that maximum plus one.

## What stays the same

- The program merchant panel's shrink logic is untouched.
- `config.MERCHANT_PANEL_ROWS` is still used as the initial allocation (so `place_first_fit`
  has full room to work), and it remains the authoritative max-rows constant for the grid
  dimensions that control can_place checks during population.
- The restock panel's column count stays at `config.MERCHANT_PANEL_COLS`.
- Everything in `item_panel.lua` (layout, draw, input) is unchanged — it reads
  `panel.rows` at layout time, so the trimmed value is picked up automatically.
- Tests for the restock generator (`tests/test_restock_gen.lua`) are unaffected because
  they test generation logic, not panel layout.

## Open questions

None — approach is straightforward, no ambiguities.
