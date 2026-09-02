-- lua/game/data/character_scripts.lua
--
-- Scripted characters: named NPCs with custom dialogue that appear on a
-- trigger and behave like a normal order customer (dialogue, order panel,
-- Serve/Skip) — order_rules/order_item_count/payout are optional; when
-- omitted the customer accepts any single item (no rules) for 0 payout.

return {
    -- Chapter 1: always eligible (empty trigger). Teaches the microwave.
    {
        id               = "guide",
        chapter          = 1,
        trigger          = {},
        slot             = "after_restock",
        no_dismiss       = true,
        name             = "The Guide",
        color            = { 0.4, 0.7, 0.9, 1 },
        messages         = {
            "Welcome! I'm here to show you the ropes.",
            "Click the microwave to cook the raw chicken sitting next to it.",
            "Once it's ready, drag it onto my tray to serve it.",
        },
        after_messages   = { "You've got this. Good luck!" },
        order_rules      = { { kind = "specific", type_id = "baked_chicken" } },
        order_item_count = 1,
        payout           = 0,
    },

    -- Chapter 2: fires once the player has sold at least one fried_chicken.
    -- Teaches the restock merchant.
    {
        id               = "guide",
        chapter          = 2,
        trigger          = { item_sold = "fried_chicken", count = 1 },
        slot             = "after_restock",
        no_dismiss       = true,
        name             = "The Guide",
        color            = { 0.4, 0.7, 0.9, 1 },
        messages         = {
            "Looking good! The restock merchant always visits first —",
            "grab fresh ingredients from their stock panel.",
            "Get me another fried chicken and I'll let you get back to it.",
        },
        after_messages   = { "Keep it up!" },
        order_rules      = { { kind = "specific", type_id = "fried_chicken" } },
        order_item_count = 1,
        payout           = 0,
    },
}
