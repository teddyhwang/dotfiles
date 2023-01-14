local saga_status, saga = pcall(require, "lspsaga")
if not saga_status then
  return
end

local background = vim.cmd("echo synIDattr(synIDtrans(hlID('Cursor')), 'fg#')")

saga.setup({
  definition = {
    edit = "<cr>",
  },
  ui = {
    colors = {
      normal_bg = background,
    },
  },
})
