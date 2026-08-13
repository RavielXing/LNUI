---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AuraIconNextMixin = {}

local offsetSize = addonTable.Constants.nativeSize - 4

function addonTable.Display.AuraIconNextMixin:OnLoad()
  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)

  self:SetScript("OnShow", self.OnShow)
  self:SetScript("OnHide", self.OnHide)
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")

  self.ButtonInit = function(auraButton)
    auraButton:SetIgnoringChildrenForBounds(true)
    auraButton:SetCollapsesLayout(true)
    auraButton.Icon = auraButton:CreateTexture()
    auraButton.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
    auraButton.Icon:SetPoint("CENTER")
    auraButton:SetIcon(auraButton.Icon)

    local mask = auraButton:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    mask:SetAllPoints(auraButton.Icon)
    auraButton.Icon:AddMaskTexture(mask)

    auraButton.CountFrame = CreateFrame("auraButton", nil, auraButton)
    auraButton.CountFrame:SetAllPoints(auraButton.Icon)
    auraButton.CountFrame.text = auraButton.CountFrame:CreateFontString(nil, nil, "NumberFontNormal")
    auraButton:SetApplicationCount(auraButton.CountFrame.text)

    auraButton.BaseCooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    auraButton.BaseCooldown:SetDrawEdge(false)
    auraButton.BaseCooldown:SetAllPoints(auraButton.Icon)
    auraButton.BaseCooldown:SetDrawBling(false)
    auraButton:SetDurationCooldown(auraButton.BaseCooldown)

    auraButton.TypeBorder = CreateFrame("auraButton", nil, auraButton)
    auraButton.TypeBorder.texture = auraButton.TypeBorder:CreateTexture()
    auraButton.TypeBorder:SetAllPoints(auraButton.Icon)
    auraButton.TypeBorder.texture:SetAllPoints()

    auraButton.Glow = addonTable.Utilities.InitFrameWithMixin(auraButton, addonTable.Display.GlowMixin)
    auraButton.Glow:SetAllPoints()

    auraButton:SetPoint("TOPLEFT", self)

    local sizeAssistant = CreateFrame("Frame", nil, self, "DisableUntrustedLayoutScriptsTemplate")
    sizeAssistant:SetSize(0.0001, 0.0001)
    sizeAssistant:SetPoint("TOPLEFT", auraButton, "BOTTOMRIGHT")
  end

  self.StyleButton = function(auraButton, details)
    auraButton.BaseCooldown:SetDrawSwipe(details.showSwipe)

    auraButton:SetCollapsesLayout(addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT))
    auraButton.details = details
    addonTable.Display.StyleIcon({id  = details.style}, auraButton, auraButton.Icon, auraButton.CountFrame.text, nil, {auraButton.Icon}, {{text = true, swipe = true, widget = auraButton.BaseCooldown}})
    auraButton:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
    auraButton.TypeBorder:SetFrameLevel(auraButton:GetFrameLevel() + 3)
    auraButton.BaseCooldown:SetFrameLevel(auraButton:GetFrameLevel() + 4)
    auraButton.CountFrame:SetFrameLevel(auraButton:GetFrameLevel() + 5)

    local usingGlow = addonTable.Constants.GlowsMap[details.whenActive] ~= nil
    auraButton.Glow:SetShown(usingGlow)
    if usingGlow then
      auraButton.Glow:SetAsset(addonTable.Constants.GlowsMap[details.whenActive], details.glowColor, details.glowReverse)
      auraButton.Glow:SetFrameLevel(auraButton:GetFrameLevel() + 4)
    end
  end

  self.SetDispelBorder = function(auraButton, details)
    if details.style == "square" then
      local asset = addonTable.Assets.IconBorders["Cooli: 1px"]
      auraButton.TypeBorder.texture:SetTexture(asset.file)
    else
      auraButton.TypeBorder.texture:SetAtlas("UI-HUD-CoolDownManager-Debuff-Bleed")
    end
  end
