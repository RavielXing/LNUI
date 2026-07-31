---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.TotemStatusBarMixin = CreateFromMixins(addonTable.Display.BaseDurationStatusBarMixin)

function addonTable.Display.TotemStatusBarMixin:Enable(details)
  addonTable.CallbackRegistry:RegisterCallback("Update.Totems", self.Update, self)
end

function addonTable.Display.TotemStatusBarMixin:Disable(details)
  addonTable.CallbackRegistry:UnregisterCallback("Update.Totems", self)
end

function addonTable.Display.TotemStatusBarMixin:Setup(details)
  addonTable.Display.BaseDurationStatusBarMixin.Setup(self, details)

  self.spellID = C_Spell.GetOverrideSpell(details.resource.spellID)

  self.Icon:SetTexture(C_Spell.GetSpellTexture(self.spellID))

  if C_Spell.IsSpellDataCached(self.spellID) then
    self.TextsContainer.Name:SetText(C_Spell.GetSpellName(self.spellID))
  else
    Spell:CreateFromSpellID(self.spellID):ContinueOnSpellLoad(function()
      self.TextsContainer.Name:SetText(C_Spell.GetSpellName(self.spellID))
    end)
  end

  self:Update()
end

function addonTable.Display.TotemStatusBarMixin:Update()
  local spellIDToIndex = addonTable.Display.GetTotems()
  local duration = spellIDToIndex[self.spellID] and GetTotemDuration(spellIDToIndex[self.spellID])
  local wasShown = self:IsShown()
  if not duration then
    self:Hide()
    if self:IsShown() ~= wasShown and self:GetParent().TriggerLayout then
      self:GetParent():TriggerLayout()
    end
    return
  end
  self:Show()
  self:ApplyPadding(self.paddingH, self.paddingV)
  self.statusBar:SetTimerDuration(duration, nil, Enum.StatusBarTimerDirection.RemainingTime)

  self.DurationBinding:SetDuration(duration)
  self.DurationBinding:Enable()
  self.DurationBinding:UpdateFontString()
end
