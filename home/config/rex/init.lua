-- Rex key bindings that mirror my tmux and Herdr configs (prefix ctrl+a).
-- Validate with `rex config check`; apply with `rex config reload` (prefix+r).
-- Key sequences are written "ctrl+a>c". Shifted symbols name the base key:
-- "|" is shift+\, "_" is shift+-, "<" is shift+, and "?" is shift+/.

local PREFIX = "ctrl+a"

local function prefixed(key, action, args)
  rex.bind(PREFIX .. ">" .. key, action, args)
end

-- Last location: prefix+tab goes back to where you were, like tmux last-pane
-- and Herdr last_pane, but across panes, tabs, sessions and remote hosts.
--
-- Rex has no focus history, and this version ignores rex.on in init.lua. So
-- every navigation key below goes through the `tracked` action, which notes
-- where you are before it moves you. A move made another way (a mouse click,
-- the sidebar) is noticed at the next tracked key, because the location has
-- changed since the last note. Config actions from the app run on its home
-- server with ctx.server naming the remote host, so the history can cross
-- hosts. `rex do last_location_log --json` shows recent jumps.
local history = {} -- client ID -> { current = location, previous = location }
local log = {}

local function remember_log(entry)
  table.insert(log, entry)
  if #log > 20 then
    table.remove(log, 1)
  end
end

local function location(ctx)
  if not ctx or not ctx.session_id then
    return nil
  end
  return { server = ctx.server, session_id = ctx.session_id, block_id = ctx.block_id }
end

local function same_location(a, b)
  return a ~= nil
    and b ~= nil
    and a.server == b.server
    and a.session_id == b.session_id
    and a.block_id == b.block_id
end

local function describe(loc)
  if not loc then
    return "nowhere"
  end
  return string.format("%s %s %s", loc.server or "local", loc.session_id, loc.block_id or "-")
end

-- Note the current location. Returns the client's history and the location.
local function observe(ctx)
  local here = location(ctx)
  if not here then
    return nil, nil
  end
  local key = ctx.client_id or "default"
  local state = history[key]
  if not state then
    state = {}
    history[key] = state
  end
  if not same_location(state.current, here) then
    state.previous, state.current = state.current, here
  end
  return state, here
end

-- The API of the server that holds a location, seen from ctx. rex.call goes to
-- ctx.server when it is set. nil means that server cannot be reached here.
local function api_for(ctx, loc)
  if loc.server == ctx.server then
    return rex
  end
  if loc.server then
    local ok, api = pcall(rex.server, loc.server)
    if ok then
      return api
    end
  end
  return nil
end

local function elsewhere(ctx, loc)
  return loc.session_id ~= ctx.session_id or loc.server ~= ctx.server
end

-- Focus the target's pane on its own server. The caller then selects the
-- target's session in the app when it differs.
local function focus(ctx, target)
  local api = api_for(ctx, target)
  if api and target.block_id then
    -- Focusing the block also makes its window the session's active window.
    local ok, err = pcall(api.call, "session.focus_block", {
      session_id = target.session_id,
      block_id = target.block_id,
    })
    if not ok and not elsewhere(ctx, target) then
      error(err)
    end
  end
end

rex.action({
  name = "last_location",
  title = "Go to Last Location",
  run = function(ctx)
    local state, here = observe(ctx)
    local target = state and state.previous
    if not target then
      remember_log("no previous location from " .. describe(here))
      return
    end
    local ok, err = pcall(focus, ctx, target)
    if not ok then
      remember_log("failed " .. describe(target) .. ": " .. tostring(err))
      state.previous = nil
      return
    end
    if elsewhere(ctx, target) then
      -- A session keeps the window and pane you left it on, so selecting it
      -- is enough when focus could not reach the target's server.
      rex.client.queue("session.select", { session_id = target.session_id })
    end
    remember_log("jumped " .. describe(here) .. " -> " .. describe(target))
    state.previous, state.current = here, target
  end,
})

rex.action({
  name = "tracked",
  title = "Navigate and Remember Location",
  run = function(ctx, args)
    observe(ctx)
    rex.client.queue(args.action, args.args)
  end,
})

rex.action({
  name = "last_location_log",
  title = "Show Last Location Log",
  run = function()
    return log
  end,
})

-- Bind a key to a client action, noting the location first.
local function tracked(key, action, args)
  prefixed(key, "tracked", { action = action, args = args })
end

-- Panes
tracked("-", "pane.split.down") -- tmux: bind - split-window -v
tracked("shift+\\", "pane.split.right") -- tmux: bind | split-window -h
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  tracked(key, "pane.focus", { direction = direction, wrap = false })
  prefixed("shift+" .. key, "pane.move", { direction = direction })
end
tracked("o", "pane.focus_next")
prefixed("q", "pane.close") -- tmux: bind q killp
prefixed("x", "pane.close")
prefixed("z", "pane.zoom")
prefixed("=", "pane.balance") -- tmux: select-layout even-horizontal
tracked("shift+t", "pane.move_to_new_tab") -- tmux: bind T break-pane
tracked("shift+b", "pane.move_to_new_tab")
tracked("shift+v", "pane.move_to_tab") -- tmux: bind V join-pane
prefixed("\\", "client.sidebar.toggle") -- Herdr: toggle_sidebar
-- Typing ctrl+a twice sends a literal ctrl+a (readline start of line).
prefixed(PREFIX, "pane.send_key", { key = PREFIX })
-- tmux: bind Tab last-pane; Herdr: last_pane. See "Last location" above.
prefixed("tab", "last_location")

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
tracked("c", "client.tab.new")
prefixed("shift+a", "client.tab.rename") -- tmux: bind A rename-window
prefixed("shift+7", "client.tab.close") -- prefix+&
tracked("p", "client.tab.previous")
tracked("n", "client.tab.next")
tracked("ctrl+h", "client.tab.previous")
tracked("ctrl+l", "client.tab.next")
prefixed("shift+,", "client.tab.move.backward") -- prefix+<
prefixed("shift+.", "client.tab.move.forward") -- prefix+>
-- Zero-based like Herdr: prefix+0 is the first tab. Rex counts from 1.
for digit = 0, 9 do
  tracked(tostring(digit), "client.tab.goto", { index = digit + 1 })
end

-- Sessions (tmux sessions, Herdr workspaces)
tracked("shift+n", "session.new") -- Herdr default: new_workspace
tracked("s", "session.switch")
tracked("shift+s", "session.switch")
tracked("w", "session.switch")
prefixed("shift+4", "session.rename") -- prefix+$
tracked("ctrl+j", "session.next")
tracked("ctrl+k", "session.previous")

-- Misc
prefixed("r", "client.config.reload")
prefixed("shift+c", "client.settings")
prefixed("shift+/", "client.palette.toggle") -- prefix+?
-- Copy mode: Rex has no tmux copy mode. client.find.open opens the scrollback
-- search bar, the closest equivalent for navigating and highlighting history.
prefixed("escape", "client.find.open") -- tmux: bind Escape copy-mode
-- Paste: Rex uses the macOS clipboard rather than a tmux paste buffer.
-- Sends Cmd+V so the terminal receives a native paste from the system clipboard.
prefixed("shift+p", "pane.send_key", { key = "cmd+v" }) -- tmux: bind P paste-buffer

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
    observe(ctx) -- for prefix+tab
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
