local status, lualine = pcall(require, "lualine")
if not status then
  return
end

local base16 = require("lualine.themes.base16")

lualine.setup({
  options = {
    theme = base16,
    disabled_filetypes = {
      "packer",
    },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { "filename" },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
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
        color = { bg = "#000", fg = "#fff" },
        shorting_target = 0,
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
