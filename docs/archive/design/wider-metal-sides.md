## Goal

Widen the metal side posts in the foreground scene frame (`fg.png`) from ~50 px each to ~200 px each, narrowing the visible customer stage from ~1180 px to ~880 px. The background (`bg.png`) is unchanged.

## Affected files

- `assets/images/scene/fg.png` — the only file modified

## What changes

The `fg.png` is a 1280×360 PNG composited over the background at draw time. It contains:
- Left metal post (~50 px wide, full height)
- Right metal post (~50 px wide, full height)
- Bottom counter/sill spanning full width
- A transparent center window

The metal posts have a vertical ribbed stripe pattern (alternating dark/mid/light-gray columns). The change tiles/extends the existing stripe pattern inward so each side grows to 200 px, making the open window 880 px wide (centered at x=640).

## What stays the same

- `bg.png` is not touched; it will simply be partially covered by the wider sides
- The counter/sill at the bottom is unchanged
- Screen dimensions, `SPLIT_Y`, all Lua code — nothing changes in code
- Customer `target_x` and `exit_x` remain at their current values (customer still walks to center of screen; the wider frame just tightens the aesthetic framing)

## Open questions

None — all answered before writing this doc:
- Side width: 200 px each (4× current)
- Background: leave as-is
