-- Rex key bindings that mirror my tmux and Herdr configs (prefix ctrl+a).
-- Validate with `rex config check`; apply with `rex config reload` (prefix+r).
-- Key sequences are written "ctrl+a>c". Shifted symbols name the base key:
-- "|" is shift+\, "_" is shift+-, "<" is shift+, and "?" is shift+/.

local PREFIX = "ctrl+a"

local function prefixed(key, action, args)
  rex.bind(PREFIX .. ">" .. key, action, args)
end

-- Panes
prefixed("-", "pane.split.down") -- tmux: bind - split-window -v
prefixed("shift+\\", "pane.split.right") -- tmux: bind | split-window -h
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  prefixed(key, "pane.focus", { direction = direction, wrap = false })
  prefixed("shift+" .. key, "pane.move", { direction = direction })
end
prefixed("o", "pane.focus_next")
prefixed("q", "pane.close") -- tmux: bind q killp
prefixed("x", "pane.close")
prefixed("z", "pane.zoom")
prefixed("=", "pane.balance") -- tmux: select-layout even-horizontal
prefixed("shift+t", "pane.move_to_new_tab") -- tmux: bind T break-pane
prefixed("shift+b", "pane.move_to_new_tab")
prefixed("shift+v", "pane.move_to_tab") -- tmux: bind V join-pane
prefixed("\\", "client.sidebar.toggle") -- Herdr: toggle_sidebar
-- Typing ctrl+a twice sends a literal ctrl+a (readline start of line).
prefixed(PREFIX, "pane.send_key", { key = PREFIX })

-- Resize mode: prefix+e, then h/j/k/l; escape, enter or q leaves it.
rex.mode("resize", { exclusive = true })
prefixed("e", "client.mode.enter", { name = "resize" })
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("resize/" .. key, "pane.resize", { direction = direction, amount = 2 })
end
for _, key in ipairs({ "escape", "enter", "q", "ctrl+c" }) do
  rex.bind("resize/" .. key, "client.mode.exit")
end

-- Tabs (tmux windows).
prefixed("c", "client.tab.new")
prefixed("shift+a", "client.tab.rename") -- tmux: bind A rename-window
prefixed("shift+7", "client.tab.close") -- prefix+&
prefixed("p", "client.tab.previous")
prefixed("n", "client.tab.next")
prefixed("ctrl+h", "client.tab.previous")
prefixed("ctrl+l", "client.tab.next")
prefixed("shift+,", "client.tab.move.backward") -- prefix+<
prefixed("shift+.", "client.tab.move.forward") -- prefix+>
-- Zero-based like Herdr: prefix+0 is the first tab. Rex counts from 1.
for digit = 0, 9 do
  prefixed(tostring(digit), "client.tab.goto", { index = digit + 1 })
end

-- Sessions (tmux sessions, Herdr workspaces)
prefixed("shift+n", "session.new") -- Herdr default: new_workspace
prefixed("s", "session.switch")
prefixed("shift+s", "session.switch")
prefixed("w", "session.switch")
prefixed("shift+4", "session.rename") -- prefix+$
prefixed("ctrl+j", "session.next")
prefixed("ctrl+k", "session.previous")

-- Misc
prefixed("r", "client.config.reload")
prefixed("shift+c", "client.settings")
prefixed("shift+/", "client.palette.toggle") -- prefix+?

-- No-prefix keys, like vim-tmux-navigator: ctrl+h/j/k/l move between panes
-- unless the pane runs (Neo)vim, which gets the key and calls `rex focus` at
-- its own edge. ctrl+j/k also reach fzf, atuin and tv.
-- Key handlers cannot queue client actions (pane.focus), so they call the
-- server's session and terminal methods directly. Returning false passes the
-- key on to the pane.
local TERMINAL = "com.superlogical.terminal"

local function block_id(ctx)
  return (ctx and ctx.block_id) or rex.block_id
end

local function session_id(ctx)
  return (ctx and ctx.session_id) or rex.session_id
end

local function foreground(ctx)
  local ok, process = pcall(rex.block.call, TERMINAL, "process", { block_id = block_id(ctx) })
  if not ok or type(process) ~= "table" or type(process.foreground) ~= "table" then
    return ""
  end
  local fg = process.foreground
  return ((fg.argv0 ~= "" and fg.argv0) or fg.name or ""):gsub("^.*/", ""):gsub("^%-", "")
end

local function matches(name, patterns)
  for _, pattern in ipairs(patterns) do
    if name:match(pattern) then
      return true
    end
  end
  return false
end

local VIM = { "^g?view$", "^g?n?vim?$", "^g?n?vimdiff$" }
local TUI = { "^g?view$", "^g?n?vim?$", "^g?n?vimdiff$", "^fzf$", "^atuin$", "^tv$" }

local function navigate(key, direction, passthrough)
  rex.bind(key, function(ctx)
    if matches(foreground(ctx), passthrough) then
      return false
    end
    rex.call("session.focus_direction", { session_id = session_id(ctx), direction = direction, wrap = false })
    return true
  end)
end

navigate("ctrl+h", "left", VIM)
navigate("ctrl+l", "right", VIM)
navigate("ctrl+j", "down", TUI)
navigate("ctrl+k", "up", TUI)

-- ctrl+x clears the screen outside Vim (ctrl+l now navigates).
rex.bind("ctrl+x", function(ctx)
  if matches(foreground(ctx), VIM) then
    return false
  end
  rex.block.call(TERMINAL, "write", { block_id = block_id(ctx), data = "\12" })
  return true
end)

-- ctrl+alt+h/j/k/l resize the pane, like Herdr.
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+alt+" .. key, "pane.resize", { direction = direction, amount = 1 })
end
