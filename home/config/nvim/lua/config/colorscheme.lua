-- Auto-reload colorscheme from tinty

-- Default colorscheme: base16-seti
-- base00 = '#151718', base01 = '#282a2b', base02 = '#3b758c', base03 = '#41535b',
-- base04 = '#43a5d5', base05 = '#d6d6d6', base06 = '#eeeeee', base07 = '#ffffff',
-- base08 = '#cd3f45', base09 = '#db7b55', base0A = '#e6cd69', base0B = '#9fca56',
-- base0C = '#55dbbe', base0D = '#55b5db', base0E = '#a074c4', base0F = '#8a553f'

return function(colors)
  local handle_custom_highlights = function()
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
      -- Blink.cmp highlights
      BlinkCmpMenu = { bg = colors.base00, fg = colors.base05 },
      BlinkCmpMenuBorder = { link = "FloatBorder" },
      BlinkCmpMenuSelection = { bg = colors.base02, fg = colors.base06 },
      BlinkCmpLabel = { fg = colors.base05 },
      BlinkCmpLabelMatch = { fg = colors.base0D, bold = true },
      BlinkCmpKind = { link = "@text" },
      BlinkCmpDoc = { bg = colors.base00, fg = colors.base05 },
      BlinkCmpDocBorder = { link = "BlinkCmpMenuBorder" },
      FloatBorder = { link = "VertSplit" },
      HighlightedyankRegion = { bg = colors.base03 },
      WinSeparator = { fg = colors.base03 },
      MatchParen = { bg = colors.base02 },
      -- Fix lualine section backgrounds to use StatusLine bg
      StatusLine = { bg = colors.base01, fg = colors.base04 },
      lualine_c_normal = { bg = colors.base01 },
      lualine_c_insert = { bg = colors.base01 },
      lualine_c_visual = { bg = colors.base01 },
      lualine_c_replace = { bg = colors.base01 },
      lualine_c_command = { bg = colors.base01 },
      lualine_c_inactive = { bg = colors.base01 },
      -- Sidekick NES (Next Edit Suggestions)
      SidekickSign = { fg = colors.base0C, bold = true },
      SidekickDiffAdd = { bg = "NONE", fg = colors.base04, italic = true, blend = 30 },
      SidekickDiffDelete = { bg = colors.base01, fg = colors.base03, strikethrough = true },
      SidekickDiffContext = { bg = "NONE", fg = colors.base03 },
    }

    for k, v in pairs(highlights) do
      vim.api.nvim_set_hl(0, k, v)
    end
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "TintedColorsPost",
    callback = function()
      local tinted = require("tinted-colorscheme")
      colors = tinted.colors
      handle_custom_highlights()
    end,
  })

  handle_custom_highlights()
end
