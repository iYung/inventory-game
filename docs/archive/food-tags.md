## Food Tags Checklist

Design doc: `docs/design/food-tags.md`.

### Decisions from review (proceeding with the doc's proposals)

- Raw items carry no tags; only prepared/cooked items do (`cooked_meat` =
  `Protein`, `steamed_broccoli` = `Healthy`).
- Broccoli cooks via a second, independently-named action ("Steam") on
  the existing microwave — no new engine mechanics, the multi-action
  system already supports this.
- A customer's requested tag is chosen randomly from whatever tags
  actually appear in `item_defs` (not hardcoded), with a per-tag greeting
  message and a generic fallback for any tag without one.
- Starting broccoli quantity/placement, Steam duration (3.0s, matches
  Cook), and exact message wording are tunable, not load-bearing.

### Shared contracts (read before starting — the real files, once they
exist, are authoritative if anything here turns out ambiguous)

**`item_defs.lua`** entries get a `tags` field (a list of strings,
optional — absent/empty means no tags): `cooked_meat.tags = {"Protein"}`,
new `broccoli` (no tags) and `steamed_broccoli.tags = {"Healthy"}`
(both 1x1, placeholder green colors). `microwave.actions` gains a second
entry: `{ name = "Steam", requires = {broccoli=1}, produces =
{steamed_broccoli=1}, duration = 3.0 }`, alongside the existing `Cook`.

**`Item`**: gains `self.tags` (plain field, set in `Item.new` from
`item_defs[type_id].tags or {}` — not a method, tags don't depend on
rotation).

**`Customer`**: `requested_type` renamed to `requested_tag` throughout
(field + `cfg.requested_tag` in `show()`). Pure rename — the class itself
never inspects the value.

**`CustomerQueue`**: `make_default_cfg()` picks a random tag from the set
of tags actually present in `item_defs` (scan + dedupe + sort for
determinism, not hardcoded), sets `requested_tag`, and uses a
`TAG_MESSAGES[tag]` lookup (with a generic fallback) for the greeting.
`make_merchant_cfg()`'s `stock` list gets a `"broccoli"` added.

**`KitchenScene`**: the serve/dismiss match check becomes "does the
dropped item's `.tags` contain `customer.requested_tag`" instead of an
exact `type_id ==` comparison, via a small local `has_tag(item, tag)`
helper. `on_enter`'s starting floor layout gets a raw broccoli or two
added alongside the existing raw meat (pick cells that don't overlap the
existing layout — microwave at (0,0)-(1,1), meat at (2,0)/(3,0)/(4,0)).

Tasks are grouped into waves; within a wave, tasks run in parallel against
the contracts above (not against each other's real files). Don't start a
wave until the previous one is fully checked off.

---

#### Wave 0 (done up front by the orchestrating session, not a task)

- [x] `lua/game/data/item_defs.lua` — tags on `cooked_meat`; new
  `broccoli`/`steamed_broccoli` entries; microwave's second `Steam` action
- [x] `lua/game/item.lua` — `self.tags` field
- [x] `tests/test_item.lua` — tags assertions (`cooked_meat` has
  `Protein`, `raw_meat` has none)

---

#### Wave 1 (parallel)

- [x] Task A — `lua/game/customer.lua`, `tests/test_customer.lua` —
  mechanical rename `requested_type` → `requested_tag` throughout the
  class and its existing tests (field name, `cfg` key, every assertion
  that currently checks `c.requested_type`). No behavioral change; the
  existing test suite in this file should keep testing the exact same
  scenarios, just renamed. Run `love . --headless tests/test_customer.lua`
  and the full suite; report any pre-existing failures in OTHER files
  that reference `requested_type` (there will be some — e.g.
  `test_kitchen_scene.lua` — that's Wave 2's job, not yours; just note
  them, don't fix them).
- [x] Task B — `lua/game/customer_queue.lua`, `tests/test_day_loop.lua` —
  implement the random-tag-selection + `TAG_MESSAGES` + merchant-stock
  broccoli per the contract above. Test: for several draws, every
  produced order config's `requested_tag` is one of the tags actually
  present in `item_defs` (derive the expected set the same way the real
  code does, from `item_defs`, not a hardcoded literal in the test, so
  the test doesn't need updating if a tag is added/removed later); the
  message for a config matches `TAG_MESSAGES[requested_tag]` (or the
  generic fallback pattern if you added a tag with no custom message for
  test purposes); the merchant config's `stock` list contains
  `"broccoli"` in addition to the existing meat items. Run
  `love . --headless tests/test_day_loop.lua` and the full suite; note
  (don't fix) any pre-existing failures elsewhere referencing
  `requested_type`.

#### Wave 2 (sequential, after Wave 1 is fully checked off — integration)

- [x] Task C — `game/scenes/kitchen_scene.lua`, `tests/test_kitchen_scene.lua`
  — read the real `Customer`/`CustomerQueue`/`Item` files Wave 0/1
  produced first, they're authoritative over this checklist's contract
  summary if anything differs. Implement the `has_tag(item, tag)`
  match-check swap in the serve/dismiss branch, and add a raw broccoli or
  two to `on_enter`'s starting layout (verify non-overlap with the
  existing microwave/meat cells via `can_place`, same pattern the
  existing meat placement already uses). Update every test in this file
  that currently references `requested_type`/hardcodes `"cooked_meat"` as
  the expected match (the shared `order_cfg()` helper, and every
  serve/dismiss/rejection-message test built on it) to the new
  `requested_tag`/tag-based shape — check what actually broke by running
  the full suite first, then fix each failure. Add at least one new test
  covering the broccoli path end-to-end: drag broccoli onto the
  microwave (drag-to-insert, already-existing mechanic) or open its panel
  and place it there, click Steam, wait past duration, drag the resulting
  Steamed Broccoli onto a customer requesting `Healthy` — served,
  currency up. Also confirm (via a test) that dropping raw broccoli or
  raw meat directly on any customer is always rejected regardless of
  their requested tag (both now carry zero tags, so this should already
  fall out of the `has_tag` check with no special-casing — the test is
  there to prove it, not to add new logic).

  Run `love . --headless tests/test_kitchen_scene.lua` then the FULL
  suite (`love . --headless`) — must reach 0 failures across all files.
  Paste both outputs in your final report.

---

### Verification (Phase 4, not a checklist task)

- All headless tests green (`love . --headless`)
- Every box above checked
- `README.md` updated if its gameplay description needs the tag system /
  broccoli mentioned (it currently describes the loop at a similar level
  of detail to what's changing here — check current content, use
  judgment)
- If `docs/game-design.md` exists by now (see the still-pending
  `docs/design/project-docs.md` proposal), update its Items/Customers
  sections too; if it doesn't exist yet, skip this — nothing to update
- This checklist archived to `docs/archive/food-tags.md`, design doc
  archived to `docs/archive/design/food-tags.md`
