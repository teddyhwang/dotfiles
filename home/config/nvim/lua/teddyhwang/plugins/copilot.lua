local spin = os.getenv("SPIN")

if spin then
  vim.g.copilot_node_command = "node"
else
  vim.g.copilot_node_command = "/opt/homebrew/opt/node@16/bin/node"
end
