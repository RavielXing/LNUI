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

  local spellID = addonTable.Constants.Totems[details.resource.spellID]
  spellID = spellID ~= 0 and spellID or details.resource.spellID
  self.spellID = C_Spell.GetOverrideSpell(spellID)

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
  local index = spellIDToIndex[self.spellID]
  local duration = index and GetTotemDuration(index)
  if not duration then
    self:Hide()
    return
  end
  self:Show()
  local _, name, _, _, icon = GetTotemInfo(index)
  self.TextsContainer.Name:SetText(name)
  self.Icon:SetTexture(icon)
  self:ApplyPadding(self.paddingH, self.paddingV)
  self.statusBar:SetTimerDuration(duration, nil, Enum.StatusBarTimerDirection.RemainingTime)

  self.DurationBinding:SetDuration(duration)
  self.DurationBinding:Enable()
  self.DurationBinding:UpdateFontString()
end
