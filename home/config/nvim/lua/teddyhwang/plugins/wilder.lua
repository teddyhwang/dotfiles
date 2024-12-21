return function(wilder)
  wilder.setup({
    modes = { ":", "/", "?" },
    next_key = "<C-j>",
    previous_key = "<C-k>",
  })
  wilder.set_option("pipeline", {
    wilder.branch(
      wilder.python_file_finder_pipeline({
        file_command = { "rg", "--files" },
        dir_command = { "fd", "-td" },
        filters = { "fuzzy_filter", "difflib_sorter" },
      }),
      wilder.substitute_pipeline({
        pipeline = wilder.python_search_pipeline({
          skip_cmdtype_check = 1,
          pattern = wilder.python_fuzzy_pattern({
            start_at_boundary = 0,
          }),
        }),
      }),
      wilder.cmdline_pipeline({
        fuzzy = 2,
        fuzzy_filter = wilder.lua_fzy_filter(),
      }),
      wilder.python_search_pipeline({
        pattern = wilder.python_fuzzy_pattern({
          start_at_boundary = 0,
        }),
      })
    ),
  })

  local popupmenu_renderer = wilder.popupmenu_renderer(wilder.popupmenu_border_theme({
    border = "rounded",
    empty_message = wilder.popupmenu_empty_message_with_spinner(),
    highlighter = {
      wilder.pcre2_highlighter(),
      wilder.lua_fzy_highlighter(),
    },
    highlights = {
      accent = "WilderAccent",
      border = "WilderBorder",
    },
    left = {
      " ",
      wilder.popupmenu_devicons(),
    },
    right = {
      " ",
      wilder.popupmenu_scrollbar(),
    },
  }))

  wilder.set_option(
    "renderer",
    wilder.renderer_mux({
      [":"] = popupmenu_renderer,
      ["/"] = popupmenu_renderer,
      substitute = popupmenu_renderer,
    })
  )
end
