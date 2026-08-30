## Goal

Give the player more than one way to turn a raw ingredient into food, and
introduce a genuine multi-step recipe:

- A **fryer** (new container, like the microwave): potato -> fries.
- The existing **microwave** gains a second potato recipe: potato -> baked
  potato.
- A **dutch oven** (new, movable container): load it with potato + water +
  raw meat, then place the *loaded dutch oven itself* into the microwave and
  press Cook to turn its contents into beef stew.
- **Water** becomes a purchasable ingredient (merchant stock).
- New tags: fries is `Greasy`, baked potato is `Filling`, beef stew is both
  `Filling` and `Protein`.

Per your answer, the dutch oven is a real nested container: it physically
goes inside the microwave's panel (not a standalone "Cook" button of its
own). That is the one non-obvious part of this design - see "Nested
container recipes" below.

## Affected files

- `lua/game/data/item_defs.lua` - new item entries (`potato`, `water`,
  `fries`, `baked_potato`, `dutch_oven`, `beef_stew`, `fryer`); microwave's
  panel grows from 1x1 to 2x1 and gains two more recipes; header comment
  gains a paragraph documenting the new `container` recipe field.
- `lua/game/item.lua` - the recipe engine (`matching_recipe`,
  `Item:start_action`, `complete_action`) learns about "container" recipes:
  a recipe can require a specific container item to be sitting in the
  acting item's panel, check *that container's own panel* against
  `requires`, and read/write produced items there instead of the acting
  item's own panel.
- `lua/game/item_panel.lua` - `is_action_enabled`'s read-only recipe check
  gets the same container-recipe logic (button must light up when a loaded
  dutch oven is sitting in the microwave).
- `game/scenes/kitchen_scene.lua` - the double-click/right-click "open this
  container's panel" gesture currently only looks at the main floor grid;
  it's generalized to look at whichever grid (main floor or any open
  panel's own grid) the click actually landed on, topmost panel first. This
  is what lets you open the dutch oven's panel while it's sitting inside
  the already-open microwave panel (to load it before cooking, and to pull
  the finished beef stew out after). Starting floor layout also gets a
  fryer, a dutch oven, and some potatoes placed down.
- `lua/game/customer_queue.lua` - merchant stock list gains `water` and
  `potato`.
- Tests: `tests/test_item.lua`, `tests/test_item_panel.lua`,
  `tests/test_kitchen_scene.lua` (new coverage below).

## What changes

### New items (`lua/game/data/item_defs.lua`)

```lua
potato = { name = "Potato", footprint = {{0,0}}, color = ... }   -- no tags, raw
water  = { name = "Water",  footprint = {{0,0}}, color = ... }   -- no tags, raw

fries        = { name = "Fries",        footprint = {{0,0}}, color = ..., tags = {"Greasy"} }
baked_potato = { name = "Baked Potato", footprint = {{0,0}}, color = ..., tags = {"Filling"} }
beef_stew    = { name = "Beef Stew",    footprint = {{0,0},{1,0},{2,0}}, color = ..., tags = {"Filling", "Protein"} }

fryer = {
    name = "Fryer",
    footprint = { {0,0}, {1,0}, {0,1}, {1,1} },  -- 2x2, same shape as the microwave
    color = ...,
    has_panel = true,
    panel_cols = 1,
    panel_rows = 1,
    actions = {
        { name = "Fry", duration = 3.0, requires = { potato = 1 }, produces = { fries = 1 } },
    },
},

dutch_oven = {
    name = "Dutch Oven",
    footprint = { {0,0}, {1,0} },   -- 2 wide, 1 tall
    color = ...,
    has_panel = true,
    panel_cols = 3,   -- "inventory of size 3": exactly potato + water + raw meat
    panel_rows = 1,
},
```

`beef_stew`'s 3x1 footprint is sized to exactly fill the dutch oven's 3-slot
panel once the three ingredients are consumed - the finished stew sits
snugly where they were.

### Microwave changes

```lua
microwave = {
    ...,
    panel_cols = 2,  -- was 1; needs to fit the dutch oven's 2-wide footprint
    panel_rows = 1,
    actions = {
        {
            name = "Cook",
            duration = 3.0,
            recipes = {
                { requires = { raw_meat = 1 }, produces = { cooked_meat = 1 } },
                { requires = { broccoli = 1 }, produces = { steamed_broccoli = 1 } },
                { requires = { potato = 1 },   produces = { baked_potato = 1 } },
                {
                    container = "dutch_oven",
                    requires  = { potato = 1, water = 1, raw_meat = 1 },
                    produces  = { beef_stew = 1 },
                },
            },
        },
    },
},
```

Growing the microwave's panel to 2x1 also means it can now physically hold
two 1x1 ingredients at once (previously its 1x1 panel made that
impossible) - e.g. raw meat *and* broccoli together. Per your follow-up,
pressing Cook now fires **every** recipe whose requirements are currently
met, not just the first match: both cook in the same press. This replaces
the old "first satisfied recipe wins" behavior everywhere, not just for
the new 2-slot case.

### Recipe matching: fire every satisfied recipe, plus nested containers (`lua/game/item.lua`)

Two changes to the recipe engine, together:

1. **Multiple recipes per press.** `matching_recipe` (singular) becomes
   `matching_recipes` (plural): it walks `action.recipes` and collects
   *every* recipe currently satisfied, deducting each match's `requires`
   from a running count as it goes so two recipes can't both claim the same
   physical ingredient. All matches fire together when the action's timer
   completes - one Cook press with meat + broccoli in the panel now
   produces both cooked meat and steamed broccoli.
