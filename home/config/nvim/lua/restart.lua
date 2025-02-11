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

function M.bufferline()
  require("bufferline").setup({
    options = {
      tab_size = 30,
      themable = true,
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level)
        local icon = level:match("error") and " " or " "
        return " " .. icon .. count
      end,
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          text_align = "left",
          separator = true
        }
      },
    },
  })
end

return M
