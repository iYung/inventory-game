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
--   { name, duration, requires = {type_id = count, ...}, produces = {type_id = count, ...} }
-- or, for one button that handles more than one ingredient (e.g. the
-- microwave's single "Cook" button working for both raw meat and
-- broccoli):
--   { name, duration, recipes = { { requires = {...}, produces = {...} }, ... } }
-- start_action fires every recipe in `recipes` whose requires is currently
-- satisfied by the panel's contents (not just the first match); add a new
-- recipe to grow what a button handles, no other code changes needed.
--
-- A recipe may also carry a `container = "<type_id>"` field. Such a recipe
-- is only satisfied when an item of that type_id is sitting in the acting
-- item's own panel AND that item's own panel satisfies `requires`. On
-- completion, `requires` is removed from and `produces` is placed into the
-- **container item's panel**, not the acting item's panel - the container
-- itself is never consumed, just its contents. See lua/game/item.lua's
-- `matching_recipes` for the implementation.
--
-- `tags` (optional, default none) is a list of strings a customer's
-- requested_tag can match against (see lua/game/item.lua's Item.tags and
-- game/scenes/kitchen_scene.lua's has_tag). By design, raw/unprepared
-- items carry no tags - only something you've actually cooked does, so a
-- tag request can never be satisfied by handing over a raw ingredient.

local item_defs = {
    raw_chicken = {
        name = "Raw Chicken",
        footprint = { { 0, 0 } },
        color = { 0.75, 0.25, 0.25, 1 },
    },

    raw_beef = {
        name = "Raw Beef",
        footprint = { { 0, 0 } },
        color = { 0.65, 0.15, 0.15, 1 },
    },

    baked_chicken = {
        name = "Baked Chicken",
        footprint = { { 0, 0 } },
        color = { 0.55, 0.36, 0.20, 1 },
        tags = { "Protein" },
    },

    steak = {
        name = "Steak",
        footprint = { { 0, 0 } },
        color = { 0.55, 0.25, 0.12, 1 },
        tags = { "Protein" },
    },

    fried_chicken = {
        name = "Fried Chicken",
        footprint = { { 0, 0 } },
        color = { 0.88, 0.65, 0.20, 1 },
        tags = { "Greasy", "Protein" },
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

    -- Never placed via Item.new/on a Grid - used only by ItemPanel's title
    -- bar / def lookup for an order-kind Customer (see lua/game/customer.lua).
    order_customer = {
        name = "Customer",
    },

    microwave = {
        name = "Microwave",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color = { 0.55, 0.55, 0.60, 1 },
        has_panel = true,
        panel_cols = 2,
        panel_rows = 1,
        actions = {
            {
                name = "Cook",
                duration = 3.0,
                recipes = {
                    { requires = { raw_chicken = 1 }, produces = { baked_chicken = 1 } },
                    { requires = { raw_beef = 1 },    produces = { steak = 1 } },
                    { requires = { broccoli = 1 }, produces = { steamed_broccoli = 1 } },
                    { requires = { potato = 1 },   produces = { baked_potato = 1 } },
                    {
                        container = "pot",
                        requires  = { water = 1, raw_chicken = 1 },
                        produces  = { chicken_soup = 1 },
                    },
                    {
                        container = "pot",
                        requires  = { water = 1, onion = 1 },
                        produces  = { onion_soup = 1 },
                    },
                    {
                        container = "pot",
                        requires  = { water = 1, egg = 1 },
                        produces  = { boiled_egg = 1 },
                    },
                    {
                        container = "pot",
                        requires  = { water = 1, potato = 1, raw_beef = 1 },
                        produces  = { beef_stew = 1 },
                    },
                },
            },
        },
    },

    potato = {
        name = "Potato",
        footprint = { { 0, 0 } },
        color = { 0.85, 0.75, 0.55, 1 },
    },

    water = {
        name = "Water",
        footprint = { { 0, 0 } },
        color = { 0.40, 0.65, 0.90, 1 },
    },

    fries = {
        name = "Fries",
        footprint = { { 0, 0 } },
        color = { 0.95, 0.75, 0.25, 1 },
        tags = { "Greasy" },
    },

    baked_potato = {
        name = "Baked Potato",
        footprint = { { 0, 0 } },
        color = { 0.70, 0.55, 0.35, 1 },
        tags = { "Filling" },
    },

    beef_stew = {
        name = "Beef Stew",
        footprint = { { 0, 0 }, { 1, 0 }, { 2, 0 } },
        color = { 0.60, 0.40, 0.25, 1 },
        tags = { "Filling", "Protein" },
    },

    chicken_soup = {
        name = "Chicken Soup",
        footprint = { { 0, 0 } },
        color = { 0.70, 0.50, 0.30, 1 },
        tags = { "Protein", "Hearty" },
    },

    onion = {
        name  = "Onion",
        footprint = { {0,0} },
        color = { 0.90, 0.75, 0.40, 1 },
    },

    blooming_onion = {
        name  = "Blooming Onion",
        footprint = { {0,0} },
        color = { 0.80, 0.60, 0.25, 1 },
        tags  = { "Greasy" },
    },

    onion_soup = {
        name  = "Onion Soup",
        footprint = { {0,0} },
        color = { 0.75, 0.55, 0.25, 1 },
        tags  = { "Hearty" },
    },

    boiled_egg = {
        name = "Boiled Egg",
        footprint = { { 0, 0 } },
        color = { 0.95, 0.90, 0.75, 1 },
        tags = { "Protein" },
    },

    chicken = {
        name     = "Chicken",
        footprint = { { 0, 0 } },
        color    = { 0.72, 0.55, 0.30, 1 },
    },

    cow = {
        name     = "Cow",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color    = { 0.45, 0.28, 0.15, 1 },
    },

    egg = {
        name     = "Egg",
        footprint = { { 0, 0 } },
        color    = { 0.95, 0.92, 0.80, 1 },
    },

    coop = {
        name      = "Coop",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color     = { 0.55, 0.42, 0.25, 1 },
        has_panel  = true,
        panel_cols = 2,
        panel_rows = 2,
        overnight_actions = {
            -- preserve = true: chicken stays in the coop, only the egg is added.
            { requires = { chicken = 1 }, produces = { egg = 1 }, nights = 1, preserve = true },
        },
    },

    meat_machine = {
        name      = "Meat Machine",
        footprint = { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
        color     = { 0.40, 0.40, 0.45, 1 },
        has_panel  = true,
        panel_cols = 2,
        panel_rows = 2,
        actions = {
            {
                name     = "Process",
                duration = 1.0,
                recipes  = {
                    { requires = { chicken = 1 }, produces = { raw_chicken = 2 } },
                    { requires = { cow = 1 },     produces = { raw_beef = 4 } },
                },
            },
        },
    },

    incubator = {
        name      = "Incubator",
        footprint = { { 0, 0 } },
        color     = { 0.65, 0.75, 0.60, 1 },
        has_panel  = true,
        panel_cols = 1,
        panel_rows = 1,
        overnight_actions = {
            { requires = { egg = 1 }, produces = { chicken = 1 }, nights = 2 },
        },
    },

    fryer = {
        name = "Fryer",
        footprint = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
        color = { 0.35, 0.35, 0.40, 1 },
        has_panel = true,
        panel_cols = 1,
        panel_rows = 1,
        actions = {
            {
                name = "Fry",
                duration = 3.0,
                recipes = {
                    { requires = { potato = 1 },     produces = { fries = 1 } },
                    { requires = { onion = 1 },      produces = { blooming_onion = 1 } },
                    { requires = { raw_chicken = 1 }, produces = { fried_chicken = 1 } },
                },
            },
        },
    },

    pump = {
        name      = "Pump",
        footprint = { {0,0}, {0,1} },
        color     = { 0.35, 0.55, 0.75, 1 },
        has_panel  = true,
        panel_cols = 1,
        panel_rows = 1,
        actions = {
            {
                name     = "Pump",
                duration = 1.0,
                produces = { water = 1 },
            },
        },
    },

    garden = {
        name      = "Garden",
        footprint = {
            {0,0},{1,0},{2,0},
            {0,1},{1,1},{2,1},
            {0,2},{1,2},{2,2},
        },
        color     = { 0.25, 0.48, 0.18, 1 },
        has_panel  = true,
        panel_cols = 3,
        panel_rows = 3,
        garden_spread = { "onion", "broccoli", "potato" },
    },

    pot = {
        name = "Pot",
        footprint = { { 0, 0 }, { 1, 0 } },
        color = { 0.25, 0.25, 0.30, 1 },
        has_panel = true,
        panel_cols = 3,
        panel_rows = 1,
        -- No `actions` field: the pot is never clicked/cooked directly -
        -- see the microwave's `container` recipe above.
    },
}

return item_defs
