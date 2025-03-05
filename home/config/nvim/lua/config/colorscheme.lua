-- Seti
-- base00 = '#151718', base01 = '#282a2b', base02 = '#3b758c', base03 = '#41535b',
-- base04 = '#43a5d5', base05 = '#d6d6d6', base06 = '#eeeeee', base07 = '#ffffff',
-- base08 = '#cd3f45', base09 = '#db7b55', base0A = '#e6cd69', base0B = '#9fca56',
-- base0C = '#55dbbe', base0D = '#55b5db', base0E = '#a074c4', base0F = '#8a553f'

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
      Title = { fg = colors.base09 },
      SnacksPickerInputBorder = { link = "Title" },
      TSFuncMacro = { link = "TSString" },
      TSType = { fg = colors.base0A },
      TSNamespace = { fg = colors.base0A },
      Identifier = { fg = colors.base08 },
      LineNr = { fg = colors.base03 },
      Pmenu = { bg = colors.base00, fg = colors.base05 },
      PmenuSbar = { bg = colors.base03, fg = colors.base03 },
      PmenuSel = { bg = colors.base02, fg = colors.base06 },
      PmenuThumb = { bg = colors.base09, fg = colors.base09 },
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
      CmpGhostText = { link = "NonText" },
      FloatBorder = { link = "VertSplit" },
      BlinkCmpMenuBorder = { link = "FloatBorder" },
      BlinkCmpDocBorder = { link = "BlinkCmpMenuBorder" },
      HighlightedyankRegion = { bg = colors.base03 },
      LualineWinbar = { bg = colors.base00, fg = colors.base07 },
      WinSeparator = { fg = colors.base03 },
      MatchParen = { bg = colors.base02 },
      BufferLineTabSelected = { link = "BufferLineBufferSelected" },
      ToggleTerm1FloatBorder = { link = "FloatBorder" },
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
      restart.lualine()
      restart.bufferline()
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
