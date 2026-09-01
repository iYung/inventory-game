# Order Generator & Merchant System

## Goal

Two tightly coupled features:

1. **Order generator** — replaces the loved/liked/disliked tag-preference system
   with rule-based, multi-item orders that scale with day number and owned programs.
2. **Merchant system** — splits the single merchant type into restock merchants
   (paid restocking of raw ingredients) and program merchants (purchase new
   production chains that expand what orders can ask for).

These are designed together because the order generator's `available_tags` is
derived from owned programs, so neither is complete without the other.

---

## Affected files

- `lua/game/data/program_defs.lua` — **new**: static definitions for every purchasable program
- `lua/game/program_state.lua` — **new**: tracks which programs the player owns
- `lua/game/order_gen.lua` — **new**: order generator
- `lua/game/data/item_defs.lua` — no changes
- `lua/game/customer_queue.lua` — calls order_gen; builds restock/program merchant configs
- `lua/game/customer.lua` — `loved/liked/disliked_tags` removed from order-kind; gains `order_rules` + `order_item_count`; merchant kind becomes `"restock"` or `"program"`
- `lua/game/day_state.lua` — `record_serve(items, payout)`; removes hardcoded `+10`
- `lua/game/config.lua` — `ORDER_PANEL_*` and `MERCHANT_PANEL_*` constants updated
- `game/scenes/kitchen_scene.lua` — order panel renders rules + live pass/fail; restock/program merchant panels use expanded grid + per-item cost on drag

---

## What changes

### 1. Rule types

A rule is a Lua table with a `kind` field:

```lua
{ kind = "at_least",  tag = "Protein",   n = 2 }   -- ≥ 2 Protein items
{ kind = "no_more",   tag = "Greasy",    n = 1 }   -- ≤ 1 Greasy item
{ kind = "no",        tag = "Bitter"          }    -- 0 Bitter items allowed
{ kind = "specific",  type_id = "fried_chicken" }  -- must include this dish
{ kind = "all_unique"                         }   -- no two items share a type_id
```

All rules must pass for Serve to enable. Partial satisfaction awards nothing.
`no_more` shows amber (at limit) or red (exceeded); all others are green/red.

### 2. Program definitions — `lua/game/data/program_defs.lua`

Each entry defines a purchasable production chain.

```lua
{
  id            = "pump_microwave",
  name          = "Pump & Microwave",
  machines      = { "pump", "microwave" },   -- draggable machines; ALL must reach the floor to complete
  extras        = {},                         -- purchasable alongside machines at $5 flat; don't count toward completion
  inputs        = { "raw_chicken", "potato" }, -- ingredients consumed by this program; used by RestockGen
  tags_unlocked = { "Protein", "Filling" },  -- reachable output tags
  requires      = {},                         -- program IDs that must be owned first
  cost          = 40,
}
```

`stock` is unused — it was originally intended to auto-deliver ingredients on purchase, but that mechanic was dropped. `inputs` feeds RestockGen instead.

`extras` are additional items shown alongside machines in the program merchant panel (e.g. chickens next to the coop). They're always visible (new offer and repurchase alike), cost `RESTOCK_ITEM_COST` ($5) each, and do **not** count toward program completion.

`requires` is a list of program IDs that must all be owned before this program
can be offered for sale. Pacing is entirely driven by this graph — no fixed/random
tier distinction needed.

**Prerequisite graph** (all programs; `requires` defined in data, not code):

```
fryer  ← starting program (pre-owned at game start)
├── garden          requires: fryer
├── pump_microwave  requires: fryer
│   ├── pot                 requires: pump_microwave
│   │   └── coop            requires: pot
│   │       └── incubator   requires: coop
│   ├── meat_machine        requires: pump_microwave
│   │   └── barn            requires: meat_machine
│   │       └── milking_center  requires: barn
│   │           └── cheese_cave requires: milking_center
│   └── coffee_machine      requires: pump_microwave
```

**Merchant inventory generator** (`MerchantGen`, lives in its own file):

```
MerchantGen.offer(program_state) → list of up to 3 program entries
```

Two-step selection, filling up to **3 slots** total:

1. **New programs (1–2 slots)**: randomly pick 1–2 from programs that are not
   yet owned AND have all `requires` satisfied.
2. **Repurchase programs (remaining slots, max 3 total)**: randomly pick from
   already-owned programs to fill the remaining slots.

Programs can be repurchased any number of times — same cost, same machines and extras.
Duplicate machines are additional units on the floor, letting the player expand
production capacity without special casing.

The game starts with **exactly one program already owned**: `fryer`. Its machines
are pre-placed on the floor grid at game start. Everything else requires purchase.

### 3. Program state — `lua/game/program_state.lua`

```lua
ProgramState.new(starting_id)    -- owns one program from the start
ProgramState:owns(id)            -- boolean
ProgramState:buy(id)             -- marks owned; caller deducts currency
ProgramState:available_tags()    -- union of tags_unlocked across all owned programs
ProgramState:available_outputs() -- all type_ids producible from owned machines
```

