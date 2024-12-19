local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local default_theme = "base16-seti"

local function get_tinty_theme()
  local theme_name = vim.fn.system("tinty current &> /dev/null && tinty current")

  if vim.v.shell_error ~= 0 then
    return default_theme
  else
    return vim.trim(theme_name)
  end
end

local function handle_custom_highlights()
  local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]
  local highlights = {
    WilderAccent = { fg = colors.base0E },
    IblIndent = { fg = colors.base01, blend = 50 },
    IblScope = { fg = colors.base03, blend = 10 },
    HighlightedyankRegion = { link = "MatchParen" },
    Tabline = { bg = colors.base01, fg = colors.base05 },
    TabLineFill = { bg = colors.base00 },
    TabLineSel = { bg = colors.base02, fg = colors.base06 },
    TabLineSeparatorSel = { fg = colors.base03, bg = colors.base02 },
    TabLineSeparator = { fg = colors.base02, bg = colors.base01 },
    TabLineIconSel = { fg = colors.base06, bg = colors.base02 },
    TabLineIcon = { fg = colors.base04, bg = colors.base01 },
    TabLineModifiedSel = { fg = colors.base0B, bg = colors.base02 },
    TabLineModified = { fg = colors.base0B, bg = colors.base01 },
    TabLineCloseSel = { fg = colors.base06, bg = colors.base02 },
    TabLineClose = { fg = colors.base04, bg = colors.base01 },
    LineNr = { fg = colors.base03 },
    VertSplit = { link = "LineNr" },
    WinSeparator = { fg = colors.base03 },
    Pmenu = { bg = colors.base00, fg = colors.base05 },
    PmenuSel = { link = "TabLineSel" },
    PmenuThumb = { bg = colors.base0E, fg = colors.base02 },
    PmenuSbar = { bg = colors.base03 },
    WilderBorder = { link = "VertSplit" },
    LualineWinbar = { bg = colors.base00, fg = colors.base07 },
    FzfLuaBackdrop = { bg = colors.base00 },
    FzfLuaBorder = { link = "VertSplit" },
    FzfLuaScrollBorderFull = { link = "PmenuThumb" },
  }

  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

local function handle_focus_gained()
  local new_theme_name = get_tinty_theme()
  local current_theme_name = vim.g.colors_name

  if current_theme_name ~= new_theme_name then
    vim.cmd("colorscheme " .. new_theme_name)
    handle_custom_highlights()
    require("ibl").setup()
    require("teddyhwang.plugins.lualine").refresh()
  end
end

local function main()
  vim.o.termguicolors = true
  vim.g.tinted_colorspace = 256
  local current_theme_name = get_tinty_theme()

  vim.cmd("colorscheme " .. current_theme_name)

  vim.api.nvim_create_autocmd("FocusGained", {
    callback = handle_focus_gained,
  })

  handle_custom_highlights()
end

main()
