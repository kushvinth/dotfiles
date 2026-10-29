-- Read-only mode: swallow every keyboard/trackpad/mouse event, keep the screen live.
-- Driven by `rolock` (hs -c). Hyper+S+L locks (Karabiner); pressed again while locked it
-- asks for Touch ID (rolock-verify). No keys reach any app while locked.
-- Fail-open: if Hammerspoon dies or stalls, macOS drops the tap and input comes back.
local M = { locked = false }

local BIN = "/run/current-system/sw/bin/"
local VERIFY, HUD = BIN .. "rolock-verify", BIN .. "rolock-hud"
local ICON = hs.configdir .. "/rolock.png"
local SKETCHYBAR = "/opt/homebrew/bin/sketchybar"
local log = hs.logger.new("rolock", "info")

local allTypes = {}
for _, t in pairs(hs.eventtap.event.types) do
	allTypes[#allTypes + 1] = t
end
local T = hs.eventtap.event.types
local moveTypes = {
	[T.mouseMoved] = true,
	[T.leftMouseDragged] = true,
	[T.rightMouseDragged] = true,
	[T.otherMouseDragged] = true,
}

local tap, guard, activity
local checking = false
local hud -- rolock-hud while locked; replaced to change its text, terminated on unlock
local verifyTask -- keep a reference: an unreferenced hs.task can be garbage-collected mid-prompt

local tasks = {} -- pinned until they exit (see verifyTask)
local function run(path, args, done)
	local t
	t = hs.task.new(path, function(...)
		tasks[t] = nil
		if done then
			done(...)
		end
	end, args)
	-- a missing binary (e.g. before darnix) must not abort a lock halfway;
	-- start() returns false (it does not throw) when the launch fails
	local ok, started = false, false
	if t then
		ok, started = pcall(t.start, t)
	end
	if not (ok and started) then
		log.e("could not start " .. path)
		return nil
	end
	tasks[t] = true
	return t
end

local function setLabel(msg)
	if hud then
		-- swap in a new pill (no fade) rather than talking to the old one
		hud:terminate()
		hud = run(HUD, { msg or (checking and "Touch ID to Unlock" or "Read Only"), "--icon", ICON, "--instant" })
	end
end

-- Keep the Mac awake with the lid closed (pmset disablesleep). Needs the NOPASSWD rule in
-- nix/modules/darwin/security.nix; -n makes sudo fail instead of prompting.
local function lidSleep(disabled)
	run(
		"/usr/bin/sudo",
		{ "-n", "/usr/bin/pmset", "-a", "disablesleep", disabled and "1" or "0" },
		function(code, _, err)
			if code ~= 0 then
				log.e("pmset disablesleep failed: " .. (err or code))
			end
		end
	)
end

local function trigger()
	run(SKETCHYBAR, { "--trigger", "readonly_changed", "LOCKED=" .. (M.locked and 1 or 0) })
end

local function verify()
	if checking then
		return
	end
	checking = true
	setLabel()
	verifyTask = hs.task.new(VERIFY, function(code, _, err)
		checking, verifyTask = false, nil
		log.i("touch ID exit " .. code .. " " .. (err or ""))
		if code == 0 then
			return M.unlock()
		end
		-- 2: Touch ID cannot succeed (lid closed, locked out after failed scans)
		setLabel(code == 2 and "Touch ID unavailable: Hyper+S+0" or "Try Again")
	end)
	if not verifyTask:start() then
		checking, verifyTask = false, nil
		log.e("could not start " .. VERIFY)
		setLabel("Try Again")
	end
end

local function engage()
	if M.locked then
		return -- a second deferred lock (Secure Input path) must not replace a live tap/timers/HUD
	end
	M.locked = true
	lidSleep(true)
	hs.caffeinate.set("displayIdle", true)
	hs.caffeinate.set("systemIdle", true)
	-- swallowed input looks like idle; keep the screensaver / auto-lock from hiding the screen
	activity = hs.timer.doEvery(30, function()
		hs.caffeinate.declareUserActivity()
	end)
	hud = run(HUD, { "Read Only", "--icon", ICON })
	-- swallowing a move hides it from apps, but WindowServer still moves the cursor: warp it back
	local pin = hs.mouse.absolutePosition()
	tap = hs.eventtap
		.new(allTypes, function(e)
			if moveTypes[e:getType()] then
				local p = hs.mouse.absolutePosition()
				if p.x ~= pin.x or p.y ~= pin.y then -- guard: a warp that posts its own move must not loop
					hs.mouse.absolutePosition(pin)
				end
			end
			return true
		end)
		:start()
	-- macOS disables a tap whose callback was slow; turn it back on
	guard = hs.timer.doEvery(1, function()
		if not tap:isEnabled() then
			tap:start()
		end
	end)
	trigger()
end

function M.lock()
	if M.locked then
		return verify()
	end
	-- Secure Input (focused password field, Terminal secure entry) hides keys from taps.
	if not hs.eventtap.isSecureInputEnabled() then
		return engage()
	end
	hs.application.launchOrFocus("Finder")
	hs.timer.doAfter(0.5, function()
		if hs.eventtap.isSecureInputEnabled() then
			hs.alert.show("rolock: Secure Input is on (password field / Terminal secure entry), not locking")
		else
			engage()
		end
	end)
end

function M.unlock()
	if not M.locked then
		return
	end
	-- nil-safe: a lock that crashed halfway must still be undoable (force-unlock / Hyper+S+0)
	for _, o in pairs({ tap = tap, guard = guard, activity = activity }) do
		pcall(o.stop, o)
	end
	if hud then
		pcall(hud.terminate, hud)
	end
	tap, guard, activity, hud = nil, nil, nil, nil
	hs.caffeinate.set("displayIdle", false)
	hs.caffeinate.set("systemIdle", false)
	lidSleep(false)
	M.locked, checking = false, false
	run(HUD, { "Unlocked", "--icon", ICON, "--for", "1.5", "--instant" })
	trigger()
end

-- a crash or reload while locked loses `locked` but not the persisted pmset flag
lidSleep(false)

return M
