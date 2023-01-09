vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true
vim.g.copilot_tab_fallback = ""

local spin = os.getenv("SPIN")

if spin then
  vim.g.copilot_node_command = "node"
else
  vim.g.copilot_node_command = "/opt/homebrew/opt/node@16/bin/node"
end
