-- ctrl+j/k move down/up in Rex's pickers (session switcher, command palette).
--
-- Karabiner's ctrl+j/k rule is per app, and in Rex those keys must reach the
-- terminal: ~/.config/rex/init.lua uses them to move between panes. Rex's
-- pickers are native popups that never see init.lua bindings. So when Rex is
-- frontmost and a text field other than a terminal has focus, turn ctrl+j/k
-- into the down and up arrows. Every other key and app passes through.

local M = {}

local BUNDLE_ID = "com.superlogical.rex"
local TEXT_ROLES = { AXTextField = true, AXTextArea = true, AXComboBox = true, AXSearchField = true }
local ARROWS = { j = "down", k = "up" }

local function focusedPicker(app)
	local element = hs.axuielement.applicationElement(app)
	if not element then
		return false
	end
	element:setTimeout(0.2)
	local focused = element:attributeValue("AXFocusedUIElement")
	if not focused then
		return false
	end
	-- Rex terminals are AXTextArea elements described as "Terminal".
	return TEXT_ROLES[focused:attributeValue("AXRole") or ""] == true
		and focused:attributeValue("AXDescription") ~= "Terminal"
end

-- Exposed for `hs -c` checks.
function M.pickerFocused()
	local app = hs.application.frontmostApplication()
	return app ~= nil and app:bundleID() == BUNDLE_ID and focusedPicker(app)
end

function M.start()
	local codes = hs.keycodes.map
	local keys = { [codes.j] = "j", [codes.k] = "k" }
	M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
		local key = keys[event:getKeyCode()]
		if not key then
			return false
		end
		local flags = event:getFlags()
		if not flags.ctrl or flags.cmd or flags.alt or flags.shift or flags.fn then
			return false
		end
		if not M.pickerFocused() then
			return false
		end
		local arrow = ARROWS[key]
		return true, { hs.eventtap.event.newKeyEvent({}, arrow, true), hs.eventtap.event.newKeyEvent({}, arrow, false) }
	end)
	M.tap:start()

	-- macOS disables a tap whose callback is slow; turn it back on.
	M.watchdog = hs.timer.doEvery(5, function()
		if not M.tap:isEnabled() then
			print("[rex_pickers] event tap was disabled; restarting")
			M.tap:start()
		end
	end)
	return M
end

return M
