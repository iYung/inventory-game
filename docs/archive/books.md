## Books Checklist

- [x] Task A — `scripts/gen_icons.py`, `assets/images/items/garden_book.png`, `assets/images/items/microwave_book.png` — Add `gen_garden_book` and `gen_microwave_book` icon generators (32×32, 3-shade rule; open-book shape in green and steel-grey palettes respectively); run the script to emit both PNGs

- [x] Task B — `scripts/gen_book_pages.py` (new), `assets/images/books/garden_book.png`, `assets/images/books/microwave_book.png` — Write a new Python/Pillow script that generates 160×120 placeholder panel-content images (green garden scene for garden_book; grey kitchen scene for microwave_book) and run it to emit both PNGs; create the `assets/images/books/` directory

- [x] Task C — `lua/game/data/item_defs.lua` — Add `book` (sentinel, no footprint), `garden_book` (green, 1×1, `has_book_panel=true`, `book_image="garden_book"`), and `microwave_book` (steel-grey, 1×1, `has_book_panel=true`, `book_image="microwave_book"`) entries

- [x] Task D — `lua/game/data/program_defs.lua` — Append `"garden_book"` to `garden.extras` and `"microwave_book"` to `pump_microwave.extras`

- [x] Task E — `lua/game/book_panel.lua` (new) — Implement `BookPanel`: title bar (draggable, with close button setting `should_close`), body that loads and draws `assets/images/books/<def.book_image>.png` centered (falls back to solid-color rect if file absent); implements same public interface as `ItemPanel` (`new`, `_point_in_bg`, `_point_in_grid` always false, `mouse_pressed`, `mouse_moved`, `mouse_released`, `draw`); `should_leave/serve/skip` always false; never touches `item.panel`

- [x] Task F — `game/scenes/kitchen_scene.lua` — (1) In `_try_double_click_open`: extend the `def.has_panel` check to also match `def.has_book_panel`, and open `BookPanel.new(item)` via `_open_or_focus_panel` in that branch; (2) In `_open_container_at`: same extension; (3) In `_all_grids`: skip nil `panel.item.panel`; (4) In `_dragging_grid`: guard `panel.item.panel` before accessing `.dragging`; (5) Update `_open_or_focus_panel` (or its call site) to construct `BookPanel` when `def.has_book_panel`, `ItemPanel` otherwise
