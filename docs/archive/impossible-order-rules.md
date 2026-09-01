## Impossible Order Rules Checklist

- [x] Task A — `lua/game/order_gen.lua` — In `build_rules`, change `constrained[tag] = kind` to `constrained[tag] = true` and update the candidate filter from `constrained[tag] ~= kind` to `not constrained[tag]`, so any tag that already has a rule is excluded from further selection.

- [x] Task B — `lua/game/order_gen.lua` — In `is_satisfiable`, add a cross-rule pre-pass before the existing checks: group rules by tag; return false if any tag has both an `at_least` and a `no` rule, or has `at_least n` and `no_more m` with `n > m`.

- [x] Task C — `tests/test_order_gen.lua` — Add a test that directly calls `OrderGen.generate` many times across all day brackets with a fully-unlocked ProgramState and asserts no generated rule set contains a tag with both `at_least` and `no`, or `at_least n` and `no_more m` where `n > m`.
