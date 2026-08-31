## Inventory Size & Customer Traits Checklist

- [x] Task A — `lua/game/config.lua` — Change `GRID_COLS` from 10 to 15; `GRID_ORIGIN_X` auto-recomputes.

- [x] Task B — `lua/game/customer.lua` — Replace `self.requested_tag` field with `self.disliked_tags`, `self.liked_tags`, `self.loved_tags` (tables). Update `show()` to read `cfg.disliked_tags`, `cfg.liked_tags`, `cfg.loved_tags` instead of `cfg.requested_tag`.

- [x] Task C — `lua/game/customer_queue.lua` — Replace `TAG_MESSAGES`, `message_for_tag`, and the `requested_tag` generation in `make_default_cfg()` with three-tier trait assignment (shuffle known tags; take 1–2 for loved, 1–2 for liked, 1 for disliked). Generate a customer message from the loved/liked/disliked tiers.

- [x] Task D — `lua/game/item_panel.lua` — (1) Increase `REMINDER_H` to fit 3 labeled rows (~56 px). (2) Change `_serve_enabled()` to enable when `item.kind == "order"` and exactly 1 item is in the panel (drop the `has_tag` check). (3) Replace the "Order: [tag]" reminder draw with three tier rows (Loved / Liked / Disliked), each showing its tag list. Highlight tier rows when food in panel has a matching tag; dim when no match; neutral when panel is empty.

- [x] Task E — `tests/test_customer.lua` — Update all `show()` call sites that pass `requested_tag` to pass the new trait fields instead; update assertions that check `c.requested_tag`.

- [x] Task F — `tests/test_kitchen_scene.lua` — (1) Update `order_cfg()` to use `loved_tags`/`liked_tags`/`disliked_tags` instead of `requested_tag`. (2) Remove `requested_tag` sanity-check assertions. (3) Rewrite Test 11 (was: wrong item keeps Serve disabled) — now any 1 item enables Serve; test that Serve IS enabled after dragging any item in. (4) Rewrite Test 16 (was: raw items always rejected) — now raw items are also serveable; test that `_serve_enabled()` is true with any item in the panel. Update assertion messages in Tests 1, 4, 15 to reflect tag-agnostic serve.
