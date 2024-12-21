local ssh_client = os.getenv("SSH_CLIENT")

if ssh_client then
  vim.keymap.set('n', '<leader>p', function()
    populate_paste_buffer_from_osx()
  end, { silent = true })

  vim.keymap.set('n', '<leader>y', function()
    propagate_paste_buffer_to_osx()
  end, { silent = true })

  function propagate_paste_buffer_to_osx()
    local clipboard_content = vim.fn.getreg("*")
    vim.fn.system('pbcopy-remote', clipboard_content)
    vim.api.nvim_echo({{
      "clipboard sent", "Normal"
    }}, false, {})
  end

  function populate_paste_buffer_from_osx()
    local remote_content = vim.fn.system('pbpaste-remote')
    vim.fn.setreg('+', remote_content)
    vim.api.nvim_echo({{
      "clipboard received", "Normal"
    }}, false, {})
  end
end
