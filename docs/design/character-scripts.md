# Character Scripts

## Goal

Add a scripted-character system: named NPCs with custom dialogue that appear at a specific point in the run and behave exactly like a normal order customer — dialogue, then an order panel the player fills and clicks Serve on. Scripted characters are order customers with custom name/color/dialogue/trigger; the "script" is which config gets chosen and when, not a different interaction model. The immediate test is a tutorial guide with two chapters, each requesting a specific item.

**Revision note:** an earlier version of this design introduced a separate `kind = "scripted"` with no order panel. That was wrong — the player had no way to interact with the character beyond clicking through dialogue, and there was no way to specify what to bring them. Scripted characters now always use `kind = "order"`, tagged with `is_scripted = true` on the config/Customer so the queue and scene can still track triggers, cooldowns, and no-dismiss behavior.

## Affected files

| File | Role |
|---|---|
| `lua/game/data/character_scripts.lua` | New — data definitions |
| `lua/game/day_state.lua` | Add `seen_scripts` and `total_sold` (lifetime counters) |
| `lua/game/customer_queue.lua` | Insert scripted customers at their assigned slot; accept `day_state` parameter |
| `lua/game/customer.lua` | Propagate `is_scripted` / `no_dismiss` from cfg; keep custom color when an icon loads |
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

    -- Order (all optional; a customer with no rules accepts any single item for 0 payout)
    order_rules      = { { kind = "specific", type_id = "baked_chicken" } },
    order_item_count = 1,
    payout           = 0,
}
```

Scripted characters behave exactly like a generated order customer: dialogue, then an order panel with Serve/Skip buttons. `order_rules` uses the same rule shapes as `OrderGen` (`at_least`, `no_more`, `no`, `specific`, `all_unique`).

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

At most one scripted character per day (lowest chapter of the first qualifying character found). `self.total` increments by 1. The inserted config has `kind = "order"` (identical shape to a generated order customer) plus `is_scripted = true` and the script's own `name`/`color`/`icon`/`no_dismiss`/`messages`/`after_messages`/`order_rules`/`order_item_count`/`payout`.

**Cooldown:** `CustomerQueue` is not responsible for cooldowns — see KitchenScene below.

### `Customer` — `is_scripted` / `no_dismiss`

`Customer:show(cfg)` sets `self.is_scripted = cfg.is_scripted or false` and `self.no_dismiss = cfg.no_dismiss or false` alongside the existing fields — no separate `kind`. Order-kind logic (panel construction, messages, order_rules) is unchanged and applies to scripted characters exactly as it does to generated ones. When `cfg.color` is set, the sprite keeps that tint even after an icon image loads (generated customers with no cfg.color still reset to white/untinted).

### `KitchenScene` — click handling and cooldowns

Scripted characters use the **same click/panel flow as any order customer** — no special-casing by kind. The same click that finishes their last message opens the order panel; Serve/Skip work exactly as they do for a generated customer.

**Dismissal (`no_dismiss`):** the merchant "Leave" and order "Skip" buttons both set `should_close` unconditionally in `ItemPanel` (it has no concept of `no_dismiss`). The scene checks `self.customer.no_dismiss` before acting on `should_leave`/`should_skip`: if true, it sets `panel.should_close = false` so the click is fully absorbed as a no-op (panel stays open, customer stays put) instead of the dismiss firing or the panel silently closing out from under an order still in progress.

**Cooldown:** if `no_dismiss` is false and the player dismisses early (via Leave or Skip), `self.customer.is_scripted` gates writing the script key into `_script_cooldowns` with a day count (default 2). On `advance_day()` the scene decrements each cooldown; entries that reach 0 are cleared, making the character eligible again.

**Marking seen:** in `update()`, when the active customer stops being active (`was_active and not active()`), the scene checks `self.customer.is_scripted` (not just `self.queue.scripted_key`, which stays set for the whole day regardless of which customer is currently on stage) before writing `day_state.seen_scripts[queue.scripted_key] = true`.

### Tutorial character data (in `character_scripts.lua`)

Chapter 1 (always eligible) asks for a `baked_chicken` (teaches the microwave, which sits pre-stocked with raw chicken at scene start). Chapter 2 (fires once a `fried_chicken` has been sold) asks for another `fried_chicken` and mentions the restock merchant. Both are `no_dismiss = true` and placed `after_restock`. See `lua/game/data/character_scripts.lua` for the exact dialogue and `order_rules`.

## What stays the same

- `Customer` state machine is unchanged; scripted customers walk in/wait/talk/walk out the same way.
- Restock merchant is always slot 1 on day 2+; it does not appear on day 1. Program merchant logic is unchanged.
- `DayState` per-day currency, sold\_items, and customer counts work as before.
- No new art assets required; the `color` field gives each character a distinct body colour.

## Open questions

None — scope is clear. Exact dialogue wording can be iterated.
