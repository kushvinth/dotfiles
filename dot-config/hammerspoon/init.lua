require("hs.ipc") -- for the `hs` CLI (rolock)

-- Read-only mode, see readonly.lua; global so `hs -c 'readonly.lock()'` reaches it
readonly = require("readonly")

-- Pause music while dictating on speakers, see dictation.lua; global so the watcher isn't collected
dictationMic = require("dictation")

-- Reload when this config changes, so edits never leave stale code running.
-- Not while locked: a reload would drop the live lock's state.
reloadWatcher = hs.pathwatcher
	.new(hs.configdir, function()
		if not readonly.locked then
			hs.reload()
		end
	end)
	:start()

-- Toggle Ghostty with Cmd + Ctrl + Alt + T
hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "T", function()
	local app = hs.application.find("Ghostty")
	if app then
		if app:isFrontmost() then
			app:hide()
		else
			app:activate()
		end
	else
		hs.application.launchOrFocus("Ghostty")
	end
end)
