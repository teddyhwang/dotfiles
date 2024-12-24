return {
  "windwp/nvim-autopairs",
  dependencies = { "hrsh7th/nvim-cmp" },
  event = "InsertEnter",
  config = {
    check_ts = true,
    enable_check_bracket_line = true,
    ignored_next_char = "[%w%.]",
  },
  init = function()
    local autopairs = require("nvim-autopairs")
    local Rule = require("nvim-autopairs.rule")
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    local cmp = require("cmp")

    local paired_brackets = {
      round = { "(", ")" },
      square = { "[", "]" },
      curly = { "{", "}" },
    }

    local function get_bracket_pairs()
      return vim.tbl_map(function(v)
        return v[1] .. v[2]
      end, paired_brackets)
    end

    autopairs.add_rules({
      Rule(" ", " "):with_pair(function(opts)
        local pair = opts.line:sub(opts.col - 1, opts.col)
        return vim.tbl_contains(get_bracket_pairs(), pair)
      end),
      Rule("%(.*%)%s*%=>$", " {  }", { "typescript", "typescriptreact", "javascript" })
        :use_regex(true)
        :set_end_pair_length(2),
    })

    for _, bracket in pairs(paired_brackets) do
      autopairs.add_rules({
        Rule(bracket[1] .. " ", " " .. bracket[2])
          :with_pair(function()
            return false
          end)
          :with_move(function(opts)
            return opts.prev_char:match(".%" .. bracket[2]) ~= nil
          end)
          :use_key(bracket[2]),
      })
    end

    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
  end,
}
