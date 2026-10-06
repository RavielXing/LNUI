local _, GF = ...

-- Bound expensive event projections across frames, with one trailing update.
-- A pending deadline never moves: a continuous event stream cannot starve it.
GF.EventCoalescer = GF.EventCoalescer or {}
local Coalescer = GF.EventCoalescer

local function now()
	if type(GetTime) == "function" then return GetTime() end
	if type(GetTimePreciseSec) == "function" then return GetTimePreciseSec() end
	return 0
end

function Coalescer:Request(owner, slot, interval, callback, reason)
	local state = owner[slot]
	if not state then
		state = {}
		owner[slot] = state
	end
	state.reason = reason
	if state.pending then return false end
	state.pending = true
	local delay = state.lastRun and math.max(0, state.lastRun + interval - now()) or 0
	local function run()
		local latestReason = state.reason
		state.pending, state.timer, state.reason = nil, nil, nil
		state.lastRun = now()
		callback(owner, latestReason)
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		state.timer = C_Timer.NewTimer(delay, run)
	elseif C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(delay, run)
	else
		run()
	end
	return true
end
