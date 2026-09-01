# Merchant Panel Purchase Guards

## Goal

Prevent players from (1) opening the sub-inventory of items they haven't purchased yet in a merchant panel, and (2) starting a drag of a merchant item they cannot currently afford.

## Affected files

- `game/scenes/kitchen_scene.lua` — all changes live here; no other file needs touching.

## What changes

### 0. Block dragging floor items into a merchant panel

Items being dragged from the floor grid (or any other panel) should not be droppable onto the merchant's panel. The drop is already resolved in `mouse_released`'s cross-grid transfer path (`hover ~= owner`). A guard there: if `hover` is the merchant's panel (`_is_merchant_grid(hover)`), snap the item back instead of transferring.


### 1. Block opening sub-panels for merchant-grid items

Items in a program merchant's panel (e.g. a Fryer or Microwave) have `has_panel = true` in item_defs, so double-click and right-click currently open their inner grid. Those items haven't been bought yet, so their panel should be inaccessible.

Two code paths open panels:
- `_try_double_click_open(grid, x, y)` — double-click on a grid cell
- `_open_container_at(grid, x, y)` — right-click on a grid cell

Both will gain an early-return guard: if the grid is the active merchant customer's panel (`self.customer.panel`), skip the open.

A new private helper `_is_merchant_grid(grid)` encapsulates the check:
- Returns true when the customer is active, is kind `"restock"` or `"program"`, and `grid == self.customer.panel`.

### 2. Block drag-start when player cannot afford

Currently the currency check only runs at `mouse_released` (drop time), snapping the item back if the player can't afford it. This allows misleading ghost-drags for items the player never had the money for.

Fix: in `mouse_pressed`, when a click lands inside a merchant panel's grid area, check affordability before forwarding to `panel:mouse_pressed`. If the player can't afford the item, swallow the click (return early) so no drag begins.

A new private helper `_can_afford_merchant_item(x, y)` performs the check:

| Item type | Condition |
|---|---|
| `restock` kind, any item | `currency >= RESTOCK_ITEM_COST` |
| `program` kind, `is_extra` flag | `currency >= RESTOCK_ITEM_COST` |
| `program` kind, `program_id`, already owns | free (repurchase, no cost) |
| `program` kind, `program_id`, already paid this visit (`_paid_programs`) | free (only charged once) |
| `program` kind, `program_id`, not yet paid | `currency >= prog.cost` |

The drop-time check in `mouse_released` is kept unchanged as a safety net.

## What stays the same

- The actual purchase/currency-deduction logic in `mouse_released` is untouched.
- ItemPanel, Grid, Item, Customer, DayState — no changes.
- Opening panels for items already on the floor grid is unaffected.
- The Leave, Close, Serve, Skip buttons on merchant panels are unaffected (they sit outside the inner grid area and are not gated by either new check).

## Open questions

None — scope is clear.
