local M = {}

function M.fzf_switch()
  local fzf = require("fzf-lua")
  local builtin = require("fzf-lua.previewer.builtin")
  local windows = {}

  local IconStripPreviewer = builtin.buffer_or_file:extend()

  function IconStripPreviewer:new(o, opts, fzf_win)
    IconStripPreviewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, IconStripPreviewer)
    return self
  end

  function IconStripPreviewer:parse_entry(entry_str)
    local path = entry_str:match("[^ ]+ (.*)")
    return {
      path = path,
      line = 1,
      col = 1,
    }
  end

  local root = vim.fn.getcwd()

  local prompt_path = root
  local home = os.getenv("HOME")
  if prompt_path and home and vim.startswith(prompt_path, home) then
    prompt_path = "~" .. prompt_path:sub(#home + 1)
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local full_path = vim.api.nvim_buf_get_name(buf)
    if full_path ~= "" then
      local relative_path = full_path
      if full_path and root and vim.startswith(full_path, root) then
        relative_path = full_path:sub(#root + 2)
      end

      local icon, highlight_group = require("nvim-web-devicons").get_icon(
        relative_path,
        vim.fn.fnamemodify(relative_path, ":e"),
        { default = true }
      )

      local icon_color = nil
      if highlight_group then
        local hl = vim.api.nvim_get_hl(0, { name = highlight_group })
        if hl.fg then
          icon_color = string.format("#%06x", hl.fg)
        end
      end

      table.insert(windows, {
        name = "  " .. (icon_color and string.format(
          "\x1b[38;2;%d;%d;%dm%s\x1b[0m",
          tonumber(icon_color:sub(2, 3), 16),
          tonumber(icon_color:sub(4, 5), 16),
          tonumber(icon_color:sub(6, 7), 16),
          icon
        ) .. " " .. relative_path or icon .. " " .. relative_path),
        win_id = win,
      })
    end
  end

  local switch_to_files = function()
    local last_query = require("fzf-lua").get_last_query()
    fzf.files({
      prompt = prompt_path .. "/",
      query = last_query,
    })
  end

  fzf.fzf_exec(
    vim.tbl_map(function(w)
      return w.name
    end, windows),
    {
      prompt = prompt_path .. "/",
      title = "Switch Windows",
      header = ":: <ctrl-f> to \x1b[34mswitch to all files\x1b[0m",
      actions = {
        ["default"] = function(selected)
          if #selected == 0 then
            switch_to_files()
            return
          end

          local win = vim.tbl_filter(function(w)
            return w.name == selected[1]
          end, windows)[1]
          vim.api.nvim_set_current_win(win.win_id)
        end,
        ["ctrl-f"] = switch_to_files,
      },
      previewer = IconStripPreviewer,
      preview = {
        title = "File Preview",
        border = "rounded",
      },
    }
  )
end

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
