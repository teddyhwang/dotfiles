local ssh_client = os.getenv("SSH_CLIENT")

if ssh_client then
  vim.cmd("source ~/.vim/remote.vim")
end
