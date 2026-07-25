---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.TotemIconMixin = {}

function addonTable.Display.TotemIconMixin:OnLoad()
  self:SetCollapsesLayout(true)
  self:SetFlattensRenderLayers(true)

  self.Icon = self:CreateTexture()
  self.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  self.Icon:SetPoint("CENTER")

  self.BaseCooldown = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
  self.BaseCooldown:SetAllPoints(self.Icon)
  self.BaseCooldown:SetDrawEdge(false)

  self:SetScript("OnEnter", self.OnEnter)
  self:SetScript("OnLeave", self.OnLeave)

  self.BaseCooldown:SetScript("OnCooldownDone", function()
    self:Hide()
    self:SetSize(0.001, 0.001)
  end)

  self.paddingH, self.paddingV = 0, 0
end

function addonTable.Display.TotemIconMixin:Enable(details)
  addonTable.CallbackRegistry:RegisterCallback("Update.Totems", self.Update, self)
end

function addonTable.Display.TotemIconMixin:Disable(details)
  addonTable.CallbackRegistry:UnregisterCallback("Update.Totems", self)
end

function addonTable.Display.TotemIconMixin:Setup(details)
  self.details = details
  self.spellID = C_Spell.GetOverrideSpell(details.resource.spellID)
  self.Icon:SetTexture(C_Spell.GetSpellTexture(self.details.resource.spellID))
  self:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
  self:Update()
  addonTable.Display.StyleIcon({id  = details.style}, self, self.Icon, nil, nil, {self.Icon}, {{text = true, swipe = true, widget = self.BaseCooldown}})
end

function addonTable.Display.TotemIconMixin:ApplyPadding(horizontal, vertical)
  self.paddingH, self.paddingV = horizontal, vertical
  self:SetSize(addonTable.Constants.nativeSize - 4 + horizontal, addonTable.Constants.nativeSize - 4 + vertical)
end

function addonTable.Display.TotemIconMixin:GetDefaultSize()
  local dim = addonTable.Constants.nativeSize - 4
  return dim, dim
end

function addonTable.Display.TotemIconMixin:Update()
  local spellIDToIndex = addonTable.Display.GetTotems()
  local duration = spellIDToIndex[self.spellID] and GetTotemDuration(spellIDToIndex[self.spellID])
  if not duration then
    self:Hide()
    self:SetSize(0.001, 0.001)
    return
  end
  self:Show()
  self:ApplyPadding(self.paddingH, self.paddingV)
  self.BaseCooldown:SetCooldownFromDurationObject(duration)
end

function addonTable.Display.TotemIconMixin:OnEnter()
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  GameTooltip:SetSpellByID(self.details.resource.spellID)
end

function addonTable.Display.TotemIconMixin:OnLeave()
  GameTooltip:Hide()
end
