## Day Summary Checklist

- [x] Task A — `lua/game/day_state.lua` — Add `sold_items` map to `DayState.new()`, update `record_serve(type_id)` to tally it, and clear it in `advance_day()`
- [x] Task B — `game/scenes/kitchen_scene.lua` — Add `_showing_summary` flag; on "Next Day" click set the flag instead of advancing; add summary overlay draw (backdrop + box with day/items/revenue/served + "Start Day N+1" button); handle the Continue button click to actually advance the day; block all other input while summary is showing
