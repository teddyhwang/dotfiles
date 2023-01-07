local status, lualine = pcall(require, "lualine")
if not status then
  return
end

local base16 = require("lualine.themes.base16")

lualine.setup({
  options = {
    theme = base16,
  },
})
