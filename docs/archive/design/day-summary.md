# Day Summary Screen

## Goal

When the day ends, show the player a summary of all items sold that day before advancing to the next day — giving them a moment to reflect on their performance and see exactly what they served.

## Affected files

- `lua/game/day_state.lua` — track sold item types alongside existing stats
- `game/scenes/kitchen_scene.lua` — show the summary overlay on "Next Day" click; gate day advance behind a "Continue" button

## What changes

### 1. `DayState` — track sold items

Add `self.sold_items = {}` (a list of `{ type_id, amount }` entries, or a flat map `type_id → count`).

Modify `DayState:record_serve(type_id)` to accept the sold item's `type_id` and increment its count in the map.

Add `DayState:clear_sold_items()` called inside `advance_day()` so each day starts fresh.

### 2. `KitchenScene` — summary overlay

Add state flag: `self._showing_summary = false`.

When the "Next Day" button is clicked (currently advances immediately), instead:
- Set `self._showing_summary = true`

Draw the summary overlay in `KitchenScene:draw()` when `_showing_summary` is true:
- Semi-transparent full-screen backdrop
- Centered box with:
  - Title: "Day X Summary"
  - List of sold items with quantities (e.g. "Grilled Meat × 2")
  - Revenue earned: "$30"
  - Customers served: "3/3"
  - A "Start Day N+1 →" button

When "Start Day N+1" is clicked, advance the day (same logic that was on "Next Day").

Clicks on the summary overlay are handled in `mouse_pressed` before any other hit-test — the overlay is modal and blocks all input behind it.

## What stays the same

- `DayState:record_dismiss()` unchanged — dismissed customers are shown in served count but not in the sold items list
- The "Next Day" button appearance and position unchanged — it still appears in the same place, same condition (`_next_day_ready()`)
- All grid, panel, drag-and-drop, and customer logic unchanged
- No new files — changes confined to the two files above

## Open questions

None — scope is clear.
