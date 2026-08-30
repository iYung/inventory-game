local config = {}

config.SCREEN_W = 1280
config.SCREEN_H = 720
config.SPLIT_Y  = 360

config.U = 36 -- grid cell size in px

config.GRID_COLS     = 10
config.GRID_ROWS     = 6
config.GRID_ORIGIN_X = (config.SCREEN_W - config.GRID_COLS * config.U) / 2
config.GRID_ORIGIN_Y = config.SPLIT_Y + 12

config.CUSTOMERS_PER_DAY = 3

config.MERCHANT_PANEL_COLS = 3
config.MERCHANT_PANEL_ROWS = 2

config.ORDER_PANEL_COLS = 3
config.ORDER_PANEL_ROWS = 3

config.COLORS = {
    grid_bg     = { 0.16, 0.16, 0.20, 1 },
    grid_cell   = { 0.22, 0.22, 0.27, 1 },
    grid_line   = { 0.30, 0.30, 0.36, 1 },
    stage_bg    = { 0.55, 0.75, 0.85, 1 },
    counter     = { 0.45, 0.32, 0.22, 1 },
    button      = { 0.30, 0.55, 0.30, 1 },
    button_text = { 1, 1, 1, 1 },
    panel_bg     = { 0.10, 0.10, 0.13, 0.95 },
    panel_border = { 0.45, 0.45, 0.55, 1 },
}

return config
