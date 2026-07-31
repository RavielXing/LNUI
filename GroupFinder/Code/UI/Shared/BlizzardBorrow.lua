local _, GF = ...

GF.BlizzardBorrow = {}

local BB = GF.BlizzardBorrow

local layoutCache = {}
local hideSinkFrame
local activeOwner

function BB.CacheLayout(widget)
	if not widget or layoutCache[widget] then
		return
	end
	local points = {}
	for i = 1, widget:GetNumPoints() do
		points[i] = { widget:GetPoint(i) }
	end
	local w, h = widget:GetSize()
	layoutCache[widget] = {
		parent = widget:GetParent(),
		points = points,
		width = w,
		height = h,
	}
end

function BB.RestoreLayout(widget)
	local info = widget and layoutCache[widget]
	if not info then
		return
	end
	widget:SetParent(info.parent)
	widget:ClearAllPoints()
	for _, pt in ipairs(info.points) do
		widget:SetPoint(unpack(pt))
	end
	if info.width and info.height and info.width > 0 and info.height > 0 then
		widget:SetSize(info.width, info.height)
	end
end

function BB.EmbedFill(widget, parent, anchor, w, h)
	if not widget or not parent or not anchor then
		return
	end
	widget:SetParent(parent)
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	if w and h then
		widget:SetSize(w, h)
	else
		widget:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	end
	widget:SetFrameLevel(parent:GetFrameLevel() + 2)
	widget:Show()
end

function BB.SetActiveOwner(owner)
	activeOwner = owner
	GF.nativeControlActiveOwner = owner
end

function BB.GetActiveOwner()
	return activeOwner or GF.nativeControlActiveOwner
end

function BB.MarkBorrowed(widget, owner, channel)
	if not widget then
		return
	end
	widget._gfBorrowOwner = owner
	widget._gfBorrowChannel = channel
end

function BB.ClearBorrowed(widget, owner, channel)
	if not widget then
		return
	end
	if owner and widget._gfBorrowOwner ~= owner then
		return
	end
	if channel and widget._gfBorrowChannel ~= channel then
		return
	end
	widget._gfBorrowOwner = nil
	widget._gfBorrowChannel = nil
end

function BB.IsBorrowedBy(widget, owner, channel)
	if not widget then
		return false
	end
	if owner and widget._gfBorrowOwner ~= owner then
		return false
	end
	if channel and widget._gfBorrowChannel ~= channel then
		return false
	end
	return widget._gfBorrowOwner ~= nil
end

function BB.IsExternallyOwned(widget, nativeParent, owner, channel)
	if not widget or not widget.GetParent then
		return false
	end
	if BB.IsBorrowedBy(widget, owner, channel) then
		return false
	end
	local parent = widget:GetParent()
	if nativeParent and parent == nativeParent then
		return false
	end
	if parent == BB.GetHideSink() then
		return false
	end
	if widget._gfBorrowOwner and widget._gfBorrowOwner ~= owner then
		return true
	end
	return parent ~= nil and parent ~= nativeParent
end

function BB.GetHideSink()
	if not hideSinkFrame then
		hideSinkFrame = CreateFrame("Frame")
		hideSinkFrame:Hide()
	end
	return hideSinkFrame
end

function BB.ReadEditText(edit)
	if not edit or not edit.GetText then
		return nil
	end
	local text = edit:GetText()
	if issecretvalue and issecretvalue(text) then
		return nil
	end
	return text
end

local ACTIVE_ENTRY_EVENT = "LFG_LIST_ACTIVE_ENTRY_UPDATE"

local function getAceAddon(name)
	if not LibStub then
		return nil
	end
	local aceAddon = LibStub("AceAddon-3.0", true)
	if not (aceAddon and aceAddon.GetAddon) then
		return nil
	end
	return aceAddon:GetAddon(name, true)
end

local function isAceTargetEnabled(target)
	if not (target and target.IsEnabled) then
		return target ~= nil
	end
	local ok, enabled = pcall(target.IsEnabled, target)
	return ok and enabled == true
end

local function suspendAceActiveEntryConsumer(lease, target, callback)
	if not isAceTargetEnabled(target) then
		return true
	end
	if not (target.UnregisterEvent and target.RegisterEvent) then
		return false
	end
	local ok = pcall(target.UnregisterEvent, target, ACTIVE_ENTRY_EVENT)
	if not ok then
		return false
	end
	lease.suspended[#lease.suspended + 1] = {
		target = target,
		callback = callback,
	}
	return true
end

local function restoreAceActiveEntryConsumers(lease)
	if not (lease and lease.suspended) then
		return true
	end
	local restored = true
	local pending = {}
	for index = #lease.suspended, 1, -1 do
		local state = lease.suspended[index]
		local ok
		if state.callback then
			ok = pcall(
				state.target.RegisterEvent,
				state.target,
				ACTIVE_ENTRY_EVENT,
				state.callback
			)
		else
			ok = pcall(
				state.target.RegisterEvent,
				state.target,
				ACTIVE_ENTRY_EVENT
			)
		end
		restored = ok and restored
		if not ok then
			pending[#pending + 1] = state
		end
	end
	lease.suspended = #pending > 0 and pending or nil
	return restored
end

local function getMeetingStoneCreatePanel()
	local meetingStone = getAceAddon("MeetingStone")
	if not (meetingStone and meetingStone.GetModule) then
		return nil
	end
	return meetingStone:GetModule("CreatePanel", true)
end

-- CopyActiveEntryInfoToCreationFields() is the only supported way for addon
-- code to move protected listing text into Blizzard's creation state. During
-- RemoveListing(), known AceEvent consumers otherwise process the synchronous
-- inactive event and clear that singleton state before CreateListing() runs.
-- Suspend only that one inactive dispatch, then restore every listener before
-- the new listing is created so normal created=true handling still runs.
function BB.AcquireEntryCreationBumpLease()
	local ec = LFGListFrame and LFGListFrame.EntryCreation
	local nameEdit = ec and ec.Name
	local descriptionEdit = ec and ec.Description and ec.Description.EditBox
	if not (nameEdit and descriptionEdit) then
		return nil
	end
	local lease = { suspended = {} }
	if not suspendAceActiveEntryConsumer(
		lease,
		getMeetingStoneCreatePanel(),
		nil
	) or not suspendAceActiveEntryConsumer(
		lease,
		getAceAddon("MyKeyStone"),
		"HandleMeetingStoneActiveEntryUpdate"
	) then
		restoreAceActiveEntryConsumers(lease)
		return nil
	end
	return lease
end

function BB.ResumeEntryCreationBumpConsumers(lease)
	return restoreAceActiveEntryConsumers(lease)
end

function BB.ReleaseEntryCreationBumpLease(lease)
	restoreAceActiveEntryConsumers(lease)
end

if GF.Listing and GF.Listing.SetBumpFieldBridge then
	GF.Listing:SetBumpFieldBridge({
		Acquire = BB.AcquireEntryCreationBumpLease,
		ResumeAfterRemove = BB.ResumeEntryCreationBumpConsumers,
		Release = BB.ReleaseEntryCreationBumpLease,
	})
end
