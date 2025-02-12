local M = {}

function M.smart_swap(direction)
  local current_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(current_win)

  vim.cmd("wincmd " .. direction)
  local target_win = vim.api.nvim_get_current_win()

  if current_win ~= target_win then
    local current_buf = vim.api.nvim_win_get_buf(current_win)
    local target_buf = vim.api.nvim_win_get_buf(target_win)

    vim.api.nvim_win_set_buf(current_win, target_buf)
    vim.api.nvim_win_set_buf(target_win, current_buf)
  else
    vim.api.nvim_set_current_win(current_win)
    vim.cmd("close")

    if direction == "h" then
      vim.cmd("topleft vsplit")
    elseif direction == "l" then
      vim.cmd("botright vsplit")
    elseif direction == "k" then
      vim.cmd("topleft split")
    else
      vim.cmd("botright split")
    end

    vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
  end
end

return M
