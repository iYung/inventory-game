## Customer Speech Bubble Checklist

- [x] Task A — `lua/game/customer.lua` — Remove border-radius from the box rectangle (change `love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 6, 6)` to no radius args), remove both `love.graphics.rectangle("line", ...)` outline calls, and remove the `love.graphics.polygon("line", ...)` tail outline call
