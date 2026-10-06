local _, GF = ...

-- Blizzard's search-entry hover handler assumes the result is still present.
-- Protect only that UI callback; leave native globals and application APIs intact.
GF.NativeSearchTooltipGuard = {}
local Guard = GF.NativeSearchTooltipGuard

local function hasNativeInfo(resultID)
	local service = GF.ApplicationService
	if not (service and type(service.GetNativeResultInfo) == "function") then
		return false
	end
	local info = service:GetNativeResultInfo(resultID)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, info)
		if not ok or secret then return false end
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, info)
		if not ok or accessible ~= true then return false end
	end
	return type(info) == "table"
end

local function hideTooltip(tooltip)
	if tooltip and type(tooltip.Hide) == "function" then tooltip:Hide() end
end

function Guard:ShowTooltip(tooltip, owner, resultID)
	if not tooltip or type(LFGListUtil_SetSearchEntryTooltip) ~= "function"
		or not hasNativeInfo(resultID) then hideTooltip(tooltip); return false end
	tooltip:SetOwner(owner, "ANCHOR_RIGHT", 25, 0)
	-- Owner/font hooks can invalidate the ID after the first availability read.
	if not hasNativeInfo(resultID) then hideTooltip(tooltip); return false end
	local ok = pcall(LFGListUtil_SetSearchEntryTooltip, tooltip, resultID)
	if not ok then hideTooltip(tooltip) end
	return ok
end

function Guard:ProtectEntry(entry)
	if not entry or type(entry.GetScript) ~= "function"
		or type(entry.SetScript) ~= "function" then return false end
	local original = entry:GetScript("OnEnter")
	if entry._gfNativeSearchTooltipGuard
		and original == entry._gfNativeSearchTooltipGuard then return true end
	if type(original) ~= "function" then return false end
	local function onEnter(owner, ...)
		-- Read the current ID on every hover: Blizzard reuses these row frames.
		if hasNativeInfo(owner.resultID) then
			local ok = pcall(original, owner, ...)
			if ok then return end
		end
		hideTooltip(GameTooltip)
		if owner.Highlight and type(owner.Highlight.Hide) == "function" then
			owner.Highlight:Hide()
		end
	end
	local ok = pcall(entry.SetScript, entry, "OnEnter", onEnter)
	if ok then entry._gfNativeSearchTooltipGuard = onEnter end
	return ok
end

function Guard:Install()
	if not self._installed then
		if type(hooksecurefunc) ~= "function"
			or type(LFGListSearchEntry_Update) ~= "function" then return false end
		local ok = pcall(hooksecurefunc, "LFGListSearchEntry_Update", function(entry)
			Guard:ProtectEntry(entry)
		end)
		if not ok then return false end
		self._installed = true
	end
	local panel = LFGListFrame and LFGListFrame.SearchPanel
	local box = panel and panel.ScrollBox
	if box and type(box.GetFrames) == "function" then
		local ok, frames = pcall(box.GetFrames, box)
		if ok and type(frames) == "table" then
			for _, entry in ipairs(frames) do self:ProtectEntry(entry) end
		end
	end
	return true
end
