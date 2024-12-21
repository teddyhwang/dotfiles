local ssh_client = os.getenv("SSH_CLIENT")

if ssh_client then
  local propagate_paste_buffer_to_osx = function()
    local clipboard_content = vim.fn.getreg("*")
    vim.fn.system("pbcopy-remote", clipboard_content)
    vim.api.nvim_echo({ {
      "clipboard sent",
      "Normal",
    } }, false, {})
  end

  local populate_paste_buffer_from_osx = function()
    local remote_content = vim.fn.system("pbpaste-remote")
    vim.fn.setreg("+", remote_content)
    vim.api.nvim_echo({ {
      "clipboard received",
      "Normal",
    } }, false, {})
  end

  vim.keymap.set("n", "<leader>p", function()
    populate_paste_buffer_from_osx()
  end, { silent = true })

  vim.keymap.set("n", "<leader>y", function()
    propagate_paste_buffer_to_osx()
  end, { silent = true })
end
