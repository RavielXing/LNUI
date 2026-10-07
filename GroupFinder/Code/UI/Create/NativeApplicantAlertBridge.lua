local _, GF = ...

local Bridge = {}
GF.NativeApplicantAlertBridge = Bridge

function Bridge:SetSoundEnabled(enabled)
	enabled = enabled == true
	if self._soundEnabled == enabled then return true end
	local apply
	if enabled then apply = UnmuteSoundFile else apply = MuteSoundFile end
	if type(apply) ~= "function" then return false end
	-- Mute only the native applicant file; keep the eye animation and other
	-- queues intact. Reapply once in every fresh Lua session after DB restore.
	local ok = pcall(apply, GF.NATIVE_APPLICANT_ALERT_SOUND_FILE_ID or 1067667)
	if ok then self._soundEnabled = enabled end
	return ok
end

local function clearApplicantAlert()
	local button = QueueStatusButton
	local cleared = false
	if button and type(button.SetGlowLock) == "function" then
		-- The native eye animation plays the default applicant sound while this
		-- lock is enabled. Leave every other queue's glow/sound lock untouched.
		button:SetGlowLock("lfglist-applicant", false)
		cleared = true
	end
	if LFGListFrame then
		LFGListFrame.stopAssistPings = false
	end
	return cleared
end

function Bridge:Clear()
	-- Background lifecycle cleanup must work without loading the workspace,
	-- and missing or unavailable native UI must not interrupt removal.
	local ok, cleared = pcall(clearApplicantAlert)
	return ok and cleared == true
end
