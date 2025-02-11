local M = {}

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
  local Snacks = require("snacks")
  require("bufferline").setup({
    options = {
      close_command = function(n)
        Snacks.bufdelete(n)
      end,
      right_mouse_command = function(n)
        Snacks.bufdelete(n)
      end,
      tab_size = 30,
      themable = true,
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level)
        local icon = level:match("error") and " " or " "
        return " " .. icon .. count
      end,
      offsets = {
        {
          filetype = "snacks_layout_box",
        },
      },
    },
  })
end

return M
