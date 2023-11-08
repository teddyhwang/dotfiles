local saga_status, saga = pcall(require, "lspsaga")
local base16_status, base16 = pcall(require, "base16-colorscheme")

if not saga_status then
  return
end

local background

if not base16_status then
  background = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Normal")), "bg#")
else
  local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]
  background = colors.base00
end

saga.setup({
  symbol_in_winbar = {
    enable = false,
    delay = 0,
  },
  finder = {
    keys = {
      toggle_or_open = "<cr>",
    },
  },
  definition = {
    edit = "<cr>",
  },
  ui = {
    border = "single",
    colors = {
      normal_bg = background,
    },
  },
})
