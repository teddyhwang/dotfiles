return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "RRethy/nvim-base16",
  },
  init = function()
    local base16 = require("base16-colorscheme")
    local setup_colors = require("config.colorscheme")
    setup_colors(base16)
  end,
  config = function()
    local lualine = require("lualine")
    local lualine_theme_base16 = require("lualine.themes.base16")
    local Snacks = require("snacks")

    lualine.setup({
      options = {
        theme = lualine_theme_base16,
        disabled_filetypes = {
          "packer",
          "dbui"
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          {
            "diagnostics",
            symbols = {
              error = " ",
              warn = " ",
              info = " ",
              hint = "",
            },
          },
          { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
          {
            "filename",
            path = 4,
          },
        },
        lualine_x = {
          Snacks.profiler.status(),
          {
            function()
              return require("noice").api.status.command.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.command.has()
            end,
            color = function()
              return { fg = Snacks.util.color("Statement") }
            end,
          },
          {
            function()
              return require("noice").api.status.mode.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.mode.has()
            end,
            color = function()
              return { fg = Snacks.util.color("Constant") }
            end,
          },
          {
            "diff",
            source = function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns then
                return {
                  added = gitsigns.added,
                  modified = gitsigns.changed,
                  removed = gitsigns.removed,
                }
              end
            end,
          },
        },
        lualine_y = {
          { "progress", separator = " ",                  padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          function()
            return " " .. os.date("%R")
          end,
        },
      },
      inactive_sections = {
        lualine_a = {
          {
            "filename",
            path = 1,
            color = "LineNr",
            shorting_target = 0,
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      winbar = {
        lualine_a = {
          {
            "filename",
            path = 1,
            color = "LualineWinbar",
            shorting_target = 0,
            cond = function()
              return not vim.bo.readonly and vim.bo.modifiable and vim.bo.buftype == ""
            end,
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      inactive_winbar = {
        lualine_a = {
          {
            "filename",
            path = 1,
            color = "LineNr",
            shorting_target = 0,
            cond = function()
              return not vim.bo.readonly and vim.bo.modifiable and vim.bo.buftype == ""
            end,
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      extensions = {
        "fzf",
        "nvim-tree",
        "quickfix",
        "man",
      },
    })
  end,
}
