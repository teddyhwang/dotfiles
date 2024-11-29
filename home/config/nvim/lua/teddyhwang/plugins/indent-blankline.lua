local status, ibl = pcall(require, "ibl")
if not status then
  return
end

local base16_status, base16 = pcall(require, "base16-colorscheme")
if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

vim.api.nvim_set_hl(0, "IblIndent", { fg = colors.base01, blend = 50 })
vim.api.nvim_set_hl(0, "IblScope", { fg = colors.base03, blend = 10 })

ibl.setup({
  indent = {
    char = "│",
    highlight = "IblIndent",
  },
  scope = {
    highlight = "IblScope",
  },
})
