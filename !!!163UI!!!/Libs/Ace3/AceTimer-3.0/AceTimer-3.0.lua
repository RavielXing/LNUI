local MAJOR, MINOR = "AceTimer-3.0", 17
local AceTimer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceTimer then return end
AceTimer.activeTimers = AceTimer.activeTimers or {}
local activeTimers = AceTimer.activeTimers
local type, unpack, next, error, select = type, unpack, next, error, select
local GetTime, C_TimerAfter = GetTime, C_Timer.After

local function new(self, loop, func, delay, ...)
	if delay < 0.01 then
		delay = 0.01
	end

	local timer = {
		object = self,
		func = func,
		looping = loop,
		argsCount = select("#", ...),
		delay = delay,
		ends = GetTime() + delay,
		...
	}

	activeTimers[timer] = timer

	timer.callback = function()
		if not timer.cancelled then
			if type(timer.func) == "string" then
				timer.object[timer.func](timer.object, unpack(timer, 1, timer.argsCount))
			else
				timer.func(unpack(timer, 1, timer.argsCount))
			end

			if timer.looping and not timer.cancelled then
				local time = GetTime()
				local ndelay = timer.delay - (time - timer.ends)
				if ndelay < 0.01 then ndelay = 0.01 end
				C_TimerAfter(ndelay, timer.callback)
				timer.ends = time + ndelay
			else
				activeTimers[timer.handle or timer] = nil
			end
		end
	end

	C_TimerAfter(delay, timer.callback)
	return timer
end

function AceTimer:ScheduleTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, nil, func, delay, ...)
end

function AceTimer:ScheduleRepeatingTimer(func, delay, ...)
	if not func or not delay then
		error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(func) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[func] then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): Tried to register '"..func.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, true, func, delay, ...)
end


function AceTimer:CancelTimer(id)
	local timer = activeTimers[id]

	if not timer then
		return false
	else
		timer.cancelled = true
		activeTimers[id] = nil
		return true
	end
end

function AceTimer:CancelAllTimers()
	for k,v in next, activeTimers do
		if v.object == self then
			AceTimer.CancelTimer(self, k)
		end
	end
end


function AceTimer:TimeLeft(id)
	local timer = activeTimers[id]
	if not timer then
		return 0
	else
		return timer.ends - GetTime()
	end
end

if oldminor and oldminor < 10 then
	AceTimer.frame:SetScript("OnUpdate", nil)
	AceTimer.frame:SetScript("OnEvent", nil)
	AceTimer.frame:UnregisterAllEvents()
	for object,timers in next, AceTimer.selfs do
		for handle,timer in next, timers do
			if type(timer) == "table" and timer.callback then
				local newTimer
				if timer.delay then
					newTimer = AceTimer.ScheduleRepeatingTimer(timer.object, timer.callback, timer.delay, timer.arg)
				else
					newTimer = AceTimer.ScheduleTimer(timer.object, timer.callback, timer.when - GetTime(), timer.arg)
				end
				activeTimers[newTimer] = nil
				activeTimers[handle] = newTimer
				newTimer.handle = handle
			end
		end
	end
	AceTimer.selfs = nil
	AceTimer.hash = nil
	AceTimer.debug = nil
elseif oldminor and oldminor < 17 then
	AceTimer.inactiveTimers = nil
	AceTimer.frame = nil
	local oldTimers = AceTimer.activeTimers
	AceTimer.activeTimers = {}
	activeTimers = AceTimer.activeTimers
	for handle, timer in next, oldTimers do
		local newTimer
		local duration, elapsed = timer:GetDuration(), timer:GetElapsed()
		timer:GetParent():Stop()
		if timer.looping then
			newTimer = AceTimer.ScheduleRepeatingTimer(timer.object, timer.func, duration, unpack(timer.args, 1, timer.argsCount))
		else
			newTimer = AceTimer.ScheduleTimer(timer.object, timer.func, duration - elapsed, unpack(timer.args, 1, timer.argsCount))
		end
		activeTimers[newTimer] = nil
		activeTimers[handle] = newTimer
		newTimer.handle = handle
	end

	if oldminor < 13 and AceTimer.hashCompatTable then
		for handle, id in next, AceTimer.hashCompatTable do
			local t = activeTimers[id]
			if t then
				activeTimers[id] = nil
				activeTimers[handle] = t
				t.handle = handle
			end
		end
		AceTimer.hashCompatTable = nil
	end
end

AceTimer.embeds = AceTimer.embeds or {}

local mixins = {
	"ScheduleTimer", "ScheduleRepeatingTimer",
	"CancelTimer", "CancelAllTimers",
	"TimeLeft"
}

function AceTimer:Embed(target)
	AceTimer.embeds[target] = true
	for _,v in next, mixins do
		target[v] = AceTimer[v]
	end
	return target
end

function AceTimer:OnEmbedDisable(target)
	target:CancelAllTimers()
end

for addon in next, AceTimer.embeds do
	AceTimer:Embed(addon)
end
