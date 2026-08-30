# love-exemplar

A Love2D cooking-inventory game. Customers arrive one at a time up top requesting
a food item; you drag and rotate ingredients and appliances around a grid
inventory on the bottom half, run timed actions in containers like the
microwave (double-click it to open its sub-inventory panel), and serve
customers by dropping a matching item on them. One visitor per day is a
merchant instead of a food order — click them to open their stock panel and
drag free items into your grid, then click "Leave" to send them off. Once
everyone for the day is served, a "Next Day" button appears to advance.

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
assets/              Images and other assets
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
