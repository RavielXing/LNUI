---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AbilityStatusBarMixin = {}

function addonTable.Display.AbilityStatusBarMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)

  self.wrapper = CreateFrame("Frame", nil, self)
  self.wrapper:SetAllPoints()
  self.statusBar = CreateFrame("StatusBar", nil, self.wrapper)
  self.statusBar:SetAllPoints()

  self.background = self.statusBar:CreateTexture(nil, "BACKGROUND")
  self.background:SetAllPoints()
  self.borderWrapper = CreateFrame("Frame", nil, self.wrapper)
  self.borderWrapper:SetAllPoints()
  self.border = self.borderWrapper:CreateTexture(nil, "BORDER")
  self.border:SetPoint("CENTER", self.statusBar)
  self.borderMask = self.statusBar:CreateMaskTexture()
  self.borderMask:SetAllPoints(self.statusBar)

  self.icon = self.wrapper:CreateTexture(nil, "OVERLAY")
  self.icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  self.icon:SetPoint("CENTER")

  self.TextsContainer = CreateFrame("Frame", nil, self.wrapper)
  self.TextsContainer:SetAllPoints()
  self.TextsContainer.Charges = self.TextsContainer:CreateFontString(nil, nil, "NumberFontNormal")
  self.TextsContainer.Duration = self.TextsContainer:CreateFontString(nil, nil, "NumberFontNormal")
  self.DurationBinding = C_DurationUtil.CreateDurationTextBinding()
  self.DurationBinding:SetFontString(self.TextsContainer.Duration)
  self.DurationBinding:SetZeroDurationText("0")
  self.DurationBinding:SetFormatter(addonTable.Display.GetDurationFormatter(false))
end

function addonTable.Display.AbilityStatusBarMixin:Enable(details)
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN")

  addonTable.CallbackRegistry:RegisterCallback("Update.SpellIcons", function(_, spellID)
    if self.spellID and (not spellID or C_Spell.GetBaseSpell(self.spellID) == spellID) then
      self.icon:SetTexture(C_Spell.GetSpellTexture(self.spellID))
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
  self:SetScript("OnUpdate", self.OnUpdate)
  self.details = details

  self.rawWidth, self.rawHeight, self.borderWidth, self.borderHeight, self.lowerScale = addonTable.Display.ApplyStatusBar(details, self.statusBar, self.border, self.borderMask, self.background)

  self.ignoreGCD = details.resource.spellID ~= addonTable.Constants.GCD and not addonTable.Config.Get(addonTable.Config.Options.SHOW_GCD_SWIPE)
  self:UpdateSpellByID(addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) or details.resource.spellID)

  self.borderWrapper:SetFrameLevel(self.statusBar:GetFrameLevel() + 2)
  self.TextsContainer:SetFrameLevel(self.statusBar:GetFrameLevel() + 1)

  local font = addonTable.Config.Get(addonTable.Config.Options.NUMBER_FONT)
  if font.flags.slug then
    self.TextsContainer.Duration:SetScale(14/12)
    self.TextsContainer.Duration:SetTextScale(1)
  else
    self.TextsContainer.Duration:SetScale(1)
    self.TextsContainer.Duration:SetTextScale(14/12)
  end

  self.icon:SetShown(details.icon.show)
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
    self.icon:Show()
    PixelUtil.SetSize(self.icon, sizing.iconSize, sizing.iconSize)
  else
    self.icon:Hide()
  end

  PixelUtil.SetPoint(self.TextsContainer.Charges, "BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", -5, 5)

  self.icon:ClearAllPoints()
  self.statusBar:ClearAllPoints()
  self.TextsContainer.Duration:ClearAllPoints()
  if self.details.layout == "horizontal" then
    self.icon:SetPoint(self.details.icon.position == "left" and "LEFT" or "RIGHT")
    self.statusBar:SetPoint(self.details.icon.position == "left" and "RIGHT" or "LEFT")
    self.TextsContainer.Duration:SetPoint("RIGHT", self.statusBar, -8, 0)
  else
    self.icon:SetPoint(self.details.icon.position == "left" and "BOTTOM" or "TOP")
    self.statusBar:SetPoint(self.details.icon.position == "left" and "TOP" or "BOTTOM")
    self.TextsContainer.Duration:SetPoint("BOTTOM", self.statusBar, 0, 8)
  end
end

function addonTable.Display.AbilityStatusBarMixin:UpdateSpellByID(spellID)
  self.spellID = spellID

  self.icon:SetTexture(C_Spell.GetSpellTexture(spellID))

  if self.ticker then
    self.ticker:Cancel()
  end

  local baseDuration = C_Spell.GetSpellCooldownDuration(spellID, self.ignoreGCD)
  self.statusBar:SetTimerDuration(baseDuration, nil, Enum.StatusBarTimerDirection.RemainingTime)

  self.DurationBinding:SetDuration(baseDuration)
  self.DurationBinding:Enable()
  self.DurationBinding:UpdateFontString()

  self.wrapper:SetAlphaFromBoolean(baseDuration:IsZero(), 0, 1)

  self.ticker = C_Timer.NewTicker(0.1, function()
    baseDuration = C_Spell.GetSpellCooldownDuration(spellID, self.ignoreGCD)
    self.wrapper:SetAlphaFromBoolean(baseDuration:IsZero(), 0, 1)
  end)
end
