return {
  {
    "rgroli/other.nvim",
    config = function()
      require("other-nvim").setup({
        mappings = {
          "rails",
          "react",
          -- Custom mapping for FolderName/FolderName.tsx <-> FolderName/tests/FolderName.test.tsx
          {
            pattern = "(.*)/(.*)/(%2)%.tsx$",
            target = "%1/%2/tests/%3.test.tsx",
            context = "test",
          },
          {
            pattern = "(.*)/(.*)/tests/(%2)%.test%.tsx$",
            target = "%1/%2/%3.tsx",
            context = "component",
          },
          -- Custom mapping for FolderName/FolderName.ts <-> FolderName/tests/FolderName.test.tsx (or .ts)
          {
            pattern = "(.*)/(.*)/(%2)%.ts$",
            target = {
              { target = "%1/%2/tests/%3.test.tsx", context = "test (tsx)" },
              { target = "%1/%2/tests/%3.test.ts", context = "test (ts)" },
            },
          },
          {
            pattern = "(.*)/(.*)/tests/(%2)%.test%.tsx?$",
            target = "%1/%2/%3.ts",
            context = "source",
          },
          -- Custom mapping for file.ts <-> tests/file.test.ts
          {
            pattern = "(.*)/(.-)%.ts$",
            target = "%1/tests/%2.test.ts",
            context = "test",
          },
          {
            pattern = "(.*)/tests/(.-)%.test%.ts$",
            target = "%1/%2.ts",
            context = "source",
          },
          -- Custom mapping for components/.../lib/foo.rb <-> components/.../test/lib/foo_test.rb
          {
            pattern = "(.*)/lib/(.*)%.rb$",
            target = "%1/test/lib/%2_test.rb",
            context = "test",
          },
          {
            pattern = "(.*)/test/lib/(.*)_test%.rb$",
            target = "%1/lib/%2.rb",
            context = "source",
          },
        },
      })

      -- Wrapper function to use other.nvim with Snacks picker
      local function open_other_with_snacks(open_cmd)
        local other = require("other-nvim")
        local snacks = require("snacks")
        local current_file = vim.api.nvim_buf_get_name(0)

        -- Get alternate files using other.nvim's logic
        local matches = other.findOther(current_file, nil)

        if #matches == 0 then
          vim.notify("No alternate files found", vim.log.levels.WARN)
          return
        end

        -- Filter to only existing files
        local existing_matches = vim.tbl_filter(function(match)
          return match.exists
        end, matches)

        -- If exactly one existing file, open it directly without picker
        if #existing_matches == 1 then
          vim.cmd[open_cmd](existing_matches[1].filename)
          return
        end

        -- If multiple existing files, only show those in picker
        -- If no existing files, show all suggestions
        local items_to_show = #existing_matches > 0 and existing_matches or matches

        -- Convert filtered matches to Snacks picker format
        local items = vim.tbl_map(function(match)
          local status = match.exists and "" or " [new]"
          local display = string.format("%s | %s%s", match.context, vim.fn.fnamemodify(match.filename, ":~:."), status)
          return {
            text = display,
            context = match.context,
            file = match.filename,
            exists = match.exists,
          }
        end, items_to_show)

        -- Open Snacks picker with the items
        snacks.picker.pick({
          items = items,
          preview = function(ctx)
            local item = ctx.item
            -- Only preview files that actually exist
            if item and item.exists then
              return snacks.picker.preview.file(ctx)
            else
              -- Show message for non-existent files
              ctx.preview:reset()
              ctx.preview:set_title("New File")
              ctx.preview:set_lines({
                "File does not exist yet.",
                "",
                "Press <CR> to create: " .. item.file,
              })
            end
          end,
          confirm = function(picker, item)
            if item then
              picker:close()
              vim.cmd[open_cmd](item.file)
            end
          end,
        })
      end

      -- Create commands
      vim.api.nvim_create_user_command("Other", function()
        open_other_with_snacks("edit")
      end, {})
      vim.api.nvim_create_user_command("OtherSplit", function()
        open_other_with_snacks("split")
      end, {})
      vim.api.nvim_create_user_command("OtherVSplit", function()
        open_other_with_snacks("vsplit")
      end, {})
      vim.api.nvim_create_user_command("OtherTabNew", function()
        open_other_with_snacks("tabnew")
      end, {})
    end,
  },
}
