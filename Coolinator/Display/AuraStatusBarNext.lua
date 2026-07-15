---@class addonTableCoolinator
local addonTable = select(2, ...)

local textsByKey = {
  Duration = "duration",
  Name = "name",
}

addonTable.Display.AuraStatusBarNextMixin = {}

function addonTable.Display.AuraStatusBarNextMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)

  local function BarInit(frame)
    frame.statusBar = CreateFrame("StatusBar", nil, frame)
    frame.statusBar:SetPoint("CENTER")
    frame:SetDurationBar(frame.statusBar, {direction = Enum.StatusBarTimerDirection.RemainingTime})

    frame.background = frame.statusBar:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints(frame.statusBar)
    frame.borderWrapper = CreateFrame("Frame", nil, frame)
    frame.borderWrapper:SetAllPoints()
    frame.border = frame.borderWrapper:CreateTexture(nil, "BORDER")
    frame.border:SetPoint("CENTER", frame.statusBar)
    frame.borderMask = frame.statusBar:CreateMaskTexture()
    frame.borderMask:SetAllPoints(frame.statusBar)

    frame.Icon = frame:CreateTexture(nil, "OVERLAY")
    frame.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
    frame.Icon:SetPoint("CENTER")
    frame:SetIcon(frame.Icon)

    frame.TextsContainer = CreateFrame("Frame", nil, frame)
    frame.TextsContainer:SetAllPoints()
    frame.TextsContainer.Charges = frame.TextsContainer:CreateFontString(nil, nil, "NumberFontNormal")
    frame:SetApplicationCount(frame.TextsContainer.Charges)
    frame.TextsContainer.Duration = frame.TextsContainer:CreateFontString(nil, nil, "NumberFontNormal")
    frame.TextsContainer.Name = frame.TextsContainer:CreateFontString(nil, nil, "NumberFontNormal")
    frame:SetSpellName(frame.TextsContainer.Name)
  end

  self.helpful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.helpful:SetUnit("player")
  self.helpfulButton = self.helpful:AddAuraSlot("1", "HELPFUL|PLAYER", {})
  BarInit(self.helpfulButton)

  self.harmful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.harmful:SetUnit("target")
  self.harmfulButton = self.harmful:AddAuraSlot("1", "HARMFUL|PLAYER", {})
  BarInit(self.harmfulButton)

  self.helpfulButton:SetPoint("TOPLEFT", self)
  self.harmfulButton:SetPoint("TOPLEFT", self)
end

function addonTable.Display.AuraStatusBarNextMixin:Enable(details)
  self:RegisterUnitEvent("UNIT_AURA", "player", "target")
end

function addonTable.Display.AuraStatusBarNextMixin:Disable(details)
  self:UnregisterAllEvents()
  self.helpful:SetParent(self)
  self.harmful:SetParent(self)
end

function addonTable.Display.AuraStatusBarNextMixin:OnEvent()
  local parent = self:GetParent()
  if parent.TriggerLayout then
    parent:TriggerLayout()
  else
    self:Hide()
    self:Show()
  end
end

