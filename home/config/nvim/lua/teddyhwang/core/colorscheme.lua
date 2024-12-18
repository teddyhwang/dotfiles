local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

local highlights = {
  HighlightedyankRegion = { link = "MatchParen" },
  Tabline = { bg = colors.base00, fg = colors.base05 },
  TabLineSel = { bg = colors.base02, fg = colors.base06 },
  LineNr = { fg = colors.base03 },
  VertSplit = { link = "LineNr" },
  WinSeparator = { fg = colors.base03 },
}

for k, v in pairs(highlights) do
  vim.api.nvim_set_hl(0, k, v)
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

local function handle_focus_gained()
  local new_theme_name = get_tinty_theme()
  local current_theme_name = vim.g.colors_name

  if current_theme_name ~= new_theme_name then
    vim.cmd("colorscheme " .. new_theme_name)
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
end

main()
