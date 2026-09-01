# Design: Inventory Size Increase & Customer Trait Overhaul

## Goal

1. Increase the main floor inventory grid by 50% (90 → 135 cells) by widening from 10 to 15 columns.
2. Replace the single `requested_tag` customer preference with three trait tiers: `disliked_tags`, `liked_tags`, `loved_tags`. Each tier holds 1–3 randomly chosen tags. Rewards are not yet computed — traits are display-only for now.

## Affected files

- `lua/game/config.lua` — `GRID_COLS` 10 → 15; `GRID_ORIGIN_X` auto-recomputes from the centered formula.
- `lua/game/customer_queue.lua` — `make_default_cfg` generates three trait tiers instead of one `requested_tag`; customer message updated to mention preferences.
- `lua/game/customer.lua` — `Customer:show()` stores `disliked_tags`, `liked_tags`, `loved_tags` instead of `requested_tag`.
- `lua/game/item_panel.lua` — `_serve_enabled()` enables Serve when exactly 1 item is in the panel (no tag check). Order panel reminder row displays all three tiers with colored labels.
- `tests/test_customer.lua`, `tests/test_kitchen_scene.lua` — update any test referencing `requested_tag` or the old serve-enable logic.

## What changes

### Grid size
- `config.GRID_COLS = 15` (was 10). `GRID_ORIGIN_X = (1280 - 15*36)/2 = 370` (was 280). No other layout or row changes — rows are already at the screen-height limit.

### Customer traits
- Each customer config now carries three fields instead of `requested_tag`:
  - `disliked_tags`: table of 1–3 tag strings (decreases reward — future work)
  - `liked_tags`: table of 1–3 tag strings (slight reward increase — future work)
  - `loved_tags`: table of 1–3 tag strings (large reward increase — future work)
- Tags are drawn from the pool of all known tags in `item_defs` (currently: Protein, Healthy, Greasy, Filling, Hearty). Each tag appears in at most one tier per customer. Tags not assigned to a tier are neutral (not shown).
- Assignment algorithm: shuffle all tags; take 1–2 for `loved`, 1–2 for `liked`, 1 for `disliked` (up to what's available).
- Customer speech bubble: replaced with a single line listing preferences, e.g. "I love Healthy food! Greasy stuff isn't for me."
- Order panel reminder row (between title bar and grid): replaced "Order: [tag]" with three labeled rows showing each tier, e.g. "❤ Loved: Healthy, Protein  |  ✓ Liked: Filling  |  ✗ Disliked: Greasy".

### Serve gate
- `ItemPanel:_serve_enabled()`: enabled when `item.kind == "order"`, exactly 1 item is in the panel, **and that item has at least one tag** (`#item.tags > 0`). Containers and raw/uncooked ingredients carry no tags and leave Serve disabled.

### Visual feedback on food placement
- When the order panel has exactly 1 item in it, each tier row in the reminder area highlights dynamically:
  - **Loved match** (food has any loved tag): bright gold label
  - **Liked match** (food has any liked tag): bright green label
  - **Disliked match** (food has any disliked tag): bright red label
  - **No match** (tier's tags aren't on the food): dimmed label
- When the panel is empty, all tier labels are drawn at neutral brightness.

## What stays the same
- `GRID_ROWS = 9` (screen height limit unchanged)
- Merchant flow (Leave button, stock panel, kind == "merchant") unchanged
- Dialog typewriter system (advance, skip, talking_after) unchanged
- No reward points computed anywhere

## Open questions
None.
