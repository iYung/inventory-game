-- lua/game/data/item_defs.lua
-- Data-driven item type definitions, keyed by type id string.
--
-- Shape per entry:
--   { name, footprint, color, has_panel, panel_cols, panel_rows, actions, tags }
--
-- `footprint` is the item's *unrotated* base footprint: a list of {dx, dy}
-- integer cell offsets relative to the item's anchor cell.
--
-- `actions` (only present on containers) is a list of:
--   { name, requires = {type_id = count, ...}, produces = {type_id = count, ...}, duration }
-- A container can have more than one independently-named action (e.g. the
-- microwave's Cook and Steam) - each just needs requirements a different
-- ingredient satisfies; no other code changes needed to add a new recipe.
--
-- `tags` (optional, default none) is a list of strings a customer's
-- requested_tag can match against (see lua/game/item.lua's Item.tags and
-- game/scenes/kitchen_scene.lua's has_tag). By design, raw/unprepared
-- items carry no tags - only something you've actually cooked does, so a
-- tag request can never be satisfied by handing over a raw ingredient.

local item_defs = {
    raw_meat = {
        name = "Raw Meat",
        footprint = { { 0, 0 } },
        color = { 0.75, 0.25, 0.25, 1 },
    },

    cooked_meat = {
        name = "Cooked Meat",
        footprint = { { 0, 0 } },
        color = { 0.55, 0.36, 0.20, 1 },
        tags = { "Protein" },
    },

    broccoli = {
        name = "Broccoli",
        footprint = { { 0, 0 } },
        color = { 0.30, 0.55, 0.20, 1 },
    },

    steamed_broccoli = {
        name = "Steamed Broccoli",
        footprint = { { 0, 0 } },
        color = { 0.45, 0.75, 0.30, 1 },
        tags = { "Healthy" },
    },

    -- Never placed via Item.new/on a Grid - used only by ItemPanel's title
    -- bar / def lookup for a merchant-kind Customer (see lua/game/customer.lua).
    merchant = {
        name = "Merchant",
    },

    microwave = {
        name = "Microwave",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color = { 0.55, 0.55, 0.60, 1 },
        has_panel = true,
        panel_cols = 1,
        panel_rows = 1,
        actions = {
            {
                name = "Cook",
                requires = { raw_meat = 1 },
                produces = { cooked_meat = 1 },
                duration = 3.0,
            },
            {
                name = "Steam",
                requires = { broccoli = 1 },
                produces = { steamed_broccoli = 1 },
                duration = 3.0,
            },
        },
    },
}

return item_defs
