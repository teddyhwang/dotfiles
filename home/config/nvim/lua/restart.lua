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
  package.loaded["bufferline"] = nil
  local Snacks = require("snacks")
  local bufferline = require("bufferline")
  local groups = require("bufferline.groups")

  bufferline.setup({
    options = {
      close_command = function(n)
        Snacks.bufdelete(n)
      end,
      right_mouse_command = function(n)
        Snacks.bufdelete(n)
      end,
      tab_size = 30,
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
      style_preset = bufferline.style_preset.slant,
      groups = {
        options = {
          toggle_hidden_on_enter = true,
        },
        items = {
          groups.builtin.ungrouped,
          {
            name = "Ruby",
            auto_close = false,
            matcher = function(buf)
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf.id })
              return filetype == "ruby"
            end,
            separator = {
              style = groups.separator.slant,
            },
          },
          {
            name = "TS/JS",
            auto_close = false,
            matcher = function(buf)
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf.id })
              return filetype == "typescript" or filetype == "javascript"
            end,
            separator = {
              style = groups.separator.slant,
            },
          },
          {
            name = "Tests",
            -- BufferLineCycleNext/Prev doesn't descend into closed groups
            -- https://github.com/akinsho/bufferline.nvim/issues/980
            auto_close = false,
            separator = {
              style = groups.separator.slant,
            },
            matcher = function(buf)
              local full_path = vim.api.nvim_buf_get_name(buf.id)
              local filename = full_path:match(".*/(.*)$") or full_path
              return filename:match("%_test") or filename:match("%_spec")
            end,
          },
          {
            name = "GraphQL",
            auto_close = false,
            matcher = function(buf)
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf.id })
              return filetype == "graphql"
            end,
            separator = {
              style = groups.separator.slant,
            },
          },
          {
            name = "Data",
            auto_close = false,
            matcher = function(buf)
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf.id })
              return filetype == "json" or filetype == "yaml"
            end,
            separator = {
              style = groups.separator.slant,
            },
          },
          {
            name = "Docs",
            auto_close = false,
            matcher = function(buf)
              local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf.id })
              return filetype == "text" or filetype == "markdown"
            end,
            separator = {
              style = groups.separator.slant,
            },
          },
        },
      },
    },
  })
end

return M
