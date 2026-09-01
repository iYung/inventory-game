## Goal

Prevent the customer from being served a container item (pot, fryer, etc.) or raw ingredient. `_serve_enabled()` currently only checks that exactly one item is in the order panel, with no check that the item is actually cooked food.

## Affected files

- `lua/game/item_panel.lua` — `_serve_enabled()` gets a tags-present guard
- `tests/test_item_panel.lua` — new tests asserting Serve is disabled when the panel holds a container or tagless item, and enabled when it holds a tagged food item

## What changes

`ItemPanel:_serve_enabled()` currently:

```lua
function ItemPanel:_serve_enabled()
    if self.item.kind ~= "order" then return false end
    return #self.item.panel:items() == 1
end
```

It will also require the sole item to have at least one tag (`#item.tags > 0`). Only cooked/processed food carries tags; containers (pot, fryer, …) and raw ingredients (raw_chicken, broccoli, …) have none:

```lua
function ItemPanel:_serve_enabled()
    if self.item.kind ~= "order" then return false end
    local panel_items = self.item.panel:items()
    if #panel_items ~= 1 then return false end
    return #panel_items[1].tags > 0
end
```

A container or raw ingredient sitting in the order panel is allowed to remain there (the drop is not blocked); only Serve is disabled, keeping the button greyed out until proper food is placed.

## What stays the same

- Drop mechanics — containers and raw ingredients can still be dragged into the customer panel; only Serve is blocked.
- The Serve button's draw path (already reads `_serve_enabled()` for its color, no draw change needed).

## Open questions

None.
