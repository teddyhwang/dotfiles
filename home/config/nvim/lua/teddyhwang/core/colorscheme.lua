local set_theme_path = "$HOME/.config/tinted-theming/set_theme.lua"
local is_set_theme_file_readable = vim.fn.filereadable(vim.fn.expand(set_theme_path)) == 1 and true or false
local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

if is_set_theme_file_readable then
  vim.cmd("let base16colorspace=256")
  vim.cmd("source " .. set_theme_path)
end

local highlights = {
  HighlightedyankRegion = { link = "MatchParen" },
  Tabline = { bg = colors.base00, fg = colors.base05 },
  TabLineSel = { bg = colors.base02, fg = colors.base06 },
  LineNr = { fg = colors.base03 },
  VertSplit = { link = "LineNr" },
  WinSeparator = { fg = colors.base03 },
  TelescopePromptNormal = { bg = colors.base01 },
  TelescopePromptPrefix = { bg = colors.base01 },
  TelescopePromptBorder = { link = "LineNr" },
  TelescopeTitle = { fg = colors.base04 },
  TelescopePromptTitle = { link = "TelescopeTitle" },
  TelescopeResultsTitle = { link = "TelescopeTitle" },
  TelescopePreviewTitle = { link = "TelescopeTitle" },
}

for k, v in pairs(highlights) do
  vim.api.nvim_set_hl(0, k, v)
end
