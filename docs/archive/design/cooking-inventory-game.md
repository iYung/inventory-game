## Goal

Build the first playable slice of a cooking-themed grid-inventory game. A static
scene is split into two halves: the **top half** shows customers arriving one at a
time to order food, and the **bottom half** is a grid-based inventory where the
player drags/rotates items (ingredients and appliances), combines them via
containers with timed actions (e.g. a microwave "cooking" meat), and hands
finished items to the waiting customer.

Reuses two things from `../wip`: the walk-in/wait/talk/walk-out customer state
machine + pre/post dialogue bubble system, and the general "container holds
items, button triggers an action that checks/transforms contents" idea (wip's
plants/watering-can/grafter). Reuses the current framework as-is (`Scene`,
`Camera`, `Sprite`, `SpriteSet`, `Timer`, `Drawer`, `Input`, `scene_manager`).
Grid placement, rotation, and multi-cell items are new — nothing in either repo
does this today (wip's `Slot`/`Store` is one-item-per-slot, not a grid).

## Affected files

New files only; nothing existing is modified except `main.lua` (swap the scene)
and `game/scenes/game_scene.lua` (replaced/repurposed).

- `game/scenes/kitchen_scene.lua` — top-level scene, owns day/customer loop, wires top+bottom halves together
- `lua/game/config.lua` — shared constants (grid cell size `U`, screen split line, colors)
- `lua/game/grid.lua` — the bottom-half inventory grid: cell occupancy, placement/collision, drag, rotate
- `lua/game/item.lua` — base item: id, footprint cells (list of `{dx,dy}`), rotation, sprite, optional sub-inventory, optional actions
- `lua/game/data/item_defs.lua` — data-driven item definitions (footprint, sprite color/placeholder, container slots, actions, transform rules)
- `lua/game/item_panel.lua` — the popup sub-inventory panel opened on double-click (its own small grid + action buttons)
- `lua/game/customer.lua` — adapted from `wip/lua/game/customer.lua`: walk-in/wait/talk/walk-out + pre/post dialogue bubbles, minus plant-specific bits
- `lua/game/customer_queue.lua` — per-day customer list/spawning, "N customers today" tracking, "Next Day" button state
- `lua/game/day_state.lua` — current day number, customers remaining/served, currency
- `game/player.lua` — deleted (no walking player character in this game; free-look static scene)
- `main.lua` — point `SceneManager:switch(...)` at `KitchenScene.new()` instead of `GameScene.new()`

## What changes

### Screen layout

1280x720 logical canvas (matches current `main.lua`), split at y=360:
- **Top half (y 0–360):** customer stage. A back wall, an entry point offscreen-right, a "counter" line where customers stop and wait.
- **Bottom half (y 360–720):** the inventory grid. Fixed grid, e.g. 10 columns x 6 rows of 36px cells (tunable in `config.lua`), drawn with a background panel.

No camera movement — `Scene.camera` stays static (zoom 1, fixed x/y), since this is explicitly a static scene, not a scrolling one. `player.lua` and WASD movement are removed; there is no player avatar, only mouse/click interaction.

### Grid inventory (`grid.lua`, `item.lua`)

- Grid is one shared surface for both appliances (microwave) and ingredients (meat) per the chosen MVP scope — no separate delivery area yet.
- Each item has a **footprint**: a list of occupied cell offsets, e.g. `{{0,0}}` for a 1x1 meat, `{{0,0},{1,0},{0,1},{1,1}}` for a 2x2 microwave. Footprints and rotations are defined per item type in `item_defs.lua`.
- **Drag:** mouse-down on an item's occupied cell picks it up (item follows cursor, snapped preview shown on the grid); mouse-up drops it if the target cells are free and in-bounds, otherwise it snaps back to its last valid position.
- **Rotate:** while dragging (or with the item selected), a key/right-click rotates the footprint 90°; the drop preview updates live and rejects rotations that would go out of bounds or overlap.
- **Double-click** an item that has `has_panel = true` in its def opens that item's `item_panel.lua` popup; single click/drag is reserved for grid movement.
- Items start pre-placed on the grid at day 1 (fixed starting layout defined in `item_defs.lua`/scene setup) — no delivery/spawn system for this MVP slice.
- Items persist across days (nothing resets the grid between days) — day-loop only concerns customers/currency.

### Item sub-inventory + timed actions (`item_panel.lua`, `item_defs.lua`)

- A container item (microwave) defines: a small internal grid (e.g. 2x1 or 2x2 cells), a list of action buttons (e.g. "Cook"), and per-action rules: required input item type(s) inside the panel grid, output item type(s) it becomes, and a duration in seconds.
- Double-clicking the microwave opens `item_panel.lua`: shows its internal grid, lets the player drag items from the main grid into it (and back out) the same way as the main grid (reuses grid drag/drop logic against a second `Grid` instance), and shows the action button(s) along the bottom.
- Action buttons are enabled only when the panel's current contents satisfy the action's required-input check; clicking starts a **timed transform**: a progress bar/fill shown on the button (or on the item in the panel), ticking via `Timer`/`dt`; when it completes, matching input items are swapped in place for their output item type (e.g. raw meat sprite/id → cooked meat sprite/id, same footprint). Panel stays open during cooking; player can close it and the timer keeps running in the background (stored on the item itself, not the panel), so they can come back later.
- This is data-driven (`item_defs.lua` action table), not per-item hardcoded Lua, so adding a second appliance (e.g. a cutting board) later means adding a data entry, not new code.

### Customers (`customer.lua`, `customer_queue.lua`, `day_state.lua`)

- Ported from `wip/lua/game/customer.lua`: same state machine (`idle → walking_in → waiting → (talking) → walking_out → idle`), same pre-message speech bubble with typewriter reveal, same `after_messages` (post-serve dialogue) support. Plant-specific bits (plant_type, color-replace shader, plant sprite variants) are stripped; customer sprite becomes a simple placeholder (colored rectangle via `Sprite`, matching this repo's current placeholder-art style — see `game_scene.lua`'s coins/ground) with a name + requested item.
- Each customer carries one **request**: an item type id (e.g. `"cooked_meat"`). Pre-messages state the request in text (e.g. "Could I get some cooked meat?"); this doubles as the player-facing hint for what to hand over, no separate UI needed for MVP.
- **Serving:** clicking a customer while `waiting` and holding/dragging a matching item onto them fulfills the order — item is removed from the grid, `after_messages` (happy line) play, customer awards currency, then walks out. Dragging a non-matching item onto them, or clicking an explicit "send away" affordance, is failure — customer gives a short "not what I wanted" line and walks out with no reward. (Matches your answer: simple item request + reward, with wip's pre/post dialogue.)
- `customer_queue.lua` holds today's list of N customers (N configurable, e.g. 3–5 for MVP) and current index. Only one customer is ever on-stage/`active` at a time — the state machine already guarantees this via wip's single-customer pattern, so the queue just decides who spawns next.
- Currency is tracked in `day_state.lua`, incremented on successful serves. No spend/shop mechanic yet — just accumulation and display (matches "item request + reward" without full economy).

### Day loop

- `day_state.lua` tracks `day`, `customers_served`, `customers_total` (from the queue), `currency`.
- Customers spawn one at a time automatically (next customer walks in as soon as the previous one finishes walking out) until `customers_total` for the day is reached.
- Once the last customer for the day has walked out, a **"Next Day" button** appears (bottom-right of the top half, say) and is the only way to advance — no auto-advance, no summary screen for this slice. Clicking it increments `day`, resets `customers_served` to 0, generates/refills the day's customer queue, and starts the first customer walking in again. (Matches your answer.)
- Before the last customer is served, the button either doesn't render or renders disabled — TBD in review, default: don't render it at all until eligible, simplest to implement and matches "clickable after all customers sold."

### Tests

Following this repo's existing pattern (`tests/test_scene.lua`, `test_basics.lua`, `test_camera.lua`, run via `--headless`), add headless tests for: grid placement/collision/rotation bounds, item panel input-matching logic, timed-action completion, customer state transitions + serve success/failure, and day-loop advancement gating on the Next Day button.

## What stays the same

- `lua/core/*` (camera, drawer, fonts, input, scene, scene_manager, shader, sprite, spriteset, timer) — untouched, used as-is
- `lua/headless/*`, `conf.lua`, `web-template/`, `scripts/build_web.sh` — untouched
- Canvas size, letterboxing/scaling logic in `main.lua` — untouched
- Fade-transition scene switching — untouched (not used within this single static scene, but still available)

## Open questions

Resolved during review:
- Customer requests: single item request + reward, with wip-style pre/post dialogue. ✓
- Grid scope: single shared grid for appliances + ingredients, no separate delivery area. ✓
- Container actions: timed transform (progress bar), not instant. ✓
- Day loop: manual "Next Day" button, enabled only once all of today's customers are served. ✓

Still open — flagging assumptions made above, please confirm or correct:
1. **Art**: placeholder colored rectangles (via `Sprite`, no images) for grid items and customers, consistent with this repo's current placeholder style — real art is a later pass. Assumed yes.
2. **Grid/panel sizing**: main grid 10x6 @ 36px cells, microwave panel 2x1 or 2x2 — these are starting guesses, tunable, not load-bearing for the design.
3. **Starting item set for MVP**: just enough to prove the loop — a microwave (2x2, container, "Cook" action) and a few raw-meat items (1x1) placed on the grid at day start, plus one customer type requesting cooked meat. More items/recipes come in later checklists.
4. **Failure interaction**: is there an explicit "send customer away empty-handed" action (e.g. a button/right-click), or does simply doing nothing while other customers wait not apply since only one customer is ever on stage — should an unmatched drag onto the customer be the *only* failure path, with the player otherwise free to just leave them waiting indefinitely (no timeout)? Assumed: no timeout, failure only triggers on an explicit wrong-item drop; waiting indefinitely is allowed for MVP.