### 4. Order generator — `lua/game/order_gen.lua`

`OrderGen.generate(day, program_state)` → order config table.

**Item count** — random in `[lo, hi]`:

| Days | Range |
|------|-------|
| 1–2  | 1–2   |
| 3–6  | 1–4   |
| 7+   | 1–5   |

**Rule count** — random in `[lo, hi]`:

| Days | Range |
|------|-------|
| 1–4  | 1–2   |
| 5+   | 1–4   |

**Available tags**: `program_state:available_tags()`.
**Specific dish source**: `program_state:available_outputs()` — only output items
(produced items), never raw ingredients, appear in `specific` rules.

**Rule generation:**
1. Pick item count and rule count.
2. Build a weighted kind pool (`at_least` and `no` common; `no_more`, `specific`,
   `all_unique` less frequent).
3. Fill rule slots: tag-based kinds pick a random tag from available tags, skip if
   already constrained. `specific` picks a random output, skip if none or already
   used. `all_unique` added at most once, only when item_count ≥ 2.
4. Validate: confirm a satisfying combination of `item_count` output items exists
   given the rules. If not, drop the last rule and retry once; if still invalid,
   drop it.

**Payout**: `item_count × 10 + (rule_count - 1) × 5`. Stored in the order config.

### 5. Merchant system

#### Restock merchant

- One slot in the customer queue per day, same walk-in mechanic as today.
- Stock is generated by `RestockGen` based on owned programs (see below).
- Panel grid: **6×4**.
- Each item has a per-unit cost (TBD prices). Dragging onto the floor deducts
  immediately; unaffordable drags are rejected with a visual cue.

**`RestockGen`** (`lua/game/restock_gen.lua` or same file as `MerchantGen`):

Each program in `program_defs` gains an `inputs` field:

```lua
inputs = { "raw_chicken", "potato", "onion" }, -- ingredients this program may need to buy
```

`RestockGen.stock(program_state)` → list of `{type_id, quantity}` pairs:

1. Collect the union of `inputs` across all owned programs (full pool, no filtering
   for self-sufficiency — water remains a valid restock even if pump is owned).
2. Randomly pick **up to 5** items from the pool.
3. Assign a random quantity to each (e.g. 1–4 units).

Simple and stable — the pool only grows as programs are purchased, never shrinks.

#### Program merchant

- Appears every **2 days** (days 2, 4, 6, …). Restock merchant always goes first (slot 1).
- Offers 1–2 new programs + fills to 3 total with repurchasable programs.
- Panel: programs laid out row by row. Each program's `machines` are placed first,
  then its `extras`, advancing col by each item's actual footprint width. When a
  row overflows, it wraps and advances row by the tallest item in that row.
  A blank separator row follows each program. Panel height shrinks to fit content.
- **Cost**: dragging the **first machine** from a new program deducts the full program
  cost. Subsequent machines from that program are free. Extras always cost $5 flat
  (RESTOCK_ITEM_COST) per drag, regardless of program state.
- **Completion**: a program is marked owned in `ProgramState` once **all** of its
  `machines` have been dragged to the floor (tracked by `_machines_placed` on
  `ItemPanel`). Extras never count toward completion.
- Panel size: **8 cols × dynamic rows** (shrinks to content after placement).

### 6. DayState changes

`record_serve(items, payout)`:
- `items` — list of `type_id` strings in the panel at serve time.
- `payout` — from the order config; replaces hardcoded `+10`.
- Increments `sold_items` per type_id (per day, for day summary).

### 7. Order panel changes

- Size: **4×4** (`ORDER_PANEL_COLS = 4, ORDER_PANEL_ROWS = 4`).
- Rule list renders above the grid. Each row: rule description + live pass/fail
  indicator, recalculated on every drag event.
- Payout displayed alongside rules.
- Serve enables only when all rules are green AND panel has at least one item.

### 8. CustomerQueue changes

`CustomerQueue.new(total, day, program_state)`:
- Order configs built via `OrderGen.generate(day, program_state)`.
- Total customers per day: random in **[4, 6]** (up from fixed 3).
- One slot is always a restock merchant (random position, same as today).
- On even days (2, 4, 6…), one additional slot is a program merchant.
- Remaining slots are order customers built via `OrderGen.generate`.

---

## What stays the same

- Drag-and-drop, rotation, grid placement mechanics — unchanged, including for
  machines bought from the program merchant (drag to floor = purchase + placement).
- Overnight system, item production, item definitions.
- Day summary screen (updated to show payout per order).
- Speech bubble / typewriter reveal — bubble gives a short natural-language hint;
  formal rules are in the panel. Wording generation TBD.

---

## Open questions

- **Restock item prices**: $5 flat per item for now; tune during balance pass.
- **Program costs**: set in program_defs but not yet balance-tuned.
