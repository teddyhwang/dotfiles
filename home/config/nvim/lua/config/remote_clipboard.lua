-- Clipboard for sessions whose yanks may need to reach another machine:
-- every copy is emitted as OSC 52 (inside tmux this becomes a tmux buffer,
-- rebroadcast to every attached client, local or SSH). Paste prefers the
-- local system clipboard when one is reachable (Wayland via wl-paste, macOS
-- via pbpaste), so content copied in other apps remains pasteable; without a
-- local clipboard, paste is an OSC 52 query that tmux (or the terminal)
-- answers -- which stalls for a second when nothing replies.
local M = {}

local function proc_lines(pid, file)
  local ok, lines = pcall(vim.fn.readfile, "/proc/" .. pid .. "/" .. file)
  return ok and lines or {}
end

local function proc_ppid(pid)
  for _, line in ipairs(proc_lines(pid, "status")) do
    local ppid = line:match("^PPid:%s+(%d+)")
    if ppid then
      return tonumber(ppid)
    end
  end
end

local function ancestor_process_named(name)
  local pid = vim.fn.getpid()

  for _ = 1, 16 do
    local ppid = proc_ppid(pid)
    if not ppid or ppid <= 1 then
      return false
    end

    local comm = proc_lines(ppid, "comm")[1] or ""
    if comm:find(name, 1, true) then
      return true
    end

    pid = ppid
  end

  return false
end

function M.setup()
  local in_tmux = vim.env.TMUX ~= nil
  local in_ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
  local in_herdr = vim.env.HERDR_PANE_ID ~= nil or ancestor_process_named("herdr")

  if not (in_tmux or in_ssh or in_herdr) then
    return
  end

  local osc52 = require("vim.ui.clipboard.osc52")

  -- The local clipboard commands for this machine, if it has one we can reach.
  -- Wayland keeps a separate primary selection; macOS has only one clipboard,
  -- so "*" and "+" both map to pbcopy/pbpaste.
  local function local_clipboard()
    if
      vim.env.WAYLAND_DISPLAY ~= nil
      and vim.fn.executable("wl-copy") == 1
      and vim.fn.executable("wl-paste") == 1
    then
      return function(register)
        local primary = register == "*" and { "--primary" } or {}
        return {
          copy = vim.list_extend({ "wl-copy", "--sensitive", "--type", "text/plain" }, primary),
          paste = vim.list_extend({ "wl-paste", "--no-newline" }, primary),
        }
      end
    end

    if vim.fn.has("mac") == 1 and vim.fn.executable("pbcopy") == 1 and vim.fn.executable("pbpaste") == 1 then
      return function()
        return { copy = { "pbcopy" }, paste = { "pbpaste" } }
      end
    end
  end

  local local_cmds = local_clipboard()

  local function copy(register)
    local emit = osc52.copy(register)

    return function(lines)
      if local_cmds then
        vim.fn.system(local_cmds(register).copy, lines)
      end

      if vim.g.omarchy_remote_clipboard_osc52 ~= false then
        emit(lines)
      end
    end
  end

  local function paste(register)
    if not local_cmds then
      return osc52.paste(register)
    end

    return function()
      local lines = vim.fn.systemlist(local_cmds(register).paste, "", 1)
      return vim.v.shell_error == 0 and lines or {}
    end
  end

  vim.g.clipboard = {
    name = "OmarchyRemoteClipboard",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
    cache_enabled = 0,
  }
end

return M
