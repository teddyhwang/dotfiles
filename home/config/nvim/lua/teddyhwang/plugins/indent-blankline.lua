local status, ibl = pcall(require, "ibl")
if not status then
  return
end

ibl.setup({
  indent = {
    char = "│",
    highlight = "IblIndent",
  },
  scope = {
    highlight = "IblScope",
  },
})
