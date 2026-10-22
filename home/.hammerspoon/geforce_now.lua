-- GeForce NOW gaming mode.
--
-- When GeForce NOW launches:
--   * toggle HDR on with BetterDisplay's ctrl+alt+h shortcut
--   * take Tailscale down, if it was running, for a direct connection
-- When GeForce NOW quits, undo whatever was changed.
--
-- State is kept in hs.settings so a Hammerspoon reload while the game is
-- running still restores everything when the app quits.

local M = {}

local BUNDLE_ID = "com.nvidia.gfnpc.mall"
local SETTINGS_KEY = "geforceNowGamingMode"
local HDR_MODS = { "ctrl", "alt" }
local HDR_KEY = "h"
local TAILSCALE_CANDIDATES = {
	"/usr/local/bin/tailscale",
	"/opt/homebrew/bin/tailscale",
	"/Applications/Tailscale.app/Contents/MacOS/Tailscale",
}

local function log(message)
	print("[geforce_now] " .. message)
end

local function tailscaleBinary()
	for _, path in ipairs(TAILSCALE_CANDIDATES) do
		if hs.fs.attributes(path) then
			return path
		end
	end
	return nil
end

local function runTailscale(args, callback)
	local binary = tailscaleBinary()
	if not binary then
		log("tailscale CLI not found")
		if callback then
			callback(false, "")
		end
		return
	end
	local task = hs.task.new(binary, function(exitCode, stdout, stderr)
		if exitCode ~= 0 then
			log("tailscale " .. table.concat(args, " ") .. " failed: " .. (stderr or ""))
		end
		if callback then
			callback(exitCode == 0, stdout or "")
		end
	end, args)
	if not task or not task:start() then
		log("could not start tailscale " .. table.concat(args, " "))
		if callback then
			callback(false, "")
		end
	end
end

local function toggleHdr()
	hs.eventtap.keyStroke(HDR_MODS, HDR_KEY)
end

local function loadState()
	return hs.settings.get(SETTINGS_KEY)
end

local function saveState(state)
	hs.settings.set(SETTINGS_KEY, state)
end

local function enable()
	if loadState() then
		return -- already active (e.g. a relaunch); don't toggle HDR twice
	end
	local state = { hdr = true, tailscale = false }
	saveState(state)
	toggleHdr()

	runTailscale({ "status", "--json" }, function(ok, stdout)
		if not ok then
			return
		end
		local status = hs.json.decode(stdout)
		if not status or status.BackendState ~= "Running" then
			return
		end
		runTailscale({ "down" }, function(downOk)
			if downOk then
				state.tailscale = true
				saveState(state)
			end
		end)
	end)
	hs.alert.show("GeForce NOW: HDR on, Tailscale off")
end

local function restore()
	local state = loadState()
	if not state then
		return
	end
	saveState(nil)
	if state.hdr then
		toggleHdr()
	end
	if state.tailscale then
		runTailscale({ "up" })
	end
	hs.alert.show("GeForce NOW closed: settings restored")
end

local function isRunning()
	return #hs.application.applicationsForBundleID(BUNDLE_ID) > 0
end

function M.start()
	M.watcher = hs.application.watcher.new(function(_, event, app)
		if not app or app:bundleID() ~= BUNDLE_ID then
			return
		end
		if event == hs.application.watcher.launched then
			enable()
		elseif event == hs.application.watcher.terminated then
			-- Wait briefly: GeForce NOW can relaunch itself after updates.
			hs.timer.doAfter(3, function()
				if not isRunning() then
					restore()
				end
			end)
		end
	end)
	M.watcher:start()

	-- Recover from a quit that happened while Hammerspoon wasn't running.
	if loadState() and not isRunning() then
		restore()
	end
	return M
end

return M
