require("fzf-lua").setup({ fzf_colors = true })
local M = {}

function M.switch_windows()
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
  if vim.startswith(prompt_path, home) then
    prompt_path = "~" .. prompt_path:sub(#home + 1)
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local full_path = vim.api.nvim_buf_get_name(buf)
    if full_path ~= "" then
      local relative_path = full_path
      if vim.startswith(full_path, root) then
        relative_path = full_path:sub(#root + 2)
      end

      local icon = require("nvim-web-devicons").get_icon(
        relative_path,
        vim.fn.fnamemodify(relative_path, ":e"),
        { default = true }
      )

      table.insert(windows, {
        name = string.format("%s %s", icon, relative_path),
        win_id = win,
      })
    end
  end

  local function switch_to_files()
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
      header = ":: <ctrl-f> to switch to all files",
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

return M
