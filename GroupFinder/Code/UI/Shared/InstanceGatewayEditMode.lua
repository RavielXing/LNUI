local _, GF = ...

-- Participate in Blizzard's editing session without registering an invented
-- EditModeSystem or writing to its secure system/layout collections.
GF.InstanceGatewayEditMode = GF.InstanceGatewayEditMode or {}
local EditMode = GF.InstanceGatewayEditMode

local function inCombat()
	return InCombatLockdown and InCombatLockdown() == true
end

-- A geometry-only adapter lets Blizzard choose its normal grid/edge/corner
-- candidates without registering our frame in either of its secure collections.
local SnapGeometry = {}

function SnapGeometry:GetScaledSelectionCenter()
	local x, y = self.frame:GetCenter()
	local scale = self.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

function SnapGeometry:GetScaledSelectionSides()
	local x, y = self:GetScaledSelectionCenter()
	local scale = self.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local halfWidth, halfHeight = self.frame:GetWidth() * scale / 2, self.frame:GetHeight() * scale / 2
	return x - halfWidth, x + halfWidth, y - halfHeight, y + halfHeight
end

function SnapGeometry:GetFrameMagneticEligibility(candidate)
	if candidate == self.frame or not candidate.IsVisible or not candidate:IsVisible()
		or not candidate.HasValidSelectionRect or not candidate:HasValidSelectionRect()
		or not candidate.GetScaledSelectionSides or not candidate.IsToTheLeftOfFrame
		or not candidate.IsAboveFrame
	then
		return false, false
	end
	local left, right, bottom, top = self:GetScaledSelectionSides()
	local otherLeft, otherRight, otherBottom, otherTop = candidate:GetScaledSelectionSides()
	return top >= otherBottom and bottom <= otherTop and (right < otherLeft or left > otherRight),
		right >= otherLeft and left <= otherRight and (top < otherBottom or bottom > otherTop)
end

-- Coordinates returned by magnetism are in UIParent units. Resolve them to an
-- absolute position, so snapping never anchors us to a protected Blizzard frame.
local function pointCoordinates(geometry, point)
	local left, right, bottom, top = geometry:GetScaledSelectionSides()
	local x, y = (left + right) / 2, (bottom + top) / 2
	if point:find("LEFT", 1, true) then x = left
	elseif point:find("RIGHT", 1, true) then x = right end
	if point:find("TOP", 1, true) then y = top
	elseif point:find("BOTTOM", 1, true) then y = bottom end
	return x, y
end

function EditMode:GetSnapCandidates()
	local manager, magnetism = EditModeManagerFrame, EditModeMagnetismManager
	local frame = GF.InstanceGatewayOverlay and GF.InstanceGatewayOverlay.frame
	if not self.dragging or not self.editing or inCombat() or not frame
		or not manager or not manager:IsShown() or not manager:IsEditModeActive()
		or not manager.IsSnapEnabled or not manager:IsSnapEnabled()
		or not magnetism or not magnetism.GetMagneticFrameInfos
		or not magnetism.UpdateTopLevelParentPoints or not UIParent.GetRect
		or not frame:GetCenter() or not UIParent:GetRect()
	then
		return
	end
	self._snapGeometry = self._snapGeometry or setmetatable({}, { __index = SnapGeometry })
	self._snapGeometry.frame = frame
	-- Keep root bounds fresh without writing any fields on Blizzard's manager.
	if not self._magnetism or self._magnetismSource ~= magnetism then
		self._magnetism = setmetatable({}, { __index = magnetism })
		self._magnetismSource = magnetism
	end
	-- Our selection does not deselect Blizzard's active system. That stationary
	-- system is absent from magneticFrames but must still be a usable target.
	local frames = self._magnetism.magneticFrames
	if not rawget(self._magnetism, "magneticFrames") then
		frames = {}
		self._magnetism.magneticFrames = frames
	end
	for candidate in pairs(frames) do frames[candidate] = nil end
	for candidate in pairs(magnetism.magneticFrames or {}) do frames[candidate] = true end
	for _, candidate in ipairs(manager.registeredSystemFrames or {}) do
		if candidate.isSelected and not candidate.isDragging then frames[candidate] = true end
	end
	self._magnetism:UpdateTopLevelParentPoints()
	local ok, candidates = pcall(self._magnetism.GetMagneticFrameInfos, self._magnetism, self._snapGeometry)
	if ok then return candidates end
