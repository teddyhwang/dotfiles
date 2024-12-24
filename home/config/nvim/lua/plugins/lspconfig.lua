return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "gfanto/fzf-lsp.nvim",
    "lukas-reineke/lsp-format.nvim",
    "onsails/lspkind.nvim",
    { "williamboman/mason.nvim", config = true },
    {
      "j-hui/fidget.nvim",
      tag = "legacy",
      config = true,
    },
  },
  init = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local lsp_format = require("lsp-format")

    lsp_format.setup({})

    local on_attach = function(client, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })

      if client.name == "eslint" then
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          command = "EslintFixAll",
        })
      end
      lsp_format.on_attach(client, bufnr)
    end

    local capabilities = cmp_nvim_lsp.default_capabilities()

    local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local default_config = {
      capabilities = capabilities,
      on_attach = on_attach,
    }

    local servers = {
      html = {
        filetypes = { "html", "templ", "eruby" },
      },
      ts_ls = {
        server = default_config,
      },
      cssls = {},
      tailwindcss = {},
      eslint = {},
      emmet_ls = {
        filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less", "svelte" },
      },
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
