local saga_status, saga = pcall(require, "lspsaga")
local base16_status, base16 = pcall(require, "base16-colorscheme")

if not saga_status then
  return
end

if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

saga.setup({
  definition = {
    edit = "<cr>",
  },
  ui = {
    colors = {
      normal_bg = colors.base00,
    },
  },
})
