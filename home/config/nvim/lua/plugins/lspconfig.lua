return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "gfanto/fzf-lsp.nvim",
    "nvimtools/none-ls.nvim",
    "lukas-reineke/lsp-format.nvim",
    { "williamboman/mason.nvim", config = true },
    {
      "williamboman/mason-lspconfig.nvim",
      opts = {
        automatic_installation = false,
        ensure_installed = {
          "bashls",
          "cssls",
          "graphql",
          "html",
          "jsonls",
          "lua_ls",
          "tailwindcss",
          "ts_ls",
          "yamlls",
        },
      },
    },
    {
      "jay-babu/mason-null-ls.nvim",
      opts = {
        automatic_installation = true,
        ensure_installed = {
          "eslint-lsp",
          "prettierd",
          "stylelint",
          "yamllint",
        },
      },
    },
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local lsp_format = require("lsp-format")
    local null_ls = require("null-ls")
    local formatting = null_ls.builtins.formatting
    local diagnostics = null_ls.builtins.diagnostics

    lsp_format.setup({})

    null_ls.setup({
      sources = {
        formatting.prettierd.with({
          filetypes = {
            "css",
            "graphql",
            "html",
            "less",
            "markdown",
            "scss",
          },
        }),
        formatting.stylelint,
        diagnostics.stylelint,
        diagnostics.yamllint,
      },
      on_attach = lsp_format.on_attach,
    })

    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local default_config = {
      capabilities = cmp_nvim_lsp.default_capabilities(),
      on_attach = lsp_format.on_attach,
    }

    local servers = {
      html = {
        filetypes = { "html", "eruby" },
      },
      ts_ls = {},
      cssls = {},
      tailwindcss = {},
      eslint = {},
      graphql = {},
      jsonls = {},
      lua_ls = {
        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if vim.fn.filereadable(path .. '/.luarc.json') == 1 or vim.fn.filereadable(path .. '/.luarc.jsonc') == 1 then
              return
            end
          end

          client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
              version = 'LuaJIT'
            },
            workspace = {
              checkThirdParty = false,
              library = {
                vim.env.VIMRUNTIME
              }
            }
          })
        end,
        settings = {
          Lua = {}
        }
      },
      sorbet = {
        root_dir = lspconfig.util.root_pattern("sorbet/config"),
      },
      ruby_lsp = {
        init_options = {
          formatter = "rubocop",
        },
        capabilities = vim.tbl_deep_extend("force", default_config.capabilities, {
          textDocument = {
            references = true,
            definition = true,
            implementation = true,
          },
        }),
      },
      bashls = {},
      yamlls = {},
    }

    for server, config in pairs(servers) do
      lspconfig[server].setup(vim.tbl_deep_extend("force", default_config, config))
    end
  end,
}
