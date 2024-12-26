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
    {
      "j-hui/fidget.nvim",
      tag = "legacy",
      config = true,
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

    local capabilities = cmp_nvim_lsp.default_capabilities()

    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local default_config = {
      capabilities = capabilities,
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
        settings = {
          Lua = {
            completion = {
              callSnippet = "Replace",
            },
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      },
      sorbet = {
        root_dir = lspconfig.util.root_pattern("sorbet/config"),
      },
      ruby_lsp = {
        init_options = {
          formatter = "rubocop",
        },
        capabilities = vim.tbl_deep_extend("force", capabilities, {
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
