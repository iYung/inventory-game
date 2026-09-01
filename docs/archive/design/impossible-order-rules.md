# Impossible Order Rules

## Goal

Prevent the order generator from producing rule sets that are logically
contradictory — e.g. `at_least Protein 2` together with `no Protein`.
When a customer's rules cannot be satisfied simultaneously the player has no
winning move and the order is effectively broken.

---

## Affected files

- `lua/game/order_gen.lua` — bug is fully contained here; two functions need
  patching
- `tests/test_order_gen.lua` — add a targeted contradiction test

---

## What changes

### Root cause

`build_rules` uses `constrained[tag] = kind` to remember the last constraint
applied to each tag. When choosing candidates for the next rule it skips tags
where `constrained[tag] == kind` (same kind). But it freely allows a *different*
kind on the same tag, producing contradictions:

| already placed | next rule picked | result |
|---|---|---|
| `at_least Protein 2` | `no Protein` | need ≥ 2 **and** 0 Protein — impossible |
| `at_least Protein 2` | `no_more Protein 1` | need ≥ 2 **and** ≤ 1 — impossible |

`is_satisfiable` checks each rule in isolation and does not detect these
cross-rule contradictions, so the broken rule set passes the validation step.

### Fix 1 — `build_rules`: mark a tag fully used after any constraint

Change `constrained[tag] = kind` to `constrained[tag] = true`. The candidate
filter becomes `if not constrained[tag]`, meaning once *any* rule touches a
tag no further rule may reference it.

This is the primary prevention. It costs no rule variety in practice — the
pool of tags is large enough that the generator rarely needs to revisit one.

### Fix 2 — `is_satisfiable`: detect same-tag contradictions

Add a pre-pass that groups rules by tag and rejects rule sets where:

- A tag has both an `at_least` rule and a `no` rule, **or**
- A tag has `at_least n` and `no_more m` with `n > m`.

This is a safety net that catches any contradiction that slips past Fix 1
(e.g. rules constructed by tests or future code paths).

### What stays the same

- All rule kinds, weights, and generation logic are unchanged.
- The existing single-retry drop (`table.remove(rules)`) stays; Fix 2 makes
  it more likely to succeed if it is ever needed.
- No other files are touched.

---

## What stays the same

- Payout formula, item-count scaling, rule-count scaling — unchanged.
- All existing tests continue to pass.

---

## Open questions

None — the fix is self-contained and the approach is clear.
