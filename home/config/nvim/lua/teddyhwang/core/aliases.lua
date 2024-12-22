local command_aliases = {
  WQ = "wq",
  Wq = "wq",
  Wa = "wa",
  W = "w",
  Q = "q",
  Qa = "qa",
  Ex = "Oil %:p:h",
  Vs = "vs",
  Vex = "vs | Oil %:p:h",
  VEx = "vs | Oil %:p:h",
  Se = "sp | Oil %:p:h",
  Sex = "sp | Oil %:p:h",
  SEx = "sp | Oil %:p:h",
  Tabe = "tabe",
  Fzf = "FloatermNew fzf",
  Irb = "FloatermNew irb",
  Lazygit = "FloatermNew lazygit",
  Node = "FloatermNew node",
  Python = "FloatermNew python",
  Yazi = "FloatermNew yazi",
  Terminal = "FloatermNew",
}

for alias, cmd in pairs(command_aliases) do
  vim.api.nvim_create_user_command(alias, cmd, {})
end
