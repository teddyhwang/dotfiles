return function(autopairs, Rule, cmp_autopairs, cmp)
  local brackets = { { "(", ")" }, { "[", "]" }, { "{", "}" } }
  autopairs.add_rules({
    Rule(" ", " "):with_pair(function(opts)
      local pair = opts.line:sub(opts.col - 1, opts.col)
      return vim.tbl_contains({
        brackets[1][1] .. brackets[1][2],
        brackets[2][1] .. brackets[2][2],
        brackets[3][1] .. brackets[3][2],
      }, pair)
    end),
    Rule("%(.*%)%s*%=>$", " {  }", { "typescript", "typescriptreact", "javascript" })
      :use_regex(true)
      :set_end_pair_length(2),
  })
  for _, bracket in pairs(brackets) do
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
end
