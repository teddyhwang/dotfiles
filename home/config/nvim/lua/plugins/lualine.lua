return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local colors = require("tinted-nvim").get_palette()

      local theme = {
        normal = {
          a = { fg = colors.base00, bg = colors.base0D, gui = "bold" },
          b = { fg = colors.base05, bg = colors.base02 },
          c = { fg = colors.base04, bg = colors.base01 },
        },
        insert = {
          a = { fg = colors.base00, bg = colors.base0B, gui = "bold" },
        },
        visual = {
          a = { fg = colors.base00, bg = colors.base0E, gui = "bold" },
        },
        replace = {
          a = { fg = colors.base00, bg = colors.base08, gui = "bold" },
        },
        command = {
          a = { fg = colors.base00, bg = colors.base0A, gui = "bold" },
        },
        inactive = {
          a = { fg = colors.base03, bg = colors.base01 },
          b = { fg = colors.base03, bg = colors.base01 },
          c = { fg = colors.base03, bg = colors.base01 },
        },
      }

      opts.options = opts.options or {}
      opts.options.theme = theme
      return opts
    end,
  },
}
