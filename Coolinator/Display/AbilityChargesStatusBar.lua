---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.AbilityChargesPipMixin = {}

addonTable.Display.AbilityChargesPipMixin.OnLoad = addonTable.Display.GenerateStatusBar

function addonTable.Display.AbilityChargesPipMixin:OnEvent(eventName, ...)
  self:Import()
end

function addonTable.Display.AbilityChargesPipMixin:Setup(details)
  self:RegisterEvent("SPELL_UPDATE_CHARGES")

  self.rawWidth, self.rawHeight, self.borderWidth, self.borderHeight, self.lowerScale = addonTable.Display.ApplyStatusBar(details, self.statusBar, self.border, self.borderMask, self.background)
  self.details = details
  self.index = details.index
  self.statusBar:SetMinMaxValues(self.index - 1, self.index)

  self.borderWrapper:SetFrameLevel(self.statusBar:GetFrameLevel() + 2)

  self:Import()
end

function addonTable.Display.AbilityChargesPipMixin:Disable()
  self:UnregisterAllEvents()
end

function addonTable.Display.AbilityChargesPipMixin:Import()
  local chargesInfo = C_Spell.GetSpellCharges(self.details.resource.spellID)
  if chargesInfo.maxCharges < self.index then
    self:Hide()
    return
  end
  self:Show()

  self.statusBar:SetValue(chargesInfo.currentCharges)
end

function addonTable.Display.AbilityChargesPipMixin:ApplySize(width, height)
  local sizing = addonTable.Display.GetSizingForStatusBar(self, width, height)
  PixelUtil.SetSize(self, sizing.rawWidth, sizing.rawHeight)
  PixelUtil.SetSize(self.border, sizing.borderWidth * self.lowerScale, sizing.borderHeight * self.lowerScale)
end