function addonTable.Display.AuraStatusBarNextMixin:Setup(details)
  self.details = details

  local format = "{}"
  local components = {}
  local display = self.details.texts.duration.display
  if #display == 2 then
    format = "{}/{}"
    components = {
      {
        property = addonTable.Display.ConvertDurationDisplayToComponent(display[1]),
        formatter = addonTable.Display.GetDurationFormatter(self.details.texts.duration.showFractions),
      },
      {
        property = addonTable.Display.ConvertDurationDisplayToComponent(display[2]),
        formatter = addonTable.Display.GetDurationFormatter(self.details.texts.duration.showFractions),
      }
    }
  else
    components = {{
      property = addonTable.Display.ConvertDurationDisplayToComponent(display[1]),
      formatter = addonTable.Display.GetDurationFormatter(self.details.texts.duration.showFractions),
    }}
  end

  local include = {
    includeSpellIDs = {[details.resource.spellID] = true}
  }
  if addonTable.State.CDM.auraMap[details.resource.spellID] then
    local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(addonTable.State.CDM.auraMap[details.resource.spellID])
    for _, spellID in ipairs(cooldownInfo.linkedSpellIDs) do
      include.includeSpellIDs[spellID] = true
    end
  end
  self.helpful:SetParent(UIParent)
  self.helpful:SetAuraSlotCandidateFilters("1", include)

  self.harmful:SetParent(UIParent)
  self.harmful:SetAuraSlotCandidateFilters("1", include)

  for _, auraButton in ipairs({self.helpfulButton, self.harmfulButton}) do
    auraButton.details = details
    auraButton:SetParent(self)
    auraButton.rawWidth, auraButton.rawHeight, auraButton.borderWidth, auraButton.borderHeight, auraButton.lowerScale = addonTable.Display.ApplyStatusBar(details, auraButton.statusBar, auraButton.border, auraButton.borderMask, auraButton.background)
    auraButton.borderWrapper:SetFrameLevel(auraButton.statusBar:GetFrameLevel() + 2)
    auraButton.TextsContainer:SetFrameLevel(auraButton.statusBar:GetFrameLevel() + 4)
    auraButton:SetDurationText(auraButton.TextsContainer.Duration, {
      formatter = components[1].formatter, -- XXX: Change when Blizzard fixes the formatter bug
      textFormat = format,
      textFormatComponents = components,
    })
    auraButton:SetMouseMotionEnabled(false and addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))

    addonTable.Display.ApplyTexts(auraButton, details, textsByKey, details.scale)

    auraButton.Icon:SetShown(details.icon.show)
  end
end

function addonTable.Display.AuraStatusBarNextMixin:GetDefaultSize()
  return self.helpfulButton.rawWidth * self.details.scale, self.helpfulButton.rawHeight * self.details.scale
end

function addonTable.Display.AuraStatusBarNextMixin:ApplyPadding(horizontal, vertical)
  for _, auraButton in ipairs({self.helpfulButton, self.harmfulButton}) do
    PixelUtil.SetSize(auraButton, auraButton.sizingWidth + horizontal, auraButton.sizingHeight + vertical)
  end
  self:Hide()
  self:Show()
end

function addonTable.Display.AuraStatusBarNextMixin:ApplySize(width, height)
  for _, auraButton in ipairs({self.helpfulButton, self.harmfulButton}) do
    local sizing = addonTable.Display.GetSizingForStatusBar(auraButton, width, height)
    auraButton.sizingWidth, auraButton.sizingHeight = sizing.rawWidth, sizing.rawHeight
    PixelUtil.SetSize(auraButton.statusBar, sizing.statusWidth * auraButton.lowerScale, sizing.statusHeight * auraButton.lowerScale)
    PixelUtil.SetSize(auraButton.border, sizing.borderWidth * auraButton.lowerScale, sizing.borderHeight * auraButton.lowerScale)
    if sizing.iconSize > 0 then
      auraButton.Icon:Show()
      PixelUtil.SetSize(auraButton.Icon, sizing.iconSize, sizing.iconSize)
    else
      auraButton.Icon:Hide()
    end

    PixelUtil.SetPoint(auraButton.TextsContainer.Charges, "BOTTOMRIGHT", auraButton.Icon, "BOTTOMRIGHT", -5, 5)

    auraButton.Icon:ClearAllPoints()
    auraButton.statusBar:ClearAllPoints()
    auraButton.TextsContainer.Duration:ClearAllPoints()
    if auraButton.details.layout == "horizontal" then
      auraButton.Icon:SetPoint(auraButton.details.icon.position == "left" and "LEFT" or "RIGHT")
      auraButton.statusBar:SetPoint(auraButton.details.icon.position == "left" and "RIGHT" or "LEFT")
    else
      auraButton.Icon:SetPoint(auraButton.details.icon.position == "left" and "BOTTOM" or "TOP")
      auraButton.statusBar:SetPoint(auraButton.details.icon.position == "left" and "TOP" or "BOTTOM")
    end

    addonTable.Display.SizeTextsForBar(auraButton, auraButton.details, textsByKey, auraButton.details.scale)
  end
end
