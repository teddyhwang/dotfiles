local status, lualine = pcall(require, "lualine")
if not status then
  return
end

local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

local lualine_theme_base16 = require("lualine.themes.base16")

lualine.setup({
  options = {
    theme = lualine_theme_base16,
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
        color = { bg = colors.base00, fg = colors.base07 },
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
