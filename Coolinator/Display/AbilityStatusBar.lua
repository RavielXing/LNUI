---@class addonTableCoolinator
local addonTable = select(2, ...)

local textsByKey = {
  Duration = "duration",
  Name = "name",
}

addonTable.Display.AbilityStatusBarMixin = {}

function addonTable.Display.AbilityStatusBarMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)

  self.statusBar = CreateFrame("StatusBar", nil, self)
  self.statusBar:SetAllPoints()

  self.background = self.statusBar:CreateTexture(nil, "BACKGROUND")
  self.background:SetAllPoints()
  self.borderWrapper = CreateFrame("Frame", nil, self)
  self.borderWrapper:SetAllPoints()
  self.border = self.borderWrapper:CreateTexture(nil, "BORDER")
  self.border:SetPoint("CENTER", self.statusBar)
  self.borderMask = self.statusBar:CreateMaskTexture()
  self.borderMask:SetAllPoints(self.statusBar)

  self.Icon = self:CreateTexture(nil, "OVERLAY")
  self.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  self.Icon:SetPoint("CENTER")

  addonTable.Display.GenerateTexts(self, textsByKey)

  self.DurationBinding = C_DurationUtil.CreateDurationTextBinding()
  self.DurationBinding:SetFontString(self.TextsContainer.Duration)
  self.DurationBinding:SetZeroDurationText("0")
  self.DurationBinding:SetFormatter(addonTable.Display.GetDurationFormatter(false))
end

function addonTable.Display.AbilityStatusBarMixin:Enable(details)
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN")

  addonTable.CallbackRegistry:RegisterCallback("Update.SpellIcons", function(_, spellID)
    if self.spellID and (not spellID or C_Spell.GetBaseSpell(self.spellID) == spellID) then
      self.Icon:SetTexture(C_Spell.GetSpellTexture(self.spellID))
    end
  end, self)

  addonTable.CallbackRegistry:RegisterCallback("Update.SpellsDisplay", function(_, spellID)
    if not self.spellID then
      return
    end
    local override = C_Spell.GetOverrideSpell(self.details.resource.spellID)
    if override ~= self.spellID then
      self:UpdateSpellByID(override)
    end
  end, self)
end

function addonTable.Display.AbilityStatusBarMixin:Disable(details)
  self:UnregisterAllEvents()

  if self.ticker then
    self.ticker:Cancel()
  end
end

function addonTable.Display.AbilityStatusBarMixin:OnEvent()
  self:UpdateSpellByID(self.spellID)
end

function addonTable.Display.AbilityStatusBarMixin:Setup(details)
  self.details = details

  self.rawWidth, self.rawHeight, self.borderWidth, self.borderHeight, self.lowerScale = addonTable.Display.ApplyStatusBar(details, self.statusBar, self.border, self.borderMask, self.background)

  self.ignoreGCD = details.resource.spellID ~= addonTable.Constants.GCD and not addonTable.Config.Get(addonTable.Config.Options.SHOW_GCD_SWIPE)
  self:UpdateSpellByID(addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) or details.resource.spellID)

  self.borderWrapper:SetFrameLevel(self.statusBar:GetFrameLevel() + 2)
  self.TextsContainer:SetFrameLevel(self.statusBar:GetFrameLevel() + 4)

  addonTable.Display.ApplyTexts(self, details, textsByKey, details.scale)

  self.Icon:SetShown(details.icon.show)
end

function addonTable.Display.AbilityStatusBarMixin:GetDefaultSize()
  return PixelUtil.ConvertPixelsToUIForRegion(self.rawWidth * self.details.scale, self), PixelUtil.ConvertPixelsToUIForRegion(self.rawHeight * self.details.scale, self)
end

function addonTable.Display.AbilityStatusBarMixin:ApplySize(width, height)
  local sizing = addonTable.Display.GetSizingForStatusBar(self, width, height)
  PixelUtil.SetSize(self, sizing.rawWidth, sizing.rawHeight)
  PixelUtil.SetSize(self.statusBar, sizing.statusWidth * self.lowerScale, sizing.statusHeight * self.lowerScale)
  PixelUtil.SetSize(self.border, sizing.borderWidth * self.lowerScale, sizing.borderHeight * self.lowerScale)
  if sizing.iconSize > 0 then
    self.Icon:Show()
    PixelUtil.SetSize(self.Icon, sizing.iconSize, sizing.iconSize)
  else
    self.Icon:Hide()
  end

  self.Icon:ClearAllPoints()
  self.statusBar:ClearAllPoints()
  self.TextsContainer.Duration:ClearAllPoints()
  if self.details.layout == "horizontal" then
    self.Icon:SetPoint(self.details.icon.position == "left" and "LEFT" or "RIGHT")
    self.statusBar:SetPoint(self.details.icon.position == "left" and "RIGHT" or "LEFT")
  else
    self.Icon:SetPoint(self.details.icon.position == "left" and "BOTTOM" or "TOP")
    self.statusBar:SetPoint(self.details.icon.position == "left" and "TOP" or "BOTTOM")
  end
  addonTable.Display.SizeTextsForBar(self, self.details, textsByKey, self.details.scale)
end

function addonTable.Display.AbilityStatusBarMixin:UpdateSpellByID(spellID)
  self.spellID = spellID

  self.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))

  if self.ticker then
    self.ticker:Cancel()
  end

  local baseDuration = C_Spell.GetSpellCooldownDuration(spellID, self.ignoreGCD)
  self.statusBar:SetTimerDuration(baseDuration, nil, Enum.StatusBarTimerDirection.RemainingTime)

  self.DurationBinding:SetDuration(baseDuration)
  self.DurationBinding:Enable()
  self.DurationBinding:UpdateFontString()

  if C_Spell.IsSpellDataCached(spellID) then
    self.TextsContainer.Name:SetText(C_Spell.GetSpellName(spellID))
  else
    Spell:CreateFromSpellID(spellID):ContinueOnSpellLoad(function()
      self.TextsContainer.Name:SetText(C_Spell.GetSpellName(spellID))
    end)
  end

  local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
  self:SetShown(cooldownInfo.isActive and (not self.ignoreGCD or not cooldownInfo.isOnGCD), 0, 1)

  self.ticker = C_Timer.NewTicker(0.1, function()
    cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    self:SetShown(cooldownInfo.isActive and (not self.ignoreGCD or not cooldownInfo.isOnGCD), 0, 1)
  end)
end