2. **Container recipes.** A recipe can add a `container = "<type_id>"`
   field: it's only satisfied when an item of that type_id is sitting in
   the acting item's panel *and* that item's own panel satisfies
   `requires`. On completion, `requires` are removed from and `produces`
   are placed into the **container item's panel**, not the microwave's -
   the dutch oven itself is never consumed, just its contents.

```lua
-- Returns every recipe on `action` satisfied by panel's contents right now,
-- as a list of { recipe, target_item } - target_item is the matched
-- container instance for a `container` recipe, else nil (meaning "act on
-- panel itself", the existing behavior). Deducts each match's `requires`
-- from a running `counts` copy so two recipes never double-claim the same
-- ingredient; a container recipe's own requirements are checked against
-- (and only ever deducted from) the container's own panel, never `counts`.
local function matching_recipes(action, panel)
    local counts = count_panel_items(panel)
    local matches = {}
    for _, recipe in ipairs(action_recipes(action)) do
        if recipe.container then
            local container_item = find_item_of_type(panel, recipe.container)
            if container_item and satisfies(recipe.requires, count_panel_items(container_item.panel)) then
                matches[#matches + 1] = { recipe = recipe, target_item = container_item }
            end
        elseif satisfies(recipe.requires, counts) then
            matches[#matches + 1] = { recipe = recipe, target_item = nil }
            for type_id, needed in pairs(recipe.requires or {}) do
                counts[type_id] = counts[type_id] - needed
            end
        end
    end
    return matches
end
```

`Item:start_action` stores the whole match list in `action_state`
(`{ running, elapsed, matches }`) instead of a single recipe.
`complete_action` iterates `matches`, applying each one against
`target_item.panel` (falling back to `self.panel` when `target_item` is
nil) for both removing consumed ingredients and placing produced ones,
using the target's own `panel_cols`/`panel_rows` for first-fit placement.

`ItemPanel:is_action_enabled` (its read-only duplicate of this check, used
to light up the button) only needs "at least one match" rather than the
full list, but reuses the same `matching_recipes` logic so it can't drift
out of sync with what Cook will actually do.

### Opening a container's panel from inside another open panel (`kitchen_scene.lua`)

Today, double-click and right-click to open a container's panel only check
`self.grid` (the main floor). To load the dutch oven you'll double-click it
on the floor as usual, but to retrieve the beef stew (or reload the dutch
oven for another batch) once it's sitting inside the *open* microwave
panel, the same gesture needs to work there too.

This generalizes to: check whichever grid the click landed in - main floor
or any currently-open panel's own inner grid, topmost panel first (mirrors
the existing pattern in `_hover_grid`/`_all_grids`) - for a `has_panel`
item, before falling through to that grid's normal drag-start handling.
Nothing about `ItemPanel` windows themselves needs to change - opening a
panel is already just "add another entry to `self.panels`" regardless of
where the item physically sits, so a click deep inside the microwave's
panel correctly pops open a third, independent, draggable window for the
dutch oven.

### Starting layout & merchant stock

- `on_enter`: add a fryer and a dutch oven to the starting floor (placeholder
  cells, non-overlapping with existing items), plus a couple of raw
  potatoes.
- `make_merchant_cfg`'s `stock` list gains `water` and `potato`.

### Tests

- `test_item.lua` - new coverage for container recipes: a dutch oven loaded
  with potato+water+raw_meat inside a microwave's panel, run Cook, assert
  beef_stew ends up in the dutch oven's panel and the microwave's own panel
  is untouched; assert the button/action doesn't fire with an unloaded or
  partially-loaded dutch oven.
- `test_item_panel.lua` - `is_action_enabled` true/false around the same
  loaded/unloaded dutch oven scenarios.
- `test_kitchen_scene.lua` - double-click on an item sitting inside an
  already-open panel's grid opens that item's own panel (new); existing
  main-floor double-click tests keep passing unchanged.

## What stays the same

- `lua/game/grid.lua` - no changes; placing the dutch oven into the
  microwave's panel and dragging beef stew back out are both just ordinary
  `Grid`/first-fit operations on the (now bigger) microwave panel.
- `lua/game/customer.lua`, tag-matching in `kitchen_scene.lua`'s
  `has_tag` - untouched; new tags (`Greasy`, `Filling`) automatically join
  the request pool via `customer_queue.lua`'s existing `known_tags()` scan,
  no code change needed there.
- The single-ingredient recipe pattern (fryer's `Fry`, microwave's existing
  three simple recipes) - unchanged, still flat `requires`/`produces`.

## Open questions

Resolved:
- The dutch oven is a real nested container placed inside the microwave
  (not its own standalone action button) - this is what drives the
  `container` recipe mechanic and the panel-opening generalization above.
- Cook fires every satisfied recipe in one press (multiple ingredients
  cook together), not just the first match.

Still open - flagging assumptions, not blocking:

1. **Dutch oven height** - you said "two units wide"; assuming 1 tall (2x1
   total), since nothing calls out a height and it's the minimum shape that
   still fits inside the resized 2x1 microwave panel.
2. **Fryer footprint** - assumed 2x2, matching the microwave's shape, since
   no size was specified.
3. **Starting floor placement / quantities** for the fryer, dutch oven, and
   potatoes - exact cells aren't load-bearing, just need to not overlap
   existing items.
4. **Beef stew duration** - assumed 3.0s, matching every other Cook recipe.
