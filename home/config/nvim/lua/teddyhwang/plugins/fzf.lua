vim.g.fzf_layout = {
  ["window"] = {
    ["width"] = 1,
    ["height"] = 0.4,
    ["yoffset"] = 1,
    ["border"] = "horizontal",
  },
}

local function search()
  local search_input = vim.fn.input("Search: ")
  if search_input ~= "" then
    vim.cmd(string.format(":Rg %s", search_input))
  end
end

vim.keymap.set("n", "<C-f>", search, { noremap = true })
