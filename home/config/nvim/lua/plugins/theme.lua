return {
  {
    "RRethy/nvim-base16",
    lazy = false,
    priority = 1000,
    config = function()
      local base16 = require("base16-colorscheme")
      local setup_colors = require("config.colorscheme")
      setup_colors(base16)
    end,
  },

  -- Disable LazyVim's default colorscheme
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },
}
