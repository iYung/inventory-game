## Goal

Restyle the customer speech bubble to match the game's existing dark, boxy UI design language instead of the current rounded comic-bubble aesthetic.

## Affected files

- `lua/game/customer.lua` — all bubble drawing logic lives in `Customer:draw_bubble()`

## What changes

- **Shape**: Remove border-radius from the box (`rectangle("fill", ..., 6, 6)` → `rectangle("fill", ...)` with no radius args). Same for the outline call.
- **Colors**: `BUBBLE_BG` stays white `{1.00, 1.00, 1.00, 0.97}`. `BUBBLE_TEXT` stays near-black `{0.08, 0.08, 0.10, 1}`.
- **Outline**: Remove both `love.graphics.rectangle("line", ...)` calls entirely — no border on the bubble box.
- **Tail**: Keep the triangular tail fill, but remove the `polygon("line", ...)` outline draw. Tail stays white, no border.

## What stays the same

- Typewriter reveal logic, wrap/layout math, `bubble_visible()` gating, `PAD`, `MIN_BOX_W`, `MAX_BOX_W`, `BUBBLE_GAP`, `TAIL_H`, draw-order contract with the scene.

## Open questions

None — user confirmed: no outline, boxy (no radius), dark background.
