## Goal

Add a tag system to food items (an item can carry zero or more tags, e.g.
`{"Protein"}`), switch customer requests from "give me this exact item
type" to "give me something tagged X" (one tag per customer for now), and
add a second food line — Broccoli → Steamed Broccoli (tag `"Healthy"`) —
cooked via a second action on the existing microwave.

## Affected files

- `lua/game/data/item_defs.lua` — `tags` field on relevant entries; new
  `broccoli`/`steamed_broccoli` entries; microwave gains a second action
- `lua/game/item.lua` — `Item.tags` (a plain field, set once at
  construction — unlike `footprint()`, tags don't change with rotation)
- `lua/game/customer.lua` — `requested_type` → `requested_tag`
  (rename throughout; same optional/nil-able field, just what it means
  changes)
- `lua/game/customer_queue.lua` — the default order config now randomly
  picks one of the tags actually present in `item_defs`, with a
  per-tag greeting message
- `game/scenes/kitchen_scene.lua` — the serve/dismiss match check switches
  from an exact `type_id` comparison to "does the dropped item carry the
  requested tag"; starting floor layout and merchant stock both get a
  broccoli or two so the new food is actually reachable in-game

## What changes

### Tag semantics (per your answers)

- An item's tags live in its `item_defs` entry: `tags = { "Protein" }`.
  Absent/empty means no tags — that item can never satisfy any tag
  request, by design.
- `raw_meat` and `broccoli` (the new raw item) carry **no tags**.
  `cooked_meat` is tagged `Protein`; the new `steamed_broccoli` is tagged
  `Healthy`. This is what keeps the microwave meaningful — a customer
  asking for a tag can only ever be satisfied by something you actually
  prepared, never a raw ingredient handed over directly.
- The field is a plain list so an item can carry more than one tag later
  (e.g. a future dish could be both `Protein` and `Healthy`) without any
  structural change — nothing about the design assumes exactly one tag per
  item, only that a *customer's request* is exactly one tag for now.

### `lua/game/data/item_defs.lua`

```lua
raw_meat      = { ..., }                              -- unchanged, still no tags
cooked_meat   = { ..., tags = { "Protein" } }          -- add tags

broccoli = {
    name = "Broccoli",
    footprint = { { 0, 0 } },
    color = { 0.30, 0.55, 0.20, 1 },                   -- placeholder green
},
steamed_broccoli = {
    name = "Steamed Broccoli",
    footprint = { { 0, 0 } },
    color = { 0.45, 0.75, 0.30, 1 },                   -- brighter green
    tags = { "Healthy" },
},

microwave = {
    ...,
    actions = {
        { name = "Cook",  requires = { raw_meat = 1 }, produces = { cooked_meat = 1 },      duration = 3.0 },
        { name = "Steam", requires = { broccoli = 1 }, produces = { steamed_broccoli = 1 }, duration = 3.0 },
    },
},
```

The action system already supports a list of independently-named actions
per container — `ItemPanel` already lays out "one button per `def.actions`
entry" generically, and `Item:start_action`/`update`/`complete_action`
already look actions up by name and operate on whichever one was clicked.
So "Steam" is just a second data entry, not a new mechanic: two buttons
appear in the microwave's panel, "Cook" only lights up with raw meat in
there, "Steam" only with broccoli. No engine changes needed here at all —
flagging this so it's clear the multi-recipe question from earlier isn't
being solved with new machinery, the existing one already covers it.

### `lua/game/item.lua`

`Item.new(type_id)` sets `self.tags = item_defs[type_id].tags or {}`
alongside the existing fields. A plain field rather than a method (unlike
`footprint()`) since tags don't depend on rotation state.

### `lua/game/customer.lua`

Straight rename: `self.requested_type` → `self.requested_tag`,
`cfg.requested_type` → `cfg.requested_tag`. No behavioral change to the
class itself — it never inspected the value, just stored/passed it
through; the meaning shift (item type vs. tag) is entirely in how the
scene compares it at serve time.

### `game/scenes/kitchen_scene.lua`

The serve/dismiss branch's match check:

```lua
-- before
if item.type_id == self.customer.requested_type then

-- after
if has_tag(item, self.customer.requested_tag) then
```

with a small local helper `has_tag(item, tag)` that checks
`item.tags` for `tag`. Everything else in that branch (serve/dismiss,
currency, the rejection message) is unchanged.

Starting layout (`on_enter`) and the merchant's stock both currently only
ever offer meat; each gets a placeholder broccoli added so the new food
line is actually reachable without editing data files by hand — exact
counts aren't load-bearing, see Open Questions.

### `lua/game/customer_queue.lua`

`make_default_cfg()` currently hardcodes `requested_type = "cooked_meat"`
and a matching message. It now:

1. Collects the set of tags actually used anywhere in `item_defs` (scans
   every entry's `tags` list, de-duplicates, sorts for determinism) rather
   than hardcoding `{"Protein", "Healthy"}` — so a future third tagged
   food automatically joins the request pool with no change needed here.
2. Picks one at random (`math.random`) per your answer — same pattern
   already used for the per-day merchant slot.
3. Looks up a friendly greeting for that tag from a small
   `TAG_MESSAGES` table (e.g. `Protein = "Could I get something with
   protein?"`, `Healthy = "Could I get something healthy?"`), falling back
   to a generic `Could I get something tagged "X"?` for any tag without a
   custom line — so this doesn't need updating every time a tag is added,
   only when you want nicer phrasing for a specific one.

### Tests

- `test_item.lua` — `Item.new("cooked_meat").tags` contains `"Protein"`;
  `Item.new("raw_meat").tags` is empty.
- `test_customer.lua` — rename `requested_type` → `requested_tag` in
  configs/assertions (mechanical).
- `test_day_loop.lua` — `CustomerQueue` configs now carry `requested_tag`
  drawn from the known tag set instead of a fixed `"cooked_meat"`; update
  the "drain N configs" test to assert against the tag pool rather than
  one hardcoded value.
- `test_kitchen_scene.lua` — the shared `order_cfg()` test helper and
  serve/dismiss assertions move from `requested_type = "cooked_meat"` /
  dropping the exact item to `requested_tag = "Protein"` / dropping
  anything tagged `Protein`. The existing "wrong item" tests get slightly
  *more* meaningful for free: `raw_meat` now has zero tags, so it's
  guaranteed to mismatch any tag request, which is exactly the scenario
  those tests want.

## What stays the same

- `lua/game/grid.lua`, `lua/game/item_panel.lua` — untouched, no new
  concepts needed there (per the note above, multi-action containers
  already worked)
- The cooking/action timer mechanism itself (`start_action`,
  `complete_action`, timed duration, panel capacity) — unchanged, broccoli
  just uses it a second time
- Everything about the day loop, merchant flow, drag/drop, panels — none
  of that touches request matching

## Open questions

Resolved from your answers: raw items carry no tags, only prepared items
do; requested tag is chosen randomly per customer.

Still open — flagging assumptions, not blocking:
1. **Starting broccoli quantity/placement** — proposing one or two raw
   broccoli added to `on_enter`'s starting floor layout (alongside the
   existing meat) and one added to the merchant's stock list. Just enough
   to make the new food discoverable; trivial to tune.
2. **Steam duration** — assumed 3.0s, matching Cook. No reason given to
   differ.
3. **Per-tag greeting message wording** — the `TAG_MESSAGES` text above is
   a placeholder ("Could I get something with protein?" /
   "...something healthy?"); easy to reword.
