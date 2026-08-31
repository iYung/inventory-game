# love-exemplar

A Love2D cooking-inventory game. Customers arrive one at a time up top
requesting a food *tag/category* (e.g. "something with protein") rather than
a specific item; you drag and rotate ingredients and appliances around a grid
inventory on the bottom half, run timed actions in containers like the
microwave and fryer (double-click a container to open its sub-inventory
panel), and serve customers by clicking a waiting order customer to open
their order panel, dragging the item carrying their requested tag into its
3x3 grid, and pressing **Serve** (enabled only once the grid holds exactly
one matching item) — or press **Skip** to send them away empty-handed,
which returns any item(s) in the grid to your floor inventory. Pressing a
container's action button fires every recipe its
panel's contents currently satisfy, not just one — so raw chicken and potato
dropped in together both cook from a single press. The microwave alone
handles raw chicken -> Protein-tagged baked chicken, raw beef -> Protein-tagged steak,
and potato -> Filling-tagged baked potato;
the fryer turns potato into Greasy-tagged fries, onion into Greasy-tagged blooming onion, and
raw chicken into Greasy-and-Protein-tagged fried chicken.
A **pump** (1×2) has a 1×1 panel and a "Pump" button that produces one water
per press, no ingredients required; if the panel is already full the action
runs but produces nothing.
A **pot** is a movable container in
its own right: load it with water + an ingredient, then place the loaded pot itself inside the microwave's panel
and press Cook to turn its contents into: water + broccoli -> Healthy-tagged steamed broccoli;
water + raw chicken -> Protein-and-Hearty-tagged chicken soup; water + onion -> Hearty-tagged onion soup;
water + egg -> Protein-tagged boiled egg; water + potato + raw beef -> Filling-and-Protein-tagged beef stew.
All outputs land in the pot's own panel without consuming the pot. You can
also load the pot after it is already inside the open microwave panel by dropping
ingredients directly onto it there (provided the microwave is not running).
Two **gardens** (3×3 each) sit on the kitchen floor. Each garden has a 3×3
panel where you can place onions and broccoli; every night, each occupied
cell spreads to its orthogonal empty neighbors so your supply grows
automatically overnight.
A **container** (2×2) has a 6×6 internal storage panel — purely passive, no actions. Use it to organize items on the floor grid.
A **barn** (3×3) has a 6×6 panel for housing cows — for every 2 cows inside,
one new cow is born overnight (cows are never consumed). A **coop** (2×2)
produces one egg per night for each chicken inside it — chickens are residents,
not consumed. An **incubator** (1×1) takes one egg and hatches it into a
chicken after two nights; removing the egg resets progress. A **meat machine**
(3×2) has a "Process" button that converts a chicken into 2 raw chicken, or a
cow (2×2) into 4 raw beef, on demand. One visitor per day
is a merchant instead of a food order — click them to open their stock panel
and drag free items (including water and potato) into your grid, then click
"Leave" to send them off. Once everyone for the day is served, a "Next Day"
button appears. Clicking it shows a **Day Summary** overlay listing every item sold that day,
total revenue, and customers served. Click "Start Day N+1 →" to advance.

## Structure

```
lua/core/           Engine classes — no game knowledge (Camera, Drawer, Input, Scene,
                     SceneManager, Sprite, SpriteSet, Timer, Fonts)
lua/game/           Game logic — grid inventory, items, customers, day loop
  config.lua         Shared constants (grid cell size, screen split line, colors)
  grid.lua           Generic cell grid: occupancy, placement/collision, drag, rotate
  item.lua           Base grid item: footprint/rotation, sprite, sub-inventory panel, timed actions
  item_panel.lua      Popup sub-inventory panel (panel grid + action buttons/progress)
  customer.lua        Walk-in/wait/talk/walk-out state machine + dialogue bubbles
  customer_queue.lua  Per-day customer list/spawning
  day_state.lua       Day number, customers served/total, currency
  data/item_defs.lua  Data-driven item type definitions (footprint, actions, etc.)
game/scenes/         Scene(s) built on lua/core (kitchen_scene.lua — the only scene)
lua/headless/        Headless test infrastructure (stubs, HeadlessInput, runner)
tests/               Test files — run with: love . --headless
assets/images/
  scene/bg.png       1280×360 Oregon Trail-style food-cart scene background
  customer.png        48×72 px pixel-art customer sprite (drawn at 2× in-engine)
  merchant.png        48×72 px pixel-art merchant sprite
  items/              Per-item icon PNGs
scripts/
  gen_scene_art.py   Regenerates all scene/character PNGs (requires Pillow): python3 scripts/gen_scene_art.py
  gen_icons.py       Generates item icon PNGs
conf.lua             Window config; suppresses graphics/audio modules under --headless
main.lua             Entry point — canvas rendering with letterboxing, pixel-art filter, mouse/keyboard wiring
```

## Running

```bash
love .                  # normal window
love . --headless       # run tests and exit
```

## Web build

```bash
npm install
bash scripts/build_web.sh   # outputs to web/
```

`APP_TITLE` env var overrides the browser tab title (default: `"Love Exemplar"`).

## CI / Cloudflare Pages

Two GitHub Actions workflows are included:

- **`ci.yml`** — runs `love . --headless` on every push and PR
- **`web.yml`** — builds the web output and deploys to Cloudflare Pages

To activate the web deploy, see [`docs/setup-cloudflare.md`](docs/setup-cloudflare.md). In short, set these in your GitHub repository settings:

| Type | Name | Value |
|------|------|-------|
| Secret | `CLOUDFLARE_API_TOKEN` | your Cloudflare API token |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | your Cloudflare account ID |
| Variable | `CLOUDFLARE_PROJECT_NAME` | your Cloudflare Pages project name |
| Variable | `APP_TITLE` | browser tab title (optional) |

PR previews are deployed automatically and linked in a PR comment. Production deploys on push to `master`.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame. See `tests/test_basics.lua` for a minimal example.
