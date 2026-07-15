---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.LayoutManagerNextMixin = CreateFromMixins(addonTable.Display.LayoutManagerSharedMixin)
function addonTable.Display.LayoutManagerNextMixin:OnLoad()
  addonTable.Display.LayoutManagerSharedMixin.OnLoad(self)

  self.pools.auraIcon = addonTable.Display.GeneratePool(addonTable.Display.AuraIconNextMixin, "CoolinatorPropagateMouseClicksTemplate,ResizeLayoutFrame", 40)
  self.pools.auraBar = addonTable.Display.GeneratePool(addonTable.Display.AuraStatusBarNextMixin, "CoolinatorPropagateMouseClicksTemplate,ResizeLayoutFrame", 40)
  self.pools.group = addonTable.Display.GeneratePool(addonTable.Display.GroupMixin, "CoolinatorPropagateMouseClicksTemplate,ResizeLayoutFrame")
  for key, mixin in pairs(addonTable.Display.ClassResourceStatusBar) do
    self.pools["class-" .. key] = addonTable.Display.GeneratePool(mixin)
  end

  self:Layout()
end

function addonTable.Display.LayoutManagerNextMixin:GetIcon(details)
  if details.resource.kind == "aura" and addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID) then
    local frame = self.pools.auraIcon:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "aura" and addonTable.Constants.Totems[details.resource.spellID] then
    local frame = self.pools.totemIcon:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame

  else
    return addonTable.Display.LayoutManagerSharedMixin.GetIcon(self, details)
  end
end

function addonTable.Display.LayoutManagerNextMixin:GetBar(details)
  if details.resource.kind == "aura" and addonTable.Constants.Totems[details.resource.spellID] then
    local frame = self.pools.totemStatusBar:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "aura" and addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID) then
    local frame = self.pools.auraBar:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame

  else
    return addonTable.Display.LayoutManagerSharedMixin.GetBar(self, details)
  end
end
