-- Auto-reload colorscheme from tinty
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

      -- Trigger ColorScheme autocmd for LazyVim
      vim.cmd("doautocmd ColorScheme")
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
