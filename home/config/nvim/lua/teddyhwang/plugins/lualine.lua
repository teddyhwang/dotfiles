-- import lualine plugin safely
local status, lualine = pcall(require, "lualine")
if not status then
  return
end

-- get base16 theme
local base16 = require("lualine.themes.base16")

lualine.setup({
  options = {
    theme = base16,
  },
})
