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
