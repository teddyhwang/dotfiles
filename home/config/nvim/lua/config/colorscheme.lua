-- base08: red
-- base09: orange
-- base0A: yellow
-- base0B: green
-- base0C: cyan
-- base0D: blue
-- base0E: purple
-- base0F: brown
-- base00: darkest black (default background)
-- base01: darker gray
-- base02: dark gray
-- base03: gray
-- base04: light gray
-- base05: lighter gray
-- base06: very light gray
-- base07: white

return function(base16)
  local default_theme = "base16-seti"

  local get_tinty_theme = function()
    local theme_name = vim.fn.system("tinty current &> /dev/null && tinty current")

    if vim.v.shell_error ~= 0 then
      return default_theme
    else
      return vim.trim(theme_name)
    end
  end

  local handle_custom_highlights = function()
    local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]
    local highlights = {
      ["@symbol"] = { fg = colors.base09 },
      ["@variable"] = { fg = colors.base08 },
      ["@variable.member"] = { fg = colors.base08 },
      ["@function"] = { fg = colors.base08 },
      ["@keyword"] = { fg = colors.base0E },
      ["@property"] = { fg = colors.base08 },
      ["@parameter"] = { fg = colors.base08 },
      TSFuncMacro = { link = "TSString" },
      TSType = { fg = colors.base0A },
      TSNamespace = { fg = colors.base0A },
      Identifier = { fg = colors.base08 },
      LineNr = { fg = colors.base03 },
      Pmenu = { bg = colors.base00, fg = colors.base05 },
      PmenuSbar = { bg = colors.base03, fg = colors.base03 },
      PmenuSel = { bg = colors.base02, fg = colors.base06 },
      PmenuThumb = { bg = colors.base02, fg = colors.base02 },
      VertSplit = { link = "LineNr" },

      CmpItemAbbr = { fg = colors.base05 },
      CmpItemAbbrMatch = { fg = colors.base0D, bold = true },
      CmpItemAbbrMatchFuzzy = { link = "CmpItemAbbrMatch" },
      CmpItemKind = { link = "@text" },
      CmpItemKindClass = { link = "@type" },
      CmpItemKindConstant = { link = "@constant" },
      CmpItemKindEnum = { link = "@type" },
      CmpItemKindFile = { link = "Directory" },
      CmpItemKindFolder = { link = "Directory" },
      CmpItemKindFunction = { link = "@function" },
      CmpItemKindInterface = { link = "@interface" },
      CmpItemKindKeyword = { link = "@keyword" },
      CmpItemKindMethod = { link = "@method" },
      CmpItemKindModule = { link = "@namespace" },
      CmpItemKindProperty = { link = "@property" },
      CmpItemKindSnippet = { link = "@text" },
      CmpItemKindText = { link = "@text" },
      CmpItemKindUnit = { link = "@constant" },
      CmpItemKindValue = { link = "@constant" },
      CmpItemKindVariable = { link = "@variable" },
      FloatBorder = { link = "VertSplit" },
      FzfLuaBackdrop = { bg = colors.base00 },
      FzfLuaBorder = { link = "VertSplit" },
      FzfLuaScrollBorderFull = { link = "PmenuThumb" },
      HighlightedyankRegion = { link = "MatchParen" },
      IblIndent = { fg = colors.base01, blend = 50 },
      IblScope = { fg = colors.base03, blend = 10 },
      LualineWinbar = { bg = colors.base00, fg = colors.base07 },
      TabLineClose = { fg = colors.base04, bg = colors.base01 },
      TabLineCloseSel = { fg = colors.base06, bg = colors.base02 },
      TabLineFill = { bg = colors.base00 },
      TabLineIcon = { fg = colors.base04, bg = colors.base01 },
      TabLineIconSel = { fg = colors.base06, bg = colors.base02 },
      TabLineModified = { fg = colors.base0B, bg = colors.base01 },
      TabLineModifiedSel = { fg = colors.base0B, bg = colors.base02 },
      TabLineSel = { link = "PmenuSel" },
      TabLineSeparator = { fg = colors.base02, bg = colors.base01 },
      TabLineSeparatorSel = { fg = colors.base03, bg = colors.base02 },
      Tabline = { bg = colors.base01, fg = colors.base05 },
      WilderAccent = { fg = colors.base0E },
      WilderBorder = { link = "VertSplit" },
      WinSeparator = { fg = colors.base03 },
    }

    for k, v in pairs(highlights) do
      vim.api.nvim_set_hl(0, k, v)
    end
  end

  local handle_focus_gained = function()
    local new_theme_name = get_tinty_theme()
    local current_theme_name = vim.g.colors_name

    if current_theme_name ~= new_theme_name then
      vim.cmd("colorscheme " .. new_theme_name)
      handle_custom_highlights()
      local restart = require("restart")
      restart.ibl()
      restart.lualine()
    end
  end

  vim.o.termguicolors = true
  vim.g["tinted_colorspace"] = 256
  local current_theme_name = get_tinty_theme()

  vim.cmd("colorscheme " .. current_theme_name)

  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
    callback = handle_focus_gained,
  })

  handle_custom_highlights()
end
