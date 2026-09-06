return {
  {
    "LazyVim",
    opts = {},
    init = function()
      -- Get the relative path of the current buffer
      local function get_relative_path()
        local buf_path = vim.api.nvim_buf_get_name(0)
        if buf_path == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return nil
        end

        -- For sparse checkout, calculate path from the trees/root/src/ directory
        local home = os.getenv("HOME")
        local world_src = home .. "/world/trees/root/src/"

        -- Check if the file is in the sparse checkout directory
        if buf_path:sub(1, #world_src) == world_src then
          -- Remove the world src prefix to get the full repo path
          local relative_path = buf_path:sub(#world_src + 1)
          return relative_path
        end

        -- Fallback to git root if not in sparse checkout
        local root = require("lazyvim.util").root()
        local relative_path = vim.fn.fnamemodify(buf_path, ":." .. root .. ":")
        return relative_path
      end

      -- Open Stewardlens with the current file path
      local function open_stewardlens()
        local relative_path = get_relative_path()
        if not relative_path then
          return
        end

        local encoded_path = vim.uri_encode(relative_path, "rfc3986")
        local url = "https://stewardlens.shopify.io/search?q=" .. encoded_path
        local process, err = vim.ui.open(url)
        if not process then
          vim.notify("Could not open Stewardlens: " .. err, vim.log.levels.ERROR)
          return
        end

        vim.notify("Opening in Stewardlens: " .. relative_path, vim.log.levels.INFO)
      end

      -- Create the command
      vim.api.nvim_create_user_command("StewardlensBrowse", open_stewardlens, {})
    end,
  },
}
