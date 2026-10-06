local _, GF = ...

local Bridge = {}
GF.NativeApplicantAlertBridge = Bridge

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
