local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.window_decorations = "RESIZE"

config.font = wezterm.font("MesloLGL Nerd Font")

return config
