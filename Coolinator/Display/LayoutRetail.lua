---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.LayoutManagerRetailMixin = CreateFromMixins(addonTable.Display.LayoutManagerSharedMixin)
function addonTable.Display.LayoutManagerRetailMixin:OnLoad()
  addonTable.Display.LayoutManagerSharedMixin.OnLoad(self)

  self.pools.abilityWrappers = CreateFramePool("Frame", UIParent, nil, function(_, frame)
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnSizeChanged", nil)
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    frame:Hide()
  end)
  self.pools.auraIcon = addonTable.Display.GeneratePool(addonTable.Display.AuraIconMixin)
  self.pools.auraFromItem = addonTable.Display.GeneratePool(addonTable.Display.AuraFromItemMixin)
  for key, mixin in pairs(addonTable.Display.ClassResourceStatusBar) do
    self.pools["class-" .. key] = addonTable.Display.GeneratePool(mixin)
  end

  addonTable.CallbackRegistry:RegisterCallback("Layout", function()
    self.disabled.cdmChanges = nil
    self:Layout()
  end)

  self:RegisterToCDM()

  self:Layout()
end

function addonTable.Display.LayoutManagerRetailMixin:RegisterToCDM()
  addonTable.CallbackRegistry:RegisterCallback("CDMUpdating", function(_, state)
    self.disabled.cdmChanges = state or nil
    if not state then
      self:CDMCacheAuraIcons()
      self:CDMCacheBars()
    end
  end)

  local function CacheAbilities()
    local result = {}
    for itemFrame in EssentialCooldownViewer.itemFramePool:EnumerateActive() do
      result[itemFrame.layoutIndex] = itemFrame
    end
    self.abilityIcons = result
  end

  self:CDMCacheAuraIcons()
  self:CDMCacheBars()
  CacheAbilities()

  local function IconCallback()
    if self.queueTimeAuraIcon == GetTime() then
      return
    end
    self.queueTimeAuraIcon = GetTime()
    addonTable.Utilities.RunInXFrames(2, function()
      self:CDMCacheAuraIcons()
      self:CDMSyncAuraIcons()
    end)
  end
  EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
    C_Timer.After(0, function()
      self:CDMSyncAuraIcons()
      self:CDMSyncBars()
    end)
  end)
  hooksecurefunc(BuffIconCooldownViewer, "RefreshData", IconCallback)
  hooksecurefunc(BuffIconCooldownViewer, "OnUnitAura", IconCallback)
  if BuffIconCooldownViewer.OnUnitTarget then
    hooksecurefunc(BuffIconCooldownViewer, "OnUnitTarget", IconCallback)
  else
    hooksecurefunc(BuffIconCooldownViewer, "OnPlayerTargetChanged", IconCallback)
  end

  local function BarCallback()
    if self.queueTimeAuraBar == GetTime() then
      return
    end
    self.queueTimeAuraBar = GetTime()
    addonTable.Utilities.RunInXFrames(2, function()
      self:CDMCacheBars()
      self:CDMSyncBars()
    end)
  end
  hooksecurefunc(BuffBarCooldownViewer, "RefreshData", BarCallback)
  hooksecurefunc(BuffBarCooldownViewer, "OnUnitAura", BarCallback)
  if BuffBarCooldownViewer.OnUnitTarget then
    hooksecurefunc(BuffBarCooldownViewer, "OnUnitTarget", BarCallback)
  else
    hooksecurefunc(BuffBarCooldownViewer, "OnPlayerTargetChanged", BarCallback)
  end

  hooksecurefunc(EssentialCooldownViewer, "RefreshLayout", function()
    C_Timer.After(0, function()
      if not addonTable.State.CDM then
        return
      end
      CacheAbilities()
      for i = 1, #self.abilityIcons do
        self.abilityIcons[i]:SetParent(addonTable.hiddenFrame)
      end
      for frame in self.pools.abilityWrappers:EnumerateActive() do
        local ability = self.abilityIcons[frame.abilityIndex]
        if ability then
          ability:SetParent(frame)
          ability:SetScale(0.8)
          ability:ClearAllPoints()
          ability:SetPoint("CENTER", frame)
        end
      end
    end)
  end)
end

function addonTable.Display.LayoutManagerRetailMixin:CDMCacheAuraIcons()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  self.hookedAuras = {}
  local result = {}
  local count = 0
  for itemFrame in BuffIconCooldownViewer.itemFramePool:EnumerateActive() do
    if itemFrame.cooldownID then
      result[itemFrame.cooldownID] = itemFrame
      count = count + 1
    end
  end
  self.auraIcons = result
  -- Detect missing auras
  addonTable.CallbackRegistry:TriggerEvent("MissingCDMWidgets", count ~= addonTable.State.CDM.auraCount and not self.disabled.designer and not self.disabled.cdmChanges)
