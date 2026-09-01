# Item Graph Viewer

## Goal

A standalone developer tool — a single HTML file openable in any browser — that visualizes every item in `item_defs.lua` as a node graph, showing how items connect through recipes, overnight actions, and garden spreads. Every item is visible, every tag is shown, and edges show the machine/action that transforms one item into another.

## Affected files

- `scripts/item_graph.html` — new file, the entire tool (self-contained HTML + embedded JS/CSS)
- No game code touched.

## What changes

### New file: `scripts/item_graph.html`

A self-contained single-page devtool. The item and recipe data is hard-coded as a JS object (mirroring `item_defs.lua`) and rendered as an interactive force-directed graph using [vis-network](https://visjs.github.io/vis-network/docs/network/) from jsDelivr CDN.

**Nodes** — one per item. Styled by category:
- **Raw ingredients** (raw_chicken, raw_beef, broccoli, potato, onion, egg, milk, chicken, cow, roasted_coffee_bean, water): neutral grey
- **Producers / machines** (microwave, fryer, coffee_machine, meat_machine, pump, coop, incubator, barn, milking_center, cheese_cave, garden, pot, container): blue/teal
- **Cooked / final outputs** (baked_chicken, steak, fried_chicken, steamed_broccoli, baked_potato, fries, blooming_onion, fried_chicken, chicken_soup, onion_soup, boiled_egg, omelette, beef_stew, black_coffee, cheese): warm amber/green

Each node label shows the item's `name`. Hovering shows a tooltip with:
- Item id
- Tags (e.g. `Protein`, `Greasy`)
- Footprint size

**Edges** — directed arrows from ingredient(s) → machine → output(s):
- Recipe edges (instant actions): solid arrow
- Overnight action edges: dashed arrow (with nights label)
- Garden spread: dashed arrow from `garden` to each crop

Edge labels show the machine name (e.g. "Microwave · Cook", "Fryer · Fry", "Overnight x2").

**Sidebar / legend:**
- Color-coded category legend
- List of all tags with a toggle to highlight only items that carry that tag
- "Reset" button to clear filters

**Layout:** Force-directed (physics-based) so clusters form naturally around shared machines. User can drag nodes, zoom, and pan. A "Fix positions" toggle freezes layout once the user is happy.

## What stays the same

- All game Lua code — this tool is read-only and entirely outside the game.
- The `item_defs.lua` source of truth. The HTML will need a manual sync if new items are added; a comment at the top of the data block will say so.

## Open questions

None — scope is clear and fully self-contained.
