local fn = vim.fn
local cmd = vim.cmd
local set_theme_path = "$HOME/.config/tinted-theming/set_theme.lua"
local is_set_theme_file_readable = fn.filereadable(fn.expand(set_theme_path)) == 1 and true or false
local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

if is_set_theme_file_readable then
  cmd("let base16colorspace=256")
  cmd("source " .. set_theme_path)
end
cmd("highlight link HighlightedyankRegion MatchParen")
cmd(
  "hi TabLine gui=NONE guibg="
    .. colors.base00
    .. " guifg="
    .. colors.base05
    .. " cterm=NONE term=NONE ctermfg=black ctermbg=white"
)
cmd(
  "hi TabLineSel gui=NONE guibg="
    .. colors.base02
    .. " guifg="
    .. colors.base06
    .. " cterm=NONE term=NONE ctermfg=green ctermbg=black"
)
vim.api.nvim_set_hl(0, "LineNr", { fg = colors.base03 })
