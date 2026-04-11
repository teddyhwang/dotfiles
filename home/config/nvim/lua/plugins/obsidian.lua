return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "pi-memory",
          path = "~/.pi/agent/memory",
        },
      },
      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
      },
      completion = {
        nvim_cmp = false,
        blink = true,
      },
      notes_subdir = ".",
      new_notes_location = "notes_subdir",
      legacy_commands = false,
      frontmatter = {
        enabled = false,
      },
      link = {
        style = "wiki",
      },
      checkbox = {
        order = { " ", "x" },
      },
      ui = {
        enable = true,
      },
    },
  },
}
