------------------------------------------------------------
-- IconFrame.lua  (Optimized for WoW 12.1)
--
-- Changes:
-- 1. Replaced per-icon SPELL_UPDATE_COOLDOWN registration with
--    a single singleton listener using weak table (zero overhead per icon)
-- 2. Removed redundant pcall usage
------------------------------------------------------------

local type = type
local CreateFrame = CreateFrame

local _, addon = ...
local templates = addon.templates

------------------------------------------------------------
-- Icon frame
------------------------------------------------------------

local function IconFrame_UpdateCooldown(self)
	local spell = self.data and self.data.id
	if spell then
		local spellCooldownInfo = C_Spell.GetSpellCooldown(spell)
		if spellCooldownInfo then
			local start, duration, enable = spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isEnabled
			-- WoW 12.1 Fix: startTime/duration may be "secret number" in tainted context
			local ok = pcall(function()
				if start and start > 0 and duration > 0 and enable then
					self.cooldown:SetCooldown(start, duration)
					self.cooldown:Show()
				else
					self.cooldown:Hide()
				end
			end)
			if not ok then
				self.cooldown:Hide()
			end
		else
			self.cooldown:Hide()
		end
	else
		self.cooldown:Hide()
	end
end

local function IconFrame_SetSpell(self, data)
	self.data = data
	self.icon:SetTexture(data and data.icon)
	IconFrame_UpdateCooldown(self)
end

local function IconFrame_SetIcon(self, icon)
	if icon then
		self.icon:SetTexture(icon)
	else
		local data = self.data
		self.icon:SetTexture(data and data.icon)
	end
end

local function IconFrame_SetActive(self, active)
	if active then
		IconFrame_SetIcon(self, type(active) == "string" and active or "Interface\\Icons\\Spell_Nature_WispSplode")
	else
		IconFrame_SetIcon(self)
	end
end

local function IconFrame_SetDesaturated(self, desaturated)
	self.desaturated = desaturated
	if desaturated then
		self.icon:SetVertexColor(0.3, 0.3, 0.3)
	else
		self.icon:SetVertexColor(1, 1, 1)
	end
end

local function IconFrame_SetText(self, text, r, g, b)
	self.text:SetText(text)
	if r then
		self.text:SetTextColor(r, g, b, 1)
	end
end

-- SINGLETON: One event listener for all icon frames, weak-referenced
local cooldownRegistry = setmetatable({}, { __mode = "k" })
local cooldownUpdater = CreateFrame("Frame")
cooldownUpdater:SetScript("OnEvent", function(self, event)
	for frame in pairs(cooldownRegistry) do
		IconFrame_UpdateCooldown(frame)
	end
end)
cooldownUpdater:RegisterEvent("SPELL_UPDATE_COOLDOWN")

function templates.CreateIconFrame(parent)
	local frame = CreateFrame('Button', '$parentIcon', parent, 'ActionButtonTemplate')
	frame:EnableMouse(false)

	frame.icon = _G[frame:GetName()..'Icon']

	local outset = 0
	frame.border = frame:CreateTexture('$parentBorder', 'OVERLAY')
	frame.border:SetSize(62, 62)
	frame.border:SetPoint("CENTER")
	frame.border:SetTexture[[Interface\Buttons\UI-ActionButton-Border]]
	frame.border:SetBlendMode("ADD")

	frame.text = frame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	frame.text:ClearAllPoints()
	frame.text:SetPoint("BOTTOM", frame, "BOTTOMRIGHT", -12, 5)

	frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	frame.cooldown:SetAllPoints(frame.icon)
	frame.cooldown.noCooldownCount = true
	frame.cooldown:SetAlpha(0.8)
	frame.cooldown:SetDrawEdge(true)
	frame.cooldown:SetFrameLevel(frame:GetFrameLevel())

	-- Register to singleton instead of per-frame event
	cooldownRegistry[frame] = true

	frame.SetSpell = IconFrame_SetSpell
	frame.SetIcon = IconFrame_SetIcon
	frame.SetActive = IconFrame_SetActive
	frame.SetDesaturated = IconFrame_SetDesaturated
	frame.SetText = IconFrame_SetText

	return frame
end