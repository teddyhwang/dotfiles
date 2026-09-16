return {
  {
    "mason-org/mason.nvim",
    opts = {
      npm = {
        install_args = { "--registry", "https://registry.npmjs.org/" },
      },
      ui = {
        border = "rounded",
      },
    },
  },
}
