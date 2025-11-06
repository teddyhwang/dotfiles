-- Yazi file manager integration with file selection callback
local M = {}

function M.open()
  local bufpath = vim.fn.expand("%:p:h")
  local dir = bufpath ~= "" and bufpath or vim.fn.getcwd()

  local augroup = vim.api.nvim_create_augroup("YaziFileSelect", { clear = true })
  vim.api.nvim_create_autocmd("TermClose", {
    group = augroup,
    pattern = "*",
    callback = function()
      local file = io.open("/tmp/yazi-selection", "r")
      if file then
        local selected = file:read("*l")
        file:close()
        os.remove("/tmp/yazi-selection")
        if selected and selected ~= "" then
          vim.schedule(function()
            vim.cmd("edit " .. vim.fn.fnameescape(selected))
          end)
        end
      end
      vim.api.nvim_del_augroup_by_name("YaziFileSelect")
    end,
    once = true,
  })

  require("snacks").terminal.open("yazi --chooser-file=/tmp/yazi-selection", {
    win = { style = "float" },
    cwd = dir,
  })
end

return M
