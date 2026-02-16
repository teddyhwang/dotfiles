return {
  {
    "tinted-theming/tinted-nvim",
    lazy = false,
    priority = 1000,
    config = function()
      local tinted = require("tinted-nvim")
      local setup_colors = require("config.colorscheme")

      tinted.setup({
        selector = {
          enabled = true,
          mode = "file",
          watch = true,
        },
      })
      setup_colors(tinted.get_palette())
    end,
  },
  -- Disable LazyVim's default colorscheme
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },
}
