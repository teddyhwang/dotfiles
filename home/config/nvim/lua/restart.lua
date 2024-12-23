local M = {}

function M.ibl()
  require("ibl").setup()
end

function M.lualine()
  local lualine = require("lualine")
  package.loaded["lualine.themes.base16"] = nil
  local lualine_theme_base16 = require("lualine.themes.base16")
  lualine.setup({
    options = {
      theme = lualine_theme_base16,
    },
  })
end

return M
