## Goal

Add lightweight reference docs mirroring the useful parts of `../wip`'s
`architecture.md` / `game-design.md` / `coding-notes.md`, sized to what this
project actually needs today (a handful of files, no gameplay economy yet)
rather than copying `../wip`'s exhaustive versions wholesale. Two of the
three should be living documents future features keep in sync, not
one-time snapshots.

## Affected files

- `docs/architecture.md` — new
- `docs/game-design.md` — new
- `docs/coding-notes.md` — new
- `README.md` — add short pointers to the three new docs
- (going forward) `.claude/CLAUDE.md` project instructions — see "What
  stays the same" / open question below on whether Phase 4 (Verification)
  should keep these in sync automatically

## What changes

### Why not just copy `../wip`'s versions

`../wip`'s `architecture.md` is 833 lines — a full per-method API
reference for ~25 classes across camera/sprite/scene infrastructure, six
game items, four scenes, three shaders, and save/settings systems. This
repo currently has 10 core classes, 7 game-logic files, and exactly one
scene, and each of those files already carries a thorough doc-comment
block at its top describing its own API and invariants (you've been
reading them all session — `grid.lua`, `item_panel.lua`, `customer.lua`,
etc. are already close to self-documenting). Reproducing every method
signature in a second place would just be a second thing to keep in sync
for little benefit at this size. Per your answer, `docs/architecture.md`
is the **lighter** version: module responsibilities and how they connect,
not a per-method reference — closer to a map than a manual.

`../wip`'s `game-design.md` documents current mechanics per scene/item
with an Open Questions section, and per your answer this repo should have
the same: right now that information is split between the README's intro
paragraph (terse, by design) and the archived per-feature design docs in
`docs/archive/design/` (accurate for the day they were written, not
maintained afterward — `cooking-inventory-game.md` and `merchant-npc.md`
already read a little stale relative to what actually shipped, e.g. later
fixes like the rejection-message/right-click/drag-to-insert changes aren't
reflected there and were never meant to be — archived docs are a record of
what was designed, not what's current).

`../wip`'s `coding-notes.md` (folder structure, test commands, the Lua
class pattern, `require` conventions, image/data-table conventions) isn't
something you asked about directly, so I'm flagging it as a proposal
rather than assuming: this repo's README already covers folder structure
and test commands (its existing "Structure"/"Running" sections), but
doesn't write down the conventions actually in use — the plain-metatable
class pattern, absolute `require("lua/...")` paths, the
data-driven-item-defs pattern, keeping `love.graphics` calls guarded for
headless safety. Every task agent in every NFF wave this session had to
re-derive these by reading existing files first. Writing them down once
seems worth it given how much of this session was spent doing exactly
that — but tell me if you'd rather skip it.

### `docs/architecture.md`

Structure (module map, not method-by-method):

```
## Core (lua/core/) — engine, no game knowledge
  Sprite / SpriteSet — drawable primitives
  Drawer — priority-ordered draw list
  Camera / Scene / SceneManager — how a scene renders and transitions
  Input / Timer / Fonts — small utilities
## Game logic (lua/game/)
  Grid — generic cell grid (placement, drag, rotate, first-fit); used for
         both the main floor grid and every item's own panel
  Item — footprint/rotation/sprite/optional panel+actions, data-driven via
         data/item_defs.lua
  ItemPanel — draggable popup UI wrapping any {panel, type_id} pair
              (an Item on the floor, or a merchant Customer) — this is
              the reuse seam that let the merchant feature skip building
              new panel/drag code entirely
  Customer — walk-in/wait/talk/walk-out state machine + dialogue bubbles;
             kind == "order" (requests food) or "merchant" (offers stock)
  CustomerQueue / DayState — per-day visitor list and progress/currency
## Scene (game/scenes/kitchen_scene.lua)
  Owns the main Grid, DayState/CustomerQueue, the one on-stage Customer,
  and any number of open ItemPanels; routes all mouse/keyboard input
## Data flow diagram: main.lua -> SceneManager -> KitchenScene -> {Grid,
  Customer, ItemPanel...} -> Item -> item_defs (one direction each way)
## Headless testing
  lua/headless/{stubs,input,runner}.lua — how `love . --headless` works
```

Pulled from what's already spread across file headers and this session's
own design docs, condensed — not new invention.

### `docs/game-design.md`

```
## Overview — what the game is, current loop
## Grid Inventory — footprints, rotation, drag/drop, first-fit insertion
## Items — raw_meat, cooked_meat, microwave (+ Cook action); how to add one
## Customers — order flow, dialogue/typewriter, serve/dismiss, walk timing
## Merchant — stock panel, Leave, no economy yet
## Day Loop — CUSTOMERS_PER_DAY, Next Day gating (must fully leave first)
## Controls — click/drag/rotate, double-click or right-click opens a panel
## Open Questions — e.g. no currency spend yet, no more item/recipe
  variety yet, single customer on stage at a time by design or temporary
```

This is the one meant to be **kept current** — the next feature's design
doc should update the relevant section here instead of only living in
`docs/archive/design/`.

### `docs/coding-notes.md` (proposed — confirm or skip)

```
## Folder Structure — short, points to README for the full tree
## Running Tests — love . / love . --headless / --visual
## Lua Class Pattern — the setmetatable(self, Class); Class.__index = Class
  pattern every class in this repo uses, verbatim example
## Conventions — require("lua/...") absolute-from-root paths; no external
  deps; guard love.graphics calls for headless safety; plain-color
  Sprites (no image assets yet)
## Data-Driven Items — how data/item_defs.lua entries work, how to add one
```

### `README.md`

Add one line each pointing to the three docs, near the existing
`docs/setup-cloudflare.md` link — no restructuring of what's already
there.

## What stays the same

- The per-file doc-comments already in every `.lua` file — these new docs
  summarize/link, they don't replace them
- `docs/archive/design/*` — untouched, still the historical record of each
  feature's original design
- README's existing Structure/Running/Web build/CI sections

## Open questions

1. `coding-notes.md` — add it, or skip per the reasoning above?
2. Should **Phase 4 (Verification)** of future NFF runs update
   `game-design.md` (and `architecture.md`/`coding-notes.md` when
   structurally relevant) as part of its existing "update affected
   READMEs" duty, so they actually stay current? Proposing yes — otherwise
   these end up the same kind of stale snapshot as the archived design
   docs, just with extra steps. If yes, I'll note this in these docs
   themselves so a future agent knows to update them without being told.
