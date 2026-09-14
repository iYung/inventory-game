# Book Panel Image Scaling

## Goal

Book panels should size themselves to match the actual pixel dimensions of their content image rather than always displaying at a hardcoded 160×120 area. This lets future book images of any size display at 1:1 fidelity without manual constant updates.

## Affected files

- `lua/game/book_panel.lua` — only file that needs changes
- `tests/test_book_panel.lua` — dimension assertions need updating

## What changes

### `lua/game/book_panel.lua`

**Remove hardcoded `IMG_W` / `IMG_H` constants** (currently `160` / `120`). They are module-level locals used in three places: `bg_w`/`bg_h` calculation, the draw scale factors, and the fallback rectangle. Each is handled differently:

1. **Image loaded successfully** — after `pcall(love.graphics.newImage, ...)` succeeds, read the image's natural dimensions:
   ```lua
   self._img_w = self._image:getWidth()
   self._img_h = self._image:getHeight()
   ```
   Compute `bg_w` and `bg_h` from those values. Draw the image unscaled (`sx = 1, sy = 1`, i.e. omit the scale args to `love.graphics.draw`).

2. **No image (fallback)** — keep the fallback rectangle at the current 160×120 defaults. Introduce a `FALLBACK_W = 160` / `FALLBACK_H = 120` pair (replacing the removed `IMG_W`/`IMG_H`) used only in this path, so the constant's purpose is clear.

   `bg_w` and `bg_h` are set from these fallback values when `self._image` is nil.

3. **`_layout`** — no change needed; it only uses `self.bg_w` / `self.bg_h` which are already dynamic.

4. **`draw`** — replace `IMG_W / iw` / `IMG_H / ih` scale computation with unscaled draw (or explicit `1, 1`).

### `tests/test_book_panel.lua`

Test 7 hard-asserts `bg.w == 160 + 16*2` and `bg.h == 28 + 16 + 120 + 16`. These values remain correct for the current book images (which are 160×120), but the assertion comment and values should reference the actual image dimensions (160, 120) rather than the removed `IMG_W`/`IMG_H` constants, to make the intent clear to future readers.

## What stays the same

- Panel layout logic (`_layout`, margin, title bar, close button) — unchanged
- Drag, hit-test, mouse interaction — unchanged
- Fallback solid-color rectangle size — stays 160×120
- `MARGIN`, `TITLE_H`, `CLOSE_SIZE`, `CLOSE_GAP` constants — unchanged
- All existing tests continue to pass (current images are 160×120, so dimensions don't change)

## Open questions

None — resolved before doc was written:
- Sizing rule: exact pixel dimensions (1:1), no max cap
- Fallback size: keep 160×120
