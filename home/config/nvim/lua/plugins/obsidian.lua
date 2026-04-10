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
      -- Don't manage frontmatter since pi memory files are plain markdown
      disable_frontmatter = true,
      -- Wiki-style links work with pi's [[link]] syntax
      wiki_link_func = "use_alias_only",
      -- Use pi memory's tag format (#tag)
      ui = {
        enable = true,
        checkboxes = {
          [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
          ["x"] = { char = "", hl_group = "ObsidianDone" },
        },
      },
    },
  },
}
