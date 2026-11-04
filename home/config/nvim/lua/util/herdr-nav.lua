local M = {}

local keys = { left = "h", down = "j", up = "k", right = "l" }
local tmux_flags = { left = "-L", down = "-D", up = "-U", right = "-R" }
local backends = { ["herdr-core"] = "app", herdr = "tui", tmux = "tmux" }

local backend
local warned = false

function M.enabled()
  return vim.env.HERDR_ENV == "1" or vim.env.HC_TERMINAL_ID ~= nil
end

local function process(pid)
  local result = vim.system({ "ps", "-o", "ppid=,comm=", "-p", tostring(pid) }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  local ppid, comm = (result.stdout or ""):match("^%s*(%d+)%s+(.-)%s*$")
  if not ppid then
    return nil
  end
  return tonumber(ppid), vim.fs.basename(comm)
end

function M.detect()
  if backend ~= nil then
    return backend or nil
  end
  backend = false
  local pid = vim.uv.os_getppid()
  for _ = 1, 32 do
    if not pid or pid <= 1 then
      break
    end
    local ppid, comm = process(pid)
    if not ppid then
      break
    end
    if backends[comm] then
      backend = backends[comm]
      break
    end
    pid = ppid
  end
  return backend or nil
end

local function executable(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  return vim.fs.joinpath(vim.env.HOME, ".local/bin", name)
end

local function spawn(cmd, opts, on_exit)
  local ok = pcall(vim.system, cmd, opts or {}, on_exit)
  if not ok and on_exit then
    on_exit({ code = 127 })
  end
end

local function tui(action, direction)
  spawn({ executable("herdr-nav"), action, direction }, { env = { HERDR_ACTIVE_PANE_ID = vim.env.HERDR_PANE_ID } })
end

local function warn(message)
  if warned then
    return
  end
  warned = true
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
end

function M.move(direction)
  local before = vim.api.nvim_get_current_win()
  vim.cmd(vim.v.count1 .. "wincmd " .. keys[direction])
  if vim.api.nvim_get_current_win() ~= before then
    return
  end
  local mux = M.detect()
  if mux == "app" then
    local app = executable("herdr-app")
    spawn({ app, "do", "splits.go-" .. direction }, {}, function(result)
      if result.code ~= 0 then
        spawn({ app, "do", "pane.go", "--direction", direction })
      end
    end)
  elseif mux == "tui" then
    tui("focus", direction)
  elseif mux == "tmux" then
    spawn({ "tmux", "select-pane", tmux_flags[direction] })
  end
end

local function resize_window(direction)
  local current = vim.fn.winnr()
  local horizontal = direction == "left" or direction == "right"
  local before, after = "k", "j"
  if horizontal then
    before, after = "h", "l"
  end
  if vim.fn.winnr(before) == current and vim.fn.winnr(after) == current then
    return false
  end
  local last = vim.fn.winnr(after) == current
  local grow = (direction == "left" or direction == "up") == last
  local amount = vim.v.count1 * (horizontal and 3 or 2)
  vim.cmd(string.format("%sresize %s%d", horizontal and "vertical " or "", grow and "+" or "-", amount))
  return true
end

function M.resize(direction)
  if resize_window(direction) then
    return
  end
  local mux = M.detect()
  if mux == "app" then
    spawn({ executable("herdr-app"), "do", "splits.resize-pane-" .. direction }, {}, function(result)
      if result.code ~= 0 then
        warn("herdr-nav: the herdr-app splits mod is not loaded")
      end
    end)
  elseif mux == "tui" then
    tui("resize-pane", direction)
  elseif mux == "tmux" then
    spawn({ "tmux", "resize-pane", tmux_flags[direction], "3" })
  end
end

return M
