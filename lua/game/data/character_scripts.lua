return {
    -- Chapter 1: always eligible (empty trigger)
    {
        id         = "guide",
        chapter    = 1,
        trigger    = {},
        slot       = "after_restock",
        no_dismiss = true,
        name       = "The Guide",
        color      = { 0.4, 0.7, 0.9, 1 },
        messages   = {
            "Welcome! I'm here to show you the ropes.",
            "Click a machine on the counter to cook something.",
            "Once it's ready, drag it onto the customer's tray to serve it.",
        },
        after_messages = { "You've got this. Good luck!" },
    },

    -- Chapter 2: fires once the player has sold at least one fried_chicken
    {
        id         = "guide",
        chapter    = 2,
        trigger    = { item_sold = "fried_chicken", count = 1 },
        slot       = "after_restock",
        no_dismiss = true,
        name       = "The Guide",
        color      = { 0.4, 0.7, 0.9, 1 },
        messages   = {
            "Looking good! The restock merchant always visits first —",
            "grab fresh ingredients from their stock panel.",
            "More programs become available as you earn coin.",
        },
        after_messages = { "Keep it up!" },
    },
}
