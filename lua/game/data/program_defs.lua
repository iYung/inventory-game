-- lua/game/data/program_defs.lua
--
-- Static definitions for every purchasable production program.
--
-- Fields per entry:
--   id            string   unique program identifier
--   name          string   display name
--   cost          number   currency cost (used for first purchase and repurchase)
--   machines      list     type_ids of machines that define program completion;
--                          all must be dragged to the floor to complete the program
--   extras        list     additional items shown alongside machines in the program
--                          merchant panel, purchasable at flat cost (RESTOCK_ITEM_COST);
--                          do NOT count toward program completion
--   inputs        list     ingredient type_ids this program's machines consume;
--                          used by RestockGen to build the daily restock pool
--   tags_unlocked list     tag strings that become producible once this program
--                          is owned; used by OrderGen's available_tags
--   requires      list     program ids that must be owned before this one is offered

local program_defs = {

    fryer = {
        id            = "fryer",
        name          = "Fryer",
        cost          = 30,
        machines      = { "fryer" },
        extras        = { "raw_chicken", "raw_chicken", "potato", "onion" },
        inputs        = { "raw_chicken", "potato", "onion" },
        tags_unlocked = { "Greasy", "Protein" },
        requires      = {},
    },

    garden = {
        id            = "garden",
        name          = "Garden",
        cost          = 25,
        machines      = { "garden" },
        extras        = { "onion", "broccoli", "potato" },
        inputs        = { "onion", "broccoli", "potato" },
        tags_unlocked = {},
        requires      = { "fryer" },
    },

    pump_microwave = {
        id            = "pump_microwave",
        name          = "Pump & Microwave",
        cost          = 50,
        machines      = { "pump", "microwave" },
        extras        = {},
        inputs        = { "raw_chicken", "potato", "water" },
        tags_unlocked = { "Filling", "Protein" },
        requires      = { "fryer" },
    },

    pot = {
        id            = "pot",
        name          = "Pot",
        cost          = 30,
        machines      = { "pot" },
        extras        = {},
        inputs        = { "broccoli", "onion", "raw_chicken", "egg", "water" },
        tags_unlocked = { "Healthy", "Veggie", "Hearty" },
        requires      = { "pump_microwave" },
    },

    coop = {
        id            = "coop",
        name          = "Coop",
        cost          = 40,
        machines      = { "coop" },
        extras        = { "chicken", "chicken" },
        inputs        = { "chicken" },
        tags_unlocked = {},
        requires      = { "pot" },
    },

    incubator = {
        id            = "incubator",
        name          = "Incubator",
        cost          = 35,
        machines      = { "incubator" },
        extras        = { "egg", "egg" },
        inputs        = { "egg" },
        tags_unlocked = {},
        requires      = { "coop" },
    },

    meat_machine = {
        id            = "meat_machine",
        name          = "Meat Machine",
        cost          = 60,
        machines      = { "meat_machine" },
        extras        = {},
        inputs        = { "chicken", "cow" },
        tags_unlocked = {},
        requires      = { "pump_microwave" },
    },

    barn = {
        id            = "barn",
        name          = "Barn",
        cost          = 70,
        machines      = { "barn" },
        extras        = { "cow", "cow" },
        inputs        = { "cow" },
        tags_unlocked = {},
        requires      = { "meat_machine" },
    },

    milking_center = {
        id            = "milking_center",
        name          = "Milking Center",
        cost          = 55,
        machines      = { "milking_center" },
        extras        = {},
        inputs        = { "cow" },
        tags_unlocked = {},
        requires      = { "barn" },
    },

    cheese_cave = {
        id            = "cheese_cave",
        name          = "Cheese Cave",
        cost          = 45,
        machines      = { "cheese_cave" },
        extras        = { "milk", "milk" },
        inputs        = { "milk" },
        tags_unlocked = {},
        requires      = { "milking_center" },
    },

    coffee_machine = {
        id            = "coffee_machine",
        name          = "Coffee Machine",
        cost          = 65,
        machines      = { "coffee_machine" },
        extras        = { "coffee_bean", "coffee_bean" },
        inputs        = { "coffee_bean", "water" },
        tags_unlocked = { "Caffeine", "Bitter" },
        requires      = { "pump_microwave" },
    },
}

return program_defs
