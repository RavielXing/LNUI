
---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AuraIconNextMixin = {}

local offsetSize = addonTable.Constants.nativeSize - 4

function addonTable.Display.AuraIconNextMixin:OnLoad()
  self:SetCollapsesLayout(true)
  self:SetScript("OnEvent", self.OnEvent)

  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
  self:SetFlattensRenderLayers(true)

  local function ButtonInit(frame)
    frame.Icon = frame:CreateTexture()
    frame.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
    frame.Icon:SetPoint("CENTER")
    frame:SetIcon(frame.Icon)

    local mask = frame:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    mask:SetAllPoints(frame.Icon)
    frame.Icon:AddMaskTexture(mask)

    frame.CountFrame = CreateFrame("Frame", nil, frame)
    frame.CountFrame:SetAllPoints(frame.Icon)
    frame.CountFrame.text = frame.CountFrame:CreateFontString(nil, nil, "NumberFontNormal")
    frame.CountFrame.text:SetPoint("BOTTOMRIGHT", -2, -2)
    frame:SetApplicationCount(frame.CountFrame.text)

    frame.BaseCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.BaseCooldown:SetDrawEdge(false)
    frame.BaseCooldown:SetAllPoints(frame.Icon)
    frame:SetDurationCooldown(frame.BaseCooldown)

    frame.TypeBorder = CreateFrame("Frame", nil, frame)
    frame.TypeBorder.texture = frame.TypeBorder:CreateTexture()
    frame.TypeBorder:SetAllPoints(frame.Icon)
    frame.TypeBorder.texture:SetAllPoints()
  end

  self.helpful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.helpful:SetUnit("player")
  self.helpfulButton = self.helpful:AddAuraSlot("1", "HELPFUL|PLAYER", {})
  ButtonInit(self.helpfulButton)

  self.harmful = CreateFrame("AuraContainer", nil, self, "CustomAuraContainerTemplate")
  self.harmful:SetUnit("target")
  self.harmfulButton = self.harmful:AddAuraSlot("1", "HARMFUL|PLAYER", {})
  ButtonInit(self.harmfulButton)
  self.harmfulButton:SetAuraBorder(self.harmfulButton.TypeBorder.texture, {style = AuraButtonBorderStyle.Color, showIcon = false})

  self.helpfulButton:SetPoint("TOPLEFT", self)
  self.harmfulButton:SetPoint("TOPLEFT", self)
end

function addonTable.Display.AuraIconNextMixin:Enable()
  self:RegisterUnitEvent("UNIT_AURA", "player", "target")
  self:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function addonTable.Display.AuraIconNextMixin:Disable()
  self:UnregisterAllEvents()
  self.helpful:SetParent(self)
  self.harmful:SetParent(self)
end

function addonTable.Display.AuraIconNextMixin:GetDefaultSize()
  local dim = addonTable.Constants.nativeSize - 4
  return dim, dim
end

function addonTable.Display.AuraIconNextMixin:IgnoreForSizing()
  return true
end

function addonTable.Display.AuraIconNextMixin:ApplyPadding(horizontal, vertical)
  if addonTable.Utilities.IsAurasRestricted() then
    return
  end

  horizontal = horizontal / 100
  vertical = vertical / 100
  self.helpfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
  self.harmfulButton:SetSize(offsetSize + horizontal, offsetSize + vertical)
end

function addonTable.Display.AuraIconNextMixin:Setup(details)
  self.details = details

  if details.style == "square" then
    local asset = addonTable.Assets.IconBorders["Cooli: 1px"]
    self.harmfulButton.TypeBorder.texture:SetTexture(asset.file)
  else
    self.harmfulButton.TypeBorder.texture:SetAtlas("UI-HUD-CoolDownManager-Debuff-Bleed")
  end

  local include = {
    includeSpellIDs = {[self.details.resource.spellID] = true}
  }
  if addonTable.State.CDM.auraMap[self.details.resource.spellID] then
    local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(addonTable.State.CDM.auraMap[self.details.resource.spellID])
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
    addonTable.Display.StyleIcon({id  = details.style}, auraButton, auraButton.Icon, auraButton.CountFrame.text, nil, {auraButton.Icon}, {{text = true, swipe = true, widget = auraButton.BaseCooldown}})
    auraButton:SetMouseMotionEnabled(false and addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
    auraButton.TypeBorder:SetFrameLevel(auraButton:GetFrameLevel() + 3)
    auraButton.CountFrame:SetFrameLevel(auraButton:GetFrameLevel() + 5)
  end

  self.helpfulButton:SetScale(100 * self.details.scale)
  self.harmfulButton:SetScale(100 * self.details.scale)

  self:Hide()
  self:Show()
end

function addonTable.Display.AuraIconNextMixin:OnEvent(eventName)
  if eventName == "PLAYER_TARGET_CHANGED" then
    self.harmful:UpdateAllAuras()
  end
  local parent = self:GetParent()
  if parent.TriggerLayout then
    parent:TriggerLayout()
  else
    self:Hide()
    self:Show()
  end
end

function addonTable.Display.AuraIconNextMixin:ApplySize()
  self:SetScale(0.01)
end