end

function addonTable.Display.AuraIconNextMixin:Enable()
end

function addonTable.Display.AuraIconNextMixin:Disable()
  self:UnregisterAllEvents()
end

function addonTable.Display.AuraIconNextMixin:IgnoreForSizing()
  return true
end

function addonTable.Display.AuraIconNextMixin:ApplyPadding(horizontal, vertical)
  if addonTable.Utilities.IsAurasRestricted() then
    return
  end

  horizontal = horizontal
  vertical = vertical
  if not self.helpfulButton then
    self.index, self.helpfulButton, self.harmfulButton = addonTable.Display.GenerateAuraSlots(
      {initializeFrame = function(auraButton)
        self.ButtonInit(auraButton)
        self.StyleButton(auraButton, self.details)
        auraButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
        auraButton:SetScale(self:GetEffectiveScale() / UIParent:GetScale())
      end, candidateFilters = self.include},
      {initializeFrame = function(auraButton)
        self.ButtonInit(auraButton)
        auraButton:SetAuraBorder(
          auraButton.TypeBorder.texture,
          { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, showIcon = false }
        )
        self.SetDispelBorder(auraButton, self.details)
        self.StyleButton(auraButton, self.details)
        auraButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
        auraButton:SetScale(self:GetEffectiveScale() / UIParent:GetScale())
        auraButton:SetFrameLevel(self:GetFrameLevel() + 1)
      end, candidateFilters = self.include}
    )

  else
    self.helpfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    self.helpfulButton:SetScale(self:GetEffectiveScale() / UIParent:GetScale())
    self.helpfulButton:SetFrameLevel(self:GetFrameLevel() + 1)

    self.harmfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    self.harmfulButton:SetScale(self:GetEffectiveScale() / UIParent:GetScale())
    self.harmfulButton:SetFrameLevel(self:GetFrameLevel() + 1)
  end
end

function addonTable.Display.AuraIconNextMixin:Setup(details)
  self.details = details

  self.include = {
    includeSpellIDs = {[self.details.resource.spellID] = true}
  }
  if addonTable.State.CDM.auraMap[self.details.resource.spellID] then
    local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(addonTable.State.CDM.auraMap[self.details.resource.spellID])
    for _, spellID in ipairs(cooldownInfo.linkedSpellIDs) do
      self.include.includeSpellIDs[spellID] = true
    end
  end

  if self.helpfulButton then
    self.StyleButton(self.helpfulButton, details)

    self.SetDispelBorder(self.harmfulButton, details)
    self.StyleButton(self.harmfulButton, details)

    addonTable.Display.SetAuraSlotsFilters(self.index, self.include, self.include)
  end
end

function addonTable.Display.AuraIconNextMixin:TriggerLayout()
  self:SetIgnoringChildrenForBounds(false)
  self:SetSize(0.001, 0.001)
  self:ResizeToBoundsRect()
  self:SetIgnoringChildrenForBounds(true)

  if self.helpfulButton:CanBeAccessedInContext() then
    self.helpfulButton:SetAlpha(self:GetEffectiveAlpha())
    self.harmfulButton:SetAlpha(self:GetEffectiveAlpha())
  end
end

function addonTable.Display.AuraIconNextMixin:ApplySize()
end

function addonTable.Display.AuraIconNextMixin:OnShow()
  if self.index then
    addonTable.Display.SetAuraSlotsEnabled(self.index, true)
  end
end

function addonTable.Display.AuraIconNextMixin:OnHide()
  if self.index then
    addonTable.Display.SetAuraSlotsEnabled(self.index, false)
  end
end

function addonTable.Display.AuraIconNextMixin:OnEvent()
  if addonTable.Utilities.IsAurasRestricted() then
    self.helpfulButton:SetAlpha(1)
    self.harmfulButton:SetAlpha(1)
  end
end
