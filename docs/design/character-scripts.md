# Character Scripts

## Goal

Add a scripted-character system: named NPCs with custom dialogue that appear at a specific point in the run, talk through their messages like a regular customer, and walk off. No order panel — they require no item, and the player simply clicks through their lines and then they leave. The immediate test is a tutorial guide with two chapters.

## Affected files

| File | Role |
|---|---|
| `lua/game/data/character_scripts.lua` | New — data definitions |
| `lua/game/day_state.lua` | Add `seen_scripts` and `total_sold` (lifetime counters) |
| `lua/game/customer_queue.lua` | Insert scripted customers at their assigned slot; accept `day_state` parameter |
| `lua/game/customer.lua` | Handle `kind = "scripted"` (no panel) |
| `game/scenes/kitchen_scene.lua` | Pass `day_state` to `CustomerQueue.new`; handle scripted serve; track cooldowns |
| `tests/test_character_scripts.lua` | New — unit tests for trigger / queue logic |

## What changes

### `lua/game/data/character_scripts.lua`

New data file, a table of script entries. Each entry:

```lua
{
    id             = "guide",           -- character identity (shared across chapters)
    chapter        = 1,                 -- chapter number (ch N requires ch N-1 seen first)

    -- Trigger: ALL conditions must pass. Any field omitted means "don't check it".
    trigger = {
        item_sold = "fried_chicken",    -- player must have sold this item type (optional)
        count     = 3,                  -- minimum lifetime sold count for item_sold (default 1)
    },

    -- Appearance
    name           = "The Guide",
    color          = { 0.4, 0.7, 0.9, 1 },   -- body fill colour
    icon           = "guide",                  -- asset name under assets/images/items/ (optional; falls back to default customer sprite)

    -- Placement in the day's queue
    slot           = "after_restock",   -- "after_restock" | "random" (default "random")

    -- Behaviour
    no_dismiss     = true,              -- player cannot click-dismiss before seeing all messages

    -- Dialogue
    messages       = { "...", "..." },
    after_messages = { "Good luck!" },
}
```

For a chapter with an empty `trigger = {}` the character is always eligible (useful for "fire this the first time any trigger criteria would accept it").

### `DayState`

Two new fields that do **not** reset on `advance_day()`:

```lua
self.seen_scripts = {}   -- keys: "id:chapter" → true once shown
self.total_sold   = {}   -- keys: type_id → cumulative count across all days
```

`record_serve(items, payout)` increments `total_sold[type_id]` in addition to the existing `sold_items` (per-day) counter.

### `CustomerQueue`

Signature changes to `CustomerQueue.new(day, program_state, day_state)`. The extra `day_state` argument supplies `seen_scripts` and `total_sold` for trigger evaluation, and `seen_scripts` is written back to when a script is chosen so duplicates can't fire twice on the same day.

**Day 1:** the restock merchant is skipped entirely. All slots on day 1 are order customers (plus any qualifying scripted character).

**Trigger evaluation** for each candidate script entry:

1. `seen_scripts["id:chapter"]` must be nil (not yet shown).
2. All prior chapters for the same `id` must be in `seen_scripts`.
3. `trigger.item_sold` — if set, `(total_sold[trigger.item_sold] or 0) >= (trigger.count or 1)`.

**Slot assignment:**

- `slot = "after_restock"` → always placed at index 2 (right after the restock merchant).
- `slot = "random"` → placed at a random index among the remaining (non-restock, non-program-merchant) positions, same shuffle logic as the existing program merchant.

At most one scripted character per day (lowest chapter of the first qualifying character found). `self.total` increments by 1.

**Cooldown:** `CustomerQueue` is not responsible for cooldowns — see KitchenScene below.

### `Customer` — `kind = "scripted"`

`Customer:show(cfg)` with `kind = "scripted"`:

- Skips panel construction (`self.panel = nil`).
- Sets `payout = 0`.
- Uses `cfg.color` for body colour if provided.
- `cfg.icon` loads `assets/images/items/<icon>.png` for the sprite image, same as the existing `load_icon()` path; falls back to the default customer sprite.
- All message/reveal/walk-in/walk-out behaviour is identical to any other customer.

### `KitchenScene` — click handling and cooldowns

**Serving a scripted customer:** in `mouse_pressed`, when clicking a scripted customer with `done_talking = true`, call `customer:serve()` (to trigger `after_messages` → walk-out) and `day_state:record_serve({}, 0)`. This is the same code path as any customer serve, just with an empty items list and zero payout. Scripted customers **do not** open an item panel.

**Dismissal:** if `no_dismiss` is false and the player dismisses early, the script key goes into a `_script_cooldowns` table on the scene with a day count (default 2). On `advance_day()` the scene decrements each cooldown; entries that reach 0 are cleared, making the character eligible again. This mirrors wip's dismiss-cooldown mechanism but counted in days rather than sales.

**`no_dismiss` guard:** same as wip — neither the dismiss click path nor the "Back" button applies when the active script has `no_dismiss = true`.

**Marking seen:** when a scripted customer is fully served (walks out after `after_messages`), write `day_state.seen_scripts["id:chapter"] = true`.

### Tutorial character data (in `character_scripts.lua`)

```lua
-- Chapter 1: always eligible on the first run
{
    id       = "guide",
    chapter  = 1,
    trigger  = {},                           -- no conditions; fires whenever eligible
    slot     = "after_restock",
    no_dismiss = true,
    name     = "The Guide",
    color    = { 0.4, 0.7, 0.9, 1 },
    messages = {
        "Welcome! I'm here to show you the ropes.",
        "Click a machine on the counter to cook something.",
        "Once it's ready, drag it onto the customer's tray to serve it.",
    },
    after_messages = { "You've got this. Good luck!" },
},

-- Chapter 2: fires once the player has sold at least one fried_chicken
{
    id       = "guide",
    chapter  = 2,
    trigger  = { item_sold = "fried_chicken", count = 1 },
    slot     = "after_restock",
    no_dismiss = true,
    name     = "The Guide",
    color    = { 0.4, 0.7, 0.9, 1 },
    messages = {
        "Looking good! The restock merchant always visits first —",
        "grab fresh ingredients from their stock panel.",
        "More programs become available as you earn coin.",
    },
    after_messages = { "Keep it up!" },
},
```

## What stays the same

- `Customer` state machine is unchanged; scripted customers walk in/wait/talk/walk out the same way.
- Restock merchant is always slot 1 on day 2+; it does not appear on day 1. Program merchant logic is unchanged.
- `DayState` per-day currency, sold\_items, and customer counts work as before.
- No new art assets required; the `color` field gives each character a distinct body colour.

## Open questions

None — scope is clear. Exact dialogue wording can be iterated.
