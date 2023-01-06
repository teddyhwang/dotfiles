vim.g.fzf_layout = {
  ["window"] = {
    ["width"] = 1,
    ["height"] = 0.4,
    ["yoffset"] = 1,
    ["border"] = "horizontal",
  },
}

local function search()
  local search = vim.fn.input("Search: ")
  if search ~= "" then
    vim.cmd(string.format(":Rg %s", search))
  end
end

vim.keymap.set("n", "<C-f>", search, { noremap = true })
