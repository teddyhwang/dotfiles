local treesiter_configs_status, treesitter_configs = pcall(require, "nvim-treesitter.configs")
if not treesiter_configs_status then
  return
end

local treesitter_parsers_status, treesitter_parsers = pcall(require, "nvim-treesitter.parsers")
if not treesitter_parsers_status then
  return
end

treesitter_configs.setup({
  highlight = {
    enable = true,
  },
  indent = { enable = true },
  autotag = { enable = true },
  matchup = { enable = true },
  ensure_installed = {
    "bash",
    "css",
    "dockerfile",
    "gitignore",
    "graphql",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "python",
    "ruby",
    "svelte",
    "tsx",
    "typescript",
    "vim",
    "yaml",
  },
  auto_install = true,
  textobjects = {
    lsp_interop = {
      enable = true,
      border = "none",
      floating_preview_opts = {},
      peek_definition_code = {
        ["<leader>df"] = "@function.outer",
        ["<leader>dF"] = "@class.outer",
      },
    },
  },
  hidesig = {
    enable = true,
    opacity = 0.5,
    delay = 200,
  },
})

-- https://github.com/nvim-treesitter/nvim-treesitter/issues/655#issuecomment-1021160477
local ft_to_lang = treesitter_parsers.ft_to_lang
treesitter_parsers.ft_to_lang = function(ft)
  if ft == "zsh" then
    return "bash"
  end
  return ft_to_lang(ft)
end
