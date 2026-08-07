local _, GF = ...

GF.UI = GF.UI or {}

local DEFAULT_SPEED = 10
local DEFAULT_EPSILON = 0.05

local function clamp(value, minimum, maximum)
	return math.min(maximum, math.max(minimum, value))
end

local function getScrollRange(scroll)
	if not scroll or type(scroll.GetVerticalScrollRange) ~= "function" then
		return 0
	end
	return math.max(0, tonumber(scroll:GetVerticalScrollRange()) or 0)
end

local function getCurrentScroll(scroll)
	if not scroll or type(scroll.GetVerticalScroll) ~= "function" then
		return 0
	end
	return tonumber(scroll:GetVerticalScroll()) or 0
end

function GF.UI.CancelSmoothWheelScrolling(scroll)
	if not scroll then
		return
	end
	local driver = scroll._gfSmoothWheelDriver
	if driver and type(driver.SetScript) == "function" then
		driver:SetScript("OnUpdate", nil)
	end
	scroll._gfSmoothWheelActive = false
	scroll._gfSmoothWheelTarget = nil
	scroll._gfSmoothWheelExpectedOffset = nil
end

local function isWheelAllowed(scroll)
	local allow = scroll and scroll._gfWheelAllow
	return type(allow) ~= "function" or allow() == true
end

local function applySmoothOffset(scroll, value)
	scroll._gfSmoothWheelExpectedOffset = value
	scroll:SetVerticalScroll(value)
end

local function smoothWheelOnUpdate(driver, elapsed)
	local scroll = driver and driver._gfSmoothWheelScroll
	if not scroll then
		return
	end
	if scroll.IsShown and not scroll:IsShown() then
		GF.UI.CancelSmoothWheelScrolling(scroll)
		return
	end
	if not isWheelAllowed(scroll) then
		GF.UI.CancelSmoothWheelScrolling(scroll)
		return
	end

	local range = getScrollRange(scroll)
	local target = clamp(
		tonumber(scroll._gfSmoothWheelTarget) or getCurrentScroll(scroll),
		0,
		range)
	scroll._gfSmoothWheelTarget = target

	local current = getCurrentScroll(scroll)
	local delta = target - current
	local epsilon = math.max(
		0.001,
		tonumber(scroll._gfSmoothWheelEpsilon) or DEFAULT_EPSILON)
	if math.abs(delta) <= epsilon then
		applySmoothOffset(scroll, target)
		GF.UI.CancelSmoothWheelScrolling(scroll)
		return
	end

	local speed = math.max(
		0.01,
		tonumber(scroll._gfSmoothWheelSpeed) or DEFAULT_SPEED)
	local frameTime = math.max(0, tonumber(elapsed) or 0)
	local factor = clamp(1 - math.exp(-speed * frameTime), 0, 1)
	if factor > 0 then
		applySmoothOffset(scroll, current + delta * factor)
	end
end

local function startSmoothWheelScrolling(scroll)
	local driver = scroll._gfSmoothWheelDriver
	if not driver then
		driver = CreateFrame("Frame", nil, scroll)
		driver._gfSmoothWheelScroll = scroll
		scroll._gfSmoothWheelDriver = driver
	end
	scroll._gfSmoothWheelActive = true
	driver:SetScript("OnUpdate", smoothWheelOnUpdate)
end

local function getWheelStep(scroll)
	if type(GF.GetWheelScrollPixels) == "function" then
		return math.max(
			0,
			tonumber(GF.GetWheelScrollPixels(scroll._gfWheelRowH)) or 0)
	end
	return math.max(0, tonumber(scroll._gfWheelRowH) or 0)
end

local function smoothWheelHandler(scroll, direction)
	if type(direction) ~= "number" or direction == 0 then
		return
	end
	if not isWheelAllowed(scroll) then
		return
	end

	local current = getCurrentScroll(scroll)
	local base = scroll._gfSmoothWheelActive
		and tonumber(scroll._gfSmoothWheelTarget)
		or current
	base = base or current
	local destination = clamp(
		base - direction * getWheelStep(scroll),
		0,
		getScrollRange(scroll))
	scroll._gfSmoothWheelTarget = destination

	local epsilon = math.max(
		0.001,
		tonumber(scroll._gfSmoothWheelEpsilon) or DEFAULT_EPSILON)
	if math.abs(destination - current) <= epsilon then
		applySmoothOffset(scroll, destination)
		GF.UI.CancelSmoothWheelScrolling(scroll)
	else
		startSmoothWheelScrolling(scroll)
	end

	if type(scroll._gfOnWheelScrolled) == "function" then
		scroll._gfOnWheelScrolled(scroll, destination, direction)
	end
end

function GF.UI.BindSmoothWheelScrolling(scroll, opts)
	if not scroll or type(scroll.SetScript) ~= "function" then
		return
	end
	local options = type(opts) == "table" and opts or {}
	GF.UI.CancelSmoothWheelScrolling(scroll)
	scroll._gfSmoothWheelSpeed = math.max(
		0.01,
		tonumber(options.speed) or DEFAULT_SPEED)
	scroll._gfSmoothWheelEpsilon = math.max(
		0.001,
		tonumber(options.epsilon) or DEFAULT_EPSILON)
	if scroll.EnableMouseWheel then
		scroll:EnableMouseWheel(true)
	end
	scroll:SetScript("OnMouseWheel", smoothWheelHandler)
	if not scroll._gfSmoothWheelHideHooked and scroll.HookScript then
		scroll._gfSmoothWheelHideHooked = true
		scroll:HookScript("OnHide", function(frame)
			GF.UI.CancelSmoothWheelScrolling(frame)
		end)
	end
	if not scroll._gfSmoothWheelScrollHooked and scroll.HookScript then
		scroll._gfSmoothWheelScrollHooked = true
		scroll:HookScript("OnVerticalScroll", function(frame, offset)
			if not frame._gfSmoothWheelActive then
				return
			end
			local expected = tonumber(frame._gfSmoothWheelExpectedOffset)
			local actual = tonumber(offset) or getCurrentScroll(frame)
			local epsilon = math.max(
				0.001,
				tonumber(frame._gfSmoothWheelEpsilon)
					or DEFAULT_EPSILON)
			if expected == nil or math.abs(actual - expected) > epsilon then
				GF.UI.CancelSmoothWheelScrolling(frame)
			end
		end)
	end
end
