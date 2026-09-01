## Restock Panel Shrink-to-Fit Checklist

- [x] Task A — `lua/game/customer.lua` — After the restock stock-population loop
  (`for _, entry in ipairs(cfg.stock or {}) do … end`), add a block that:
  1. Defines `MIN_RESTOCK_ROWS = 4` as a local constant (module-level, near the other
     layout locals at the top of the file, or immediately before the shrink block if
     there are no other layout constants).
  2. Iterates `self.panel._items` to find the highest occupied row:
     for each item, derive footprint height from `item:footprint()` (scan the footprint
     cells for the max dy, same pattern as the `item_size` helper in the program block),
     then compute `item.cell_row + footprint_height - 1`.
  3. Sets `self.panel.rows = math.max(MIN_RESTOCK_ROWS, max_occupied_row + 1)`.
     If `self.panel._items` is empty, leave `panel.rows` at `MIN_RESTOCK_ROWS`.
