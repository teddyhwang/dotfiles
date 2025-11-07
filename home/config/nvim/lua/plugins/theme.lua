return {
  {
    "tinted-theming/tinted-nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local tinted = require("tinted-colorscheme")
      local setup_colors = require("config.colorscheme")

      tinted.setup()
      setup_colors(tinted.colors)
    end,
  },
  -- Disable LazyVim's default colorscheme
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },
}
