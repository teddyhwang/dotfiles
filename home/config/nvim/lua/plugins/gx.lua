return {
  "chrishrb/gx.nvim",
  keys = { { "gx", "<cmd>Browse<cr>", mode = { "n", "x" } } },
  cmd = { "Browse" },
  init = function()
    vim.g.netrw_nogx = 1
  end,
  submodules = false,
  config = function()
    require("gx").setup({
      open_browser_app = "open",
      open_browser_args = { "--background" },
      open_callback = false,
      select_prompt = true,
      handlers = {
        plugin = true,
        github = true,
        brewfile = true,
        package_json = true,
        search = true,
        go = true,
        verdict = {
          name = "verdict_flag", -- set name of handler
          handle = function(mode, line, _)
            local flag = require("gx.helper").find(line, mode, '"(f_.+)"')

            if flag then
              return "https://experiments.shopify.com/flags/" .. flag
            end
          end,
        },
      },
      handler_options = {
        search_engine = "google",
        select_for_search = false,
        git_remotes = { "upstream", "origin" },
        git_remote_push = false,
      },
    })
  end,
}
