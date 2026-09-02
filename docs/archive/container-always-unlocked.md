## Container Always Unlocked Checklist

- [x] Task A — `lua/game/data/program_defs.lua` — add a `container` entry with `id = "container"`, `name = "Container"`, `machines = { "container" }`, `extras = {}`, `inputs = {}`, `tags_unlocked = {}`, `requires = {}`
- [x] Task B — `lua/game/program_state.lua` — update `ProgramState.new` to accept either a string or a list of strings as `starting`; if string, own it; if table, own each id in the list
- [x] Task C — `game/scenes/kitchen_scene.lua` — change `ProgramState.new("fryer")` to `ProgramState.new({ "fryer", "container" })`
- [x] Task D — `tests/test_program_state.lua` — add a test covering `ProgramState.new({ "fryer", "container" })` owning both at start; verify existing single-string tests still pass
