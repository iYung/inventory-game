## Reject Container Serve Checklist

- [x] Task A — `lua/game/item_panel.lua` — In `_serve_enabled()`, after the `#panel_items ~= 1` check, add `return #panel_items[1].tags > 0` so only tagged (cooked) food enables Serve.
- [x] Task B — `tests/test_item_panel.lua` — Add tests: (1) a pot placed in the order panel does NOT enable Serve, (2) a tagless raw item does NOT enable Serve, (3) a tagged cooked food item DOES enable Serve.
