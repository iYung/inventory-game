# Chicken & Coop Feature Design

## Goal

Add a chicken-based production chain to the game: chickens produce eggs overnight
in a coop, eggs can be hatched back into chickens in an incubator (takes two
nights), and a meat machine converts chickens into raw meat on demand via a
button press.

---

## Affected files

- `lua/game/data/item_defs.lua` — add `chicken`, `egg`, `coop`, `meat_machine`,
  `incubator` definitions
- `lua/game/item.lua` — add `overnight_tick()` method and overnight-action
  engine; extend `refill_daily` call-sites are unchanged (this is a new method)
- `game/scenes/kitchen_scene.lua` — call `item:overnight_tick()` on all floor
  items (and their panel items) when the player presses "Continue" on the day
  summary

---

## What changes

### New items

| type_id       | Size | Panel      | Notes                                    |
|---------------|------|------------|------------------------------------------|
| `chicken`     | 1×1  | none       | Brownish; placeable in coop or meat machine |
| `egg`         | 1×1  | none       | Pale cream; produced by coop, consumed by incubator |
| `coop`        | 2×2  | 2 cols × 2 rows | overnight_action: 1 chicken → 1 egg per night |
| `meat_machine`| 2×2  | 2 cols × 1 row  | button action "Process": 1 chicken → 1 raw_meat (instant, same as fryer) |
| `incubator`   | 1×1  | 1 col × 1 row   | overnight_action: 1 egg → 1 chicken after 2 nights |

### Overnight action system (`Item:overnight_tick`)

A new optional field `overnight_actions` in item_defs parallels `actions` but
is triggered by nights passing rather than real-time seconds:

```lua
overnight_actions = {
    { requires = { chicken = 1 }, produces = { egg = 1 }, nights = 1 },
}
```

`Item:overnight_tick()` runs each night for every item on the floor (called
from kitchen_scene during day advance, same loop that calls `refill_daily`):

1. For each overnight_action, check if `requires` is currently satisfied by the
   item's panel contents.
2. If satisfied, increment `self.overnight_state[action_name].nights_elapsed`.
   If not satisfied, reset that counter to 0 (removing the egg mid-incubation
   resets progress).
3. Once `nights_elapsed >= nights`, consume the `requires` items, produce the
   `produces` items into the panel (first-fit), and reset the counter.

The coop (nights=1) immediately produces an egg on the morning after a chicken
is inside. The incubator (nights=2) takes two full nights.

Panel items are **not** recursed into for `overnight_tick` — only floor-level
items are ticked. (Coop and incubator sit on the floor; their contents are
ingredient/product items with no `overnight_actions` of their own.)

### Meat machine

Uses the existing `actions` system (real-time button) with a very short
duration (e.g. 1.0s) so it feels manual but not instant. Recipe:
`{ chicken = 1 } → { raw_meat = 1 }`. The resulting raw_meat can then be
cooked in the microwave as normal.

### Kitchen scene day advance

In the "Continue" handler inside `mouse_pressed`, after `refill_daily` is
called on each item, also call `item:overnight_tick()` on each floor item.
Order: `overnight_tick` after `refill_daily` so gardens fill before any
overnight logic reads their contents (gardens have no overnight_actions, so
order doesn't matter in practice, but it's the safer default).

---

## What stays the same

- All existing items, recipes, and cooking chains are untouched.
- The `daily_fill` mechanism for gardens is unchanged.
- The `actions` / button-press cooking system is unchanged.
- No new UI beyond what item panels already provide.

---

## Open questions

None — proceeding to checklist.
