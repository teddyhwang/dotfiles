require("hs.ipc")

hs.allowAppleScript(true)

-- Move apps to screen 2 and reevaluate Amethyst after display changes (including display wake)

local screen2Apps = { "Discord", "Cybertron Dashboard", "Spotify" }
local screen1Apps = { "Ghostty" }

-- Primary display (ultrawide) is screen 1; the first other display is screen 2.
-- allScreens() order is not guaranteed, so don't index it directly.
local function targetScreens()
	local primary = hs.screen.primaryScreen()
	if not primary then
		return nil
	end
	for _, s in ipairs(hs.screen.allScreens()) do
		if s:id() ~= primary:id() then
			return primary, s
		end
	end
	return nil
end

-- Calls fn(win, targetScreen) for each window of a pinned app that is on the wrong screen.
-- Skips windows with no screen or a zero-size frame (common right after wake), which
-- would make moveToScreen throw "not a rect".
local function forEachMisplacedWindow(fn)
	local screen1, screen2 = targetScreens()
	if not screen1 then
		return
	end
	for _, group in ipairs({ { screen2Apps, screen2 }, { screen1Apps, screen1 } }) do
		local apps, target = group[1], group[2]
		for _, appName in ipairs(apps) do
			local app = hs.application.find(appName)
			if app then
				for _, win in ipairs(app:allWindows()) do
					local ws = win:screen()
					local f = win:frame()
					if ws and f and f.w > 0 and f.h > 0 and ws:id() ~= target:id() then
						if fn(win, target) == false then
							return
						end
					end
				end
			end
		end
	end
end

local function hasMisplacedWindows()
	local found = false
	forEachMisplacedWindow(function()
		found = true
		return false
	end)
	return found
end

-- Debounced Amethyst reevaluate (⌥⇧Z), delayed so it doesn't undo the moves
AmethystReevaluateTimer = nil
local function reevaluateAmethyst()
	if AmethystReevaluateTimer then
		AmethystReevaluateTimer:stop()
	end
	AmethystReevaluateTimer = hs.timer.doAfter(2, function()
		AmethystReevaluateTimer = nil
		hs.eventtap.keyStroke({ "alt", "shift" }, "z")
	end)
end

function MoveAppsToScreen2()
	local movedAny = false
	forEachMisplacedWindow(function(win, target)
		local ok, err = pcall(function()
			win:moveToScreen(target, false, false, 0)
		end)
		if ok then
			movedAny = true
		else
			print("MoveAppsToScreen2: could not move " .. tostring(win:title()) .. ": " .. tostring(err))
		end
	end)
	if movedAny then
		reevaluateAmethyst()
	end
end

-- Screen watcher for display reconfiguration (global to prevent GC)
ScreenWatcher = hs.screen.watcher.new(function()
	for _, delay in ipairs({ 1, 3, 7 }) do
		hs.timer.doAfter(delay, MoveAppsToScreen2)
	end
	StartWindowPolling()
end)
ScreenWatcher:start()

-- Caffeinate watcher for wake/unlock events (global to prevent GC)
CaffeinateWatcher = hs.caffeinate.watcher.new(function(event)
	if
		event == hs.caffeinate.watcher.screensDidWake
		or event == hs.caffeinate.watcher.systemDidWake
		or event == hs.caffeinate.watcher.screensDidUnlock
		or event == hs.caffeinate.watcher.sessionDidBecomeActive
	then
		for _, delay in ipairs({ 3, 7, 12, 20 }) do
			hs.timer.doAfter(delay, MoveAppsToScreen2)
		end
		StartWindowPolling()
	end
end)
CaffeinateWatcher:start()

-- Poll every 5 seconds for misplaced windows, but only for 60 seconds after wake/display change
WindowPollTimer = nil
WindowPollStopTimer = nil

function StartWindowPolling()
	if WindowPollStopTimer then
		WindowPollStopTimer:stop()
	end
	if not WindowPollTimer then
		WindowPollTimer = hs.timer.doEvery(5, function()
			if hasMisplacedWindows() then
				MoveAppsToScreen2()
			end
		end)
	end
	WindowPollStopTimer = hs.timer.doAfter(60, function()
		if WindowPollTimer then
			WindowPollTimer:stop()
			WindowPollTimer = nil
		end
	end)
end

hs.hotkey.bind({ "cmd", "shift" }, "W", MoveAppsToScreen2)

-- HDR on and Tailscale off while GeForce NOW runs (global to prevent GC)
GeForceNow = require("geforce_now").start()

hs.alert.show("Hammerspoon loaded")