end

function EditMode:ClearSnapPreview()
	if self._snapLinePool then self._snapLinePool:ReleaseAll() end
end

function EditMode:RefreshSnapPreview()
	self:ClearSnapPreview()
	local candidates = self:GetSnapCandidates()
	if not candidates or not EditModeUtil or not EditModeUtil.CreateLinePool
		or not SetupLineThickness or not self.selection then return end
	if not self._snapLinePool then
		self._snapLinePool = EditModeUtil.CreateLinePool(self.selection, "MagnetismPreviewLineTemplate")
	end
	local rootX, rootY = UIParent:GetCenter()
	for _, info in ipairs(candidates) do
		local target = info.frame == UIParent and self._rootGeometry or info.frame
		local x, y = pointCoordinates(target, info.relativePoint)
		local offset = info.offset or 0
		if info.isCornerSnap or info.isHorizontal then
			local line = self._snapLinePool:Acquire()
			line:SetStartPoint("TOP", UIParent, x + offset - rootX, 0)
			line:SetEndPoint("BOTTOM", UIParent, x + offset - rootX, 0)
			SetupLineThickness(line, 1.5)
			line:Show()
		end
		if info.isCornerSnap or not info.isHorizontal then
			local line = self._snapLinePool:Acquire()
			line:SetStartPoint("LEFT", UIParent, 0, y + offset - rootY)
			line:SetEndPoint("RIGHT", UIParent, 0, y + offset - rootY)
			SetupLineThickness(line, 1.5)
			line:Show()
		end
	end
end

function EditMode:ApplySnap(candidates)
	if not candidates then return end
	local geometry = self._snapGeometry
	local centerX, centerY = geometry:GetScaledSelectionCenter()
	local deltaX, deltaY = 0, 0
	for _, info in ipairs(candidates) do
		local target = info.frame == UIParent and self._rootGeometry or info.frame
		local fromX, fromY = pointCoordinates(geometry, info.point)
		local toX, toY = pointCoordinates(target, info.relativePoint)
		local offset = info.offset or 0
		if info.isCornerSnap or info.isHorizontal then deltaX = toX + offset - fromX end
		if info.isCornerSnap or not info.isHorizontal then deltaY = toY + offset - fromY end
	end
	local rootX, rootY = UIParent:GetCenter()
	local frame = geometry.frame
	local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER",
		(centerX + deltaX - rootX) * scale, (centerY + deltaY - rootY) * scale)
end

function EditMode:CanOpen()
	return not inCombat() and ShowUIPanel ~= nil and EditModeManagerFrame ~= nil
		and EditModeManagerFrame.CanEnterEditMode ~= nil
		and EditModeManagerFrame:CanEnterEditMode() == true
end

function EditMode:Open()
	if not self:CanOpen() then
		return false
	end
	self:Init()
	ShowUIPanel(EditModeManagerFrame)
	self:Sync()
	if self.editing and GF.MainFrame and GF.MainFrame.HideFrame then
		GF.MainFrame:HideFrame()
	end
	return self.editing == true
end

function EditMode:StartDragging()
	local overlay = GF.InstanceGatewayOverlay
	if not (self.editing and overlay and overlay.frame) or inCombat() then
		return
	end
	self._rootGeometry = self._rootGeometry or setmetatable({ frame = UIParent }, { __index = SnapGeometry })
	self.dragging = true
	overlay.frame:StartMoving()
	if self.selection then
		self.selection:SetScript("OnUpdate", function() EditMode:RefreshSnapPreview() end)
	end
end

