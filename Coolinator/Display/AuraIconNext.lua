---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AuraIconNextMixin = {}

local offsetSize = addonTable.Constants.nativeSize - 4

function addonTable.Display.AuraIconNextMixin:OnLoad()
  self:SetScript("OnEvent", self.OnEvent)

  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)

  self.ButtonInit = function(auraButton)
    auraButton:SetIgnoringChildrenForBounds(true)
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
    auraButton:SetDurationCooldown(auraButton.BaseCooldown)

    auraButton.TypeBorder = CreateFrame("auraButton", nil, auraButton)
    auraButton.TypeBorder.texture = auraButton.TypeBorder:CreateTexture()
    auraButton.TypeBorder:SetAllPoints(auraButton.Icon)
    auraButton.TypeBorder.texture:SetAllPoints()

    auraButton.Glow = addonTable.Utilities.InitFrameWithMixin(auraButton, addonTable.Display.GlowMixin)
    auraButton.Glow:SetAllPoints()

    auraButton:SetPoint("CENTER", self)
  end

  self.StyleButton = function(auraButton, details)
    auraButton.details = details
    addonTable.Display.StyleIcon({id  = details.style}, auraButton, auraButton.Icon, auraButton.CountFrame.text, nil, {auraButton.Icon}, {{text = true, swipe = true, widget = auraButton.BaseCooldown}})
    auraButton:SetMouseMotionEnabled(false and addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
    auraButton.TypeBorder:SetFrameLevel(auraButton:GetFrameLevel() + 3)
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

  self.helpful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.helpful:SetUnit("player")

  self.harmful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.harmful:SetUnit("target")
end

function addonTable.Display.AuraIconNextMixin:Enable()
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
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
    self.helpfulButton = self.helpful:AddAuraSlot("1", "HELPFUL|PLAYER", {initializeFrame = function(auraButton)
      self.ButtonInit(auraButton)
      self.StyleButton(auraButton, self.details)
      auraButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    end, candidateFilters = self.include})
  else
    self.helpfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    self.helpfulButton:GetRect()
  end

  if not self.harmfulButton then
    self.harmfulButton = self.harmful:AddAuraSlot("1", "HARMFUL|PLAYER", {initializeFrame = function(auraButton)
      self.ButtonInit(auraButton)
      auraButton:SetAuraBorder(
        auraButton.TypeBorder.texture,
        { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, showIcon = false }
      )
      self.SetDispelBorder(auraButton, self.details)
      self.StyleButton(auraButton, self.details)
      auraButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    end, candidateFilters = self.include})
  else
    self.harmfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
    self.harmfulButton:GetRect()
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
    self.helpful:SetAuraSlotCandidateFilters("1", self.include)
  end

  if self.harmfulButton then
    self.SetDispelBorder(self.harmfulButton, details)
    self.StyleButton(self.harmfulButton, details)
    self.harmful:SetAuraSlotCandidateFilters("1", self.include)
  end
end

function addonTable.Display.AuraIconNextMixin:TriggerLayout()
  self:SetIgnoringChildrenForBounds(false)
  self:SetSize(0.001, 0.001)
  self:ResizeToBoundsRect()
  self:SetIgnoringChildrenForBounds(true)
end

function addonTable.Display.AuraIconNextMixin:OnEvent(eventName)
  self.harmful:UpdateAllAuras()
end

function addonTable.Display.AuraIconNextMixin:ApplySize()
end
