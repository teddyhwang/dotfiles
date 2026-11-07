-- Send keyboard shortcuts to the remote computer while Screen Sharing is
-- frontmost, instead of letting local global hotkeys take them.
--
-- Raycast (and Hammerspoon's own hs.hotkey bindings) register global hotkeys
-- that fire before Screen Sharing sees the key, so Cmd+Shift+T opened a local
-- Raycast command instead of the Omarchy terminal on the other end. Raycast
-- has no per-app exclusion. This event tap runs before those hotkeys: while
-- Screen Sharing is frontmost, it takes each Cmd, Ctrl or Option chord,
-- posts a copy straight to Screen Sharing, and drops the original.
--
-- Plain typing and modifier presses pass through untouched. Cmd+Tab and
-- Cmd+` stay local so you can always switch away from Screen Sharing.

local M = {}

local BUNDLE_IDS = { ["com.apple.ScreenSharing"] = true, ["com.apple.screensharing.agent"] = true }

local function isScreenSharing(app)
	if not app then
		return false
	end
	if BUNDLE_IDS[app:bundleID() or ""] then
		return true
	end
	return (app:name() or ""):lower() == "screen sharing"
end

local function keepLocal(keyCode, flags)
	local codes = hs.keycodes.map
	return flags.cmd and not flags.ctrl and not flags.alt and (keyCode == codes.tab or keyCode == codes["`"])
end

-- Exposed for `hs -c` checks.
function M.active()
	return M.target ~= nil and M.tap ~= nil and M.tap:isEnabled()
end

local function setTarget(app)
	M.target = isScreenSharing(app) and app or nil
	if M.target then
		M.tap:start()
	else
		M.tap:stop()
	end
end

function M.start()
	local types = hs.eventtap.event.types
	M.tap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
		local app = M.target
		if not app then
			return false
		end
		local flags = event:getFlags()
		if not (flags.cmd or flags.ctrl or flags.alt) or keepLocal(event:getKeyCode(), flags) then
			return false
		end
		event:copy():post(app)
		return true
	end)

	M.watcher = hs.application.watcher.new(function(_, event, app)
		if event == hs.application.watcher.activated then
			setTarget(app)
		elseif event == hs.application.watcher.deactivated and M.target and app and app:pid() == M.target:pid() then
			setTarget(nil)
		end
	end)
	M.watcher:start()
	setTarget(hs.application.frontmostApplication())

	-- macOS disables a tap whose callback is slow; turn it back on.
	M.watchdog = hs.timer.doEvery(5, function()
		if M.target and not M.tap:isEnabled() then
			print("[screen_sharing_keys] event tap was disabled; restarting")
			M.tap:start()
		end
	end)
	return M
end

return M
