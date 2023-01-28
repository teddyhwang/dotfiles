local status, wilder = pcall(require, "wilder")
local base16_status, base16 = pcall(require, "base16-colorscheme")

if not status then
  return
end

if not base16_status then
  return
end

local colors = base16.colors or base16.colorschemes[vim.env.BASE16_THEME or "seti"]

wilder.setup({
  modes = { ":", "/", "?" },
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
    accent = wilder.make_hl("WilderAccent", "Pmenu", { { a = 1 }, { a = 1 }, { foreground = colors.base0E } }),
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
