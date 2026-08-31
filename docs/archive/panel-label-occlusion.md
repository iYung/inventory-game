## Panel Label Occlusion Checklist

- [x] Fix hover suppression — `game/scenes/kitchen_scene.lua` — In `KitchenScene:mouse_moved`, after the existing no-drag forwarding block (`self.grid:mouse_moved` + panel loop), add a second pass: walk `self.panels` back-to-front to find the topmost panel whose backdrop covers `(x, y)`. If found, call `self.grid:clear_hover()` and call `panel.item.panel:clear_hover()` for every panel below it in the stack. Leave the topmost covering panel's inner grid alone — its hover is already correct.
