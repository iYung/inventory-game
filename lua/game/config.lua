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
    grid_bg      = { 0.06, 0.06, 0.08, 1 },
    grid_cell    = { 0.14, 0.14, 0.18, 1 },
    grid_line    = { 0.00, 0.80, 0.80, 1 },  -- bright cyan drop-preview
    stage_bg     = { 0.04, 0.04, 0.06, 1 },
    button       = { 0.10, 0.32, 0.10, 1 },
    button_text  = { 0.40, 1.00, 0.40, 1 },
    panel_bg     = { 0.05, 0.05, 0.07, 0.97 },
    panel_border = { 0.90, 0.82, 0.40, 1 },  -- bright amber
}

return config