function EditMode:StopDragging(applySnap)
	self:ClearSnapPreview()
	if self.selection then self.selection:SetScript("OnUpdate", nil) end
	if not self.dragging then
		return
	end
	local frame = GF.InstanceGatewayOverlay and GF.InstanceGatewayOverlay.frame
	if not frame then
		self.dragging = nil
		return
	end
	frame:StopMovingOrSizing()
	if applySnap then self:ApplySnap(self:GetSnapCandidates()) end
	self.dragging = nil
	frame:SetUserPlaced(false)
	GF.InstanceGatewayOverlay:SavePosition()
end

function EditMode:ResetPosition()
	if not self.editing or inCombat() then
		return
	end
	self:StopDragging()
	if GF.InstanceGatewayService then
		GF.InstanceGatewayService:ClearPosition()
	end
	if GF.InstanceGatewayOverlay then
		GF.InstanceGatewayOverlay:ApplyPosition()
	end
end

function EditMode:EnsureSelection(frame)
	if self.selection or not EditModeSystemSelectionMixin then
		return self.selection
	end
	local selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
	self.selection = selection
	selection:SetAllPoints(frame)
	selection:SetFrameStrata("HIGH")
	selection:SetFrameLevel(frame:GetFrameLevel() + 10)
	selection:SetSystem({ GetSystemName = function()
		return GF.L and GF.L.SET_INSTANCE_GATEWAY or "Instance difficulty overlay"
	end })
	-- Keep the real preview readable inside the native editing outline. The
	-- native default label/tooltip would cover it and can hide foreign tooltips.
	selection.UpdateLabelVisibility = function(self)
		self.Label:Hide()
		if self.Center then self.Center:SetAlpha(0) end
		if self.MouseOverHighlight.Center then self.MouseOverHighlight.Center:SetAlpha(0) end
	end
	selection.CheckShowInstructionalTooltip = function() end
	selection.HideInstructionalTooltip = function() end
	selection:SetScript("OnMouseDown", function(self, button)
		if EditMode.editing and not inCombat() and button == "LeftButton" then
			self:ShowSelected()
		end
	end)
	selection:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then EditMode:ResetPosition() end
	end)
	selection:SetScript("OnDragStart", function() EditMode:StartDragging() end)
	selection:SetScript("OnDragStop", function() EditMode:StopDragging(true) end)
	selection:SetScript("OnHide", function() EditMode:StopDragging() end)
	selection:Hide()
	return selection
end

function EditMode:BindManager()
	local manager = EditModeManagerFrame
	if not manager or self.manager == manager then
		return
	end
	self.manager = manager
	-- Quick Keybind temporarily hides the editor without firing EditMode.Exit.
	-- Observe both visibility and session callbacks; repeated syncs are inert.
	manager:HookScript("OnShow", function() EditMode:Sync() end)
	manager:HookScript("OnHide", function() EditMode:Sync() end)
end

function EditMode:Sync()
	self:BindManager()
	local manager = EditModeManagerFrame
	local editing = manager and manager:IsShown() and manager:IsEditModeActive()
		and not inCombat() or false
	local overlay = GF.InstanceGatewayOverlay
	if not overlay or (self.editing == true) == editing then
		return
	end
	if not editing then
		self:StopDragging()
		if self.selection then self.selection:Hide() end
	end
	self.editing = editing
	overlay:SetEditing(editing)
	if editing then
		local selection = self:EnsureSelection(overlay.frame)
		if selection then selection:ShowHighlighted() end
	end
end

function EditMode:Init()
	if self.initialized or not (EventRegistry and CreateFrame) then
		return
	end
	self.initialized = true
	EventRegistry:RegisterCallback("EditMode.Enter", self.Sync, self)
	EventRegistry:RegisterCallback("EditMode.Exit", self.Sync, self)
	local events = CreateFrame("Frame")
	self.events = events
	events:RegisterEvent("ADDON_LOADED")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event, addon)
		if event ~= "ADDON_LOADED" or addon == "Blizzard_EditMode" then
			EditMode:Sync()
		end
	end)
	self:Sync()
end

-- RuntimeLifecycle starts editing integration after the overlay can read its saved position.