end

function addonTable.Display.LayoutManagerRetailMixin:CDMSyncAuraIcons()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  for _, icon in pairs(self.auraIcons) do
    icon:SetParent(addonTable.hiddenFrame)
  end
  for frame in self.pools.auraIcon:EnumerateActive() do
    local aura = self.auraIcons[frame.cooldownID]
    frame:UpdateSource(aura)
  end
end

function addonTable.Display.LayoutManagerRetailMixin:CDMCacheBars()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  local result = {}

  local count = 0
  for itemFrame in BuffBarCooldownViewer.itemFramePool:EnumerateActive() do
    if itemFrame.cooldownID then
      result[itemFrame.cooldownID] = itemFrame
      count = count + 1
    end
  end
  -- Detect missing bars
  addonTable.CallbackRegistry:TriggerEvent("MissingCDMWidgets", count ~= addonTable.State.CDM.barCount and not self.disabled.designer and not self.disabled.cdmChanges)
  self.auraBars = result
end

function addonTable.Display.LayoutManagerRetailMixin:CDMSyncBars()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  for _, bar in pairs(self.auraBars) do
    bar:SetParent(addonTable.hiddenFrame)
  end
  for frame in self.pools.auraStatusBar:EnumerateActive() do
    local aura = self.auraBars[frame.cooldownID]
    if aura then
      frame:UpdateSource(aura)
      frame:ApplySize()
      frame:ApplyPadding()
    end
  end
end

function addonTable.Display.LayoutManagerRetailMixin:Layout()
  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)
  for _, icon in pairs(self.auraIcons) do
    icon:SetParent(addonTable.hiddenFrame)
  end
  for _, icon in pairs(self.abilityIcons) do
    icon:SetParent(addonTable.hiddenFrame)
  end
  addonTable.Display.LayoutManagerSharedMixin.Layout(self)
end

function addonTable.Display.LayoutManagerRetailMixin:GetIcon(details)
  if details.resource.kind == "ability" and self.useBlizzardWidgets and addonTable.State.CDM.abilityMap[details.resource.spellID] then
    local spellID = addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local abilityIndex = addonTable.State.CDM.abilityOrder[addonTable.State.CDM.abilityMap[spellID]]
    local ability = self.abilityIcons[abilityIndex]
    local frame = self.pools.abilityWrappers:Acquire()
    frame.abilityIndex = abilityIndex
    if ability then
      ability:SetParent(frame)
      ability:ClearAllPoints()
      ability:SetPoint("CENTER", frame)
      ability:SetScale(0.8)
      ability:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))

      frame:SetShown(ability:IsShown())
      frame:Show()
      frame.details = details
      frame:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
      local _, _, overlay = ability:GetRegions()
      overlay:Hide()
      addonTable.Display.StyleIcon({id  = details.style}, frame, ability.Icon, ability.ChargeCount.Current, nil, {ability.Icon}, {{text = true, widget = ability.Cooldown}})

      return frame
    else
      self.missingWidget = true
    end

  elseif details.resource.kind == "aura" and addonTable.Constants.Totems[details.resource.spellID] then
    local frame = self.pools.totemIcon:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "aura" and addonTable.State.CDM.auraMap[details.resource.spellID] then
    local spellID = addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local cooldownID = addonTable.State.CDM.auraMap[spellID]
    local aura = self.auraIcons[cooldownID]
    if aura then
      aura:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
      local frame = self.pools.auraIcon:Acquire()
      frame.details = details
      frame.cooldownID = cooldownID
      frame:Setup(aura, details)
      return frame
    else
      self.missingWidget = true
    end
  elseif details.resource.kind == "aura" and addonTable.Constants.AurasFromItems[details.resource.spellID] then
    local frame = self.pools.auraFromItem:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame
  else
    return addonTable.Display.LayoutManagerSharedMixin.GetIcon(self, details)
  end
end

function addonTable.Display.LayoutManagerRetailMixin:GetBar(details)
  if details.resource.kind == "aura" and addonTable.Constants.Totems[details.resource.spellID] then
    local frame = self.pools.totemStatusBar:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame
  elseif details.resource.kind == "aura" then
    local spellID = addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local cooldownID = addonTable.State.CDM.auraMap[details.resource.spellID]
    local aura = self.auraBars[cooldownID]
    if not aura then
      self.missingWidget = true
      return
    end
    local monitor = self.pools.auraStatusBar:Acquire()
    monitor.cooldownID = cooldownID
    monitor:Show()
    monitor:Setup(aura, details)
    return monitor
  else
    return addonTable.Display.LayoutManagerSharedMixin.GetBar(self, details)
  end
end
