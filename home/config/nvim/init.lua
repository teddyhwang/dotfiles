local use_vim_rc = os.getenv("USE_VIM_RC")

if use_vim_rc then
  vim.cmd("set runtimepath^=~/.vim runtimepath+=~/.vim/after")
  vim.cmd("let &packpath = &runtimepath")
  vim.cmd("source ~/.vimrc")
else
  require("teddyhwang.plugins-setup")
  require("teddyhwang.core.aliases")
  require("teddyhwang.core.options")
  require("teddyhwang.core.colorscheme")
  require("teddyhwang.plugins.autopairs")
  require("teddyhwang.plugins.colorizer")
  require("teddyhwang.plugins.comment")
  require("teddyhwang.plugins.floaterm")
  require("teddyhwang.plugins.fzf")
  require("teddyhwang.plugins.gitsigns")
  require("teddyhwang.plugins.highlightedyank")
  require("teddyhwang.plugins.indent-blankline")
  require("teddyhwang.plugins.which-key")
  require("teddyhwang.plugins.lsp.lspconfig")
  require("teddyhwang.plugins.lsp.lspsaga")
  require("teddyhwang.plugins.lsp.mason")
  require("teddyhwang.plugins.lsp.null-ls")
  require("teddyhwang.plugins.lualine")
  require("teddyhwang.plugins.nvim-cmp")
  require("teddyhwang.plugins.nvim-tree")
  require("teddyhwang.plugins.remote")
  require("teddyhwang.plugins.telescope")
  require("teddyhwang.plugins.tint")
  require("teddyhwang.plugins.treesitter")
  require("teddyhwang.plugins.vimux")
  require("teddyhwang.plugins.wilder")
  require("teddyhwang.plugins.winresizer")
end
