---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.LayoutManagerMixin = CreateFromMixins(addonTable.Display.BaseLayoutManagerMixin)
function addonTable.Display.LayoutManagerMixin:OnLoad()
  addonTable.Display.BaseLayoutManagerMixin.OnLoad(self)
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
  self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
  self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")

  self.disabled = {}

  self.groupPool = addonTable.Display.GeneratePool(addonTable.Display.GroupMixin)
  self.abilityWrappersPool = CreateFramePool("Frame", UIParent, nil, function(_, frame)
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnSizeChanged", nil)
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    frame:Hide()
  end)
  self.auraIconPool = addonTable.Display.GeneratePool(addonTable.Display.AuraIconMixin)
  self.cooldownPool = addonTable.Display.GeneratePool(addonTable.Display.CooldownMixin)
  self.auraFromItemPool = addonTable.Display.GeneratePool(addonTable.Display.AuraFromItemMixin)
  self.abilityBarPool = addonTable.Display.GeneratePool(addonTable.Display.AbilityStatusBarMixin)
  self.abilityChargesPipPool = addonTable.Display.GeneratePool(addonTable.Display.AbilityChargesPipMixin)
  self.auraStatusBarPool = addonTable.Display.GeneratePool(addonTable.Display.AuraStatusBarMixin)
  self.classPools = {}
  for key, mixin in pairs(addonTable.Display.ClassResourceStatusBar) do
    self.classPools[key] = addonTable.Display.GeneratePool(mixin)
  end

  addonTable.CallbackRegistry:RegisterCallback("CDMUpdating", function(_, state)
    self.disabled.cdmChanges = state or nil
    if not state then
      self:CacheAuraIcons()
      self:CacheBars()
    end
  end)

  addonTable.CallbackRegistry:RegisterCallback("Layout", function()
    self.disabled.cdmChanges = nil
    self:Layout()
  end)
  addonTable.CallbackRegistry:RegisterCallback("Designer.Open", function()
    self.disabled.designer = true
    self:Delayout()
  end)
  addonTable.CallbackRegistry:RegisterCallback("Designer.Close", function()
    self.disabled.designer = nil
    self:Layout()
  end)

  local function CacheAbilities()
    local result = {}
    for itemFrame in EssentialCooldownViewer.itemFramePool:EnumerateActive() do
      result[itemFrame.layoutIndex] = itemFrame
    end
    self.abilityIcons = result
  end

  self:CacheAuraIcons()
  self:CacheBars()
  CacheAbilities()

  local function IconCallback()
    if self.queueTimeAuraIcon == GetTime() then
      return
    end
    self.queueTimeAuraIcon = GetTime()
    C_Timer.After(0, function()
      self:SyncAuraIcons()
    end)
  end
  EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
    C_Timer.After(0, function()
      self:SyncAuraIcons()
      self:SyncBars()
    end)
  end)
  hooksecurefunc(BuffIconCooldownViewer, "RefreshData", function()
    C_Timer.After(0, function()
      self:CacheAuraIcons()
      self:SyncAuraIcons()
      self.queueTimeAuraIcon = GetTime()
    end)
  end)
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
    C_Timer.After(0, function()
      self:SyncBars()
    end)
  end
  hooksecurefunc(BuffBarCooldownViewer, "RefreshData", function()
    C_Timer.After(0, function()
      self:CacheBars()
      self:SyncBars()
      self.queueTimeAuraBar = GetTime()
    end)
  end)
  hooksecurefunc(BuffBarCooldownViewer, "OnUnitAura", BarCallback)
  if BuffBarCooldownViewer.OnUnitTarget then
    hooksecurefunc(BuffBarCooldownViewer, "OnUnitTarget", IconCallback)
  else
    hooksecurefunc(BuffBarCooldownViewer, "OnPlayerTargetChanged", IconCallback)
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
      for frame in self.abilityWrappersPool:EnumerateActive() do
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

  self:Layout()
end

function addonTable.Display.LayoutManagerMixin:CacheAuraIcons()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  self.hookedAuras = {}
  self.seenAuraForIndex = {}
  self.seenAuraByCooldownID = {}
  local result = {}
  local count = 0
  for itemFrame in BuffIconCooldownViewer.itemFramePool:EnumerateActive() do
    self.seenAuraForIndex[itemFrame.layoutIndex] = itemFrame.cooldownID
    if itemFrame.cooldownID then
      self.seenAuraByCooldownID[itemFrame.cooldownID] = true
      local intendedIndex = addonTable.State.CDM.auraOrder[itemFrame.cooldownID]
      if intendedIndex then
        result[intendedIndex] = itemFrame
        count = count + 1
      end
    end
  end
  self.auraIcons = result
  -- Detect missing auras
  addonTable.CallbackRegistry:TriggerEvent("MissingCDMWidgets", count ~= addonTable.State.CDM.auraCount and not self.disabled.designer and not self.disabled.cdmChanges)
end

function addonTable.Display.LayoutManagerMixin:SyncAuraIcons()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  for _, icon in pairs(self.auraIcons) do
    icon:SetParent(addonTable.hiddenFrame)
  end
  for frame in self.auraIconPool:EnumerateActive() do
    local aura = self.auraIcons[frame.auraIndex]
    frame:UpdateSource(aura)
  end
end

function addonTable.Display.LayoutManagerMixin:CacheBars()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  local result = {}

  self.seenBarForIndex = {}
  self.seenBarByCooldownID = {}

  local count = 0
  for itemFrame in BuffBarCooldownViewer.itemFramePool:EnumerateActive() do
    if itemFrame.cooldownID then
      self.seenBarForIndex[itemFrame.layoutIndex] = itemFrame.cooldownID
      self.seenBarByCooldownID[itemFrame.cooldownID] = true
      local intendedIndex = addonTable.State.CDM.barOrder[itemFrame.cooldownID]
      if intendedIndex then
        result[intendedIndex] = itemFrame
        count = count + 1
      end
    else
      result[itemFrame.layoutIndex] = itemFrame
    end
  end
  -- Detect missing bars
  addonTable.CallbackRegistry:TriggerEvent("MissingCDMWidgets", count ~= addonTable.State.CDM.barCount and not self.disabled.designer and not self.disabled.cdmChanges)
  self.auraBars = result
end

function addonTable.Display.LayoutManagerMixin:SyncBars()
  if not addonTable.State.CDM or self.disabled.cdmChanges then
    return
  end

  for i = 1, # self.auraBars do
    self.auraBars[i]:SetParent(addonTable.hiddenFrame)
  end
  for frame in self.auraStatusBarPool:EnumerateActive() do
    local aura = self.auraBars[frame.auraIndex]
    if aura then
      frame:UpdateSource(aura)
      frame:ApplySize()
    end
  end
end

function addonTable.Display.LayoutManagerMixin:Delayout()
  local oldPending = self.pending
  self.pending = true
  self.cooldownPool:ReleaseAll()
  self.auraIconPool:ReleaseAll()
  self.abilityWrappersPool:ReleaseAll()
  self.abilityChargesPipPool:ReleaseAll()
  self.auraFromItemPool:ReleaseAll()
  self.auraStatusBarPool:ReleaseAll()
  self.abilityBarPool:ReleaseAll()
  for _, pool in pairs(self.classPools) do
    pool:ReleaseAll()
  end
  self.groupPool:ReleaseAll()

  self.toArrange = {}

  self.pending = oldPending
end

function addonTable.Display.LayoutManagerMixin:Layout()
  if next(self.disabled) then
    return
  end
  self.pending = true

  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)
  self.useBlizzardWidgets = addonTable.Config.Get(addonTable.Config.Options.USE_BLIZZARD_WIDGETS)

  self.currentLayout = addonTable.Core.GetCurrentDesign()

  self:Delayout()

  for _, icon in pairs(self.auraIcons) do
    icon:SetParent(addonTable.hiddenFrame)
  end
  for i = 1, #self.abilityIcons do
    self.abilityIcons[i]:SetParent(addonTable.hiddenFrame)
  end

  local wrapper = self:GetGroup(self.currentLayout)

  wrapper:SetParent(UIParent)
  wrapper:Show()

  self.root = wrapper

  if self.root.children[1] then
    CoolinatorPrimaryGroupAnchor:SetAllPoints(self.root.children[1])
  end

  if addonTable.Config.Get(addonTable.Config.Options.FADE_WHEN_MOUNTED) then
    self.inCombat = InCombatLockdown()
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:ApplySituation()
  else
    self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end

  self.pending = false
end

function addonTable.Display.LayoutManagerMixin:GetIcon(details)
  if details.resource.kind == "ability" and self.useBlizzardWidgets and addonTable.State.CDM.abilityMap[details.resource.spellID] then
    local spellID = addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local abilityIndex = addonTable.State.CDM.abilityOrder[addonTable.State.CDM.abilityMap[spellID]]
    local ability = self.abilityIcons[abilityIndex]
    local frame = self.abilityWrappersPool:Acquire()
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

  elseif details.resource.kind == "ability" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) then
      return
    end
    local frame = self.cooldownPool:Acquire()
    frame:Show()
    frame:Enable()
    frame.details = details
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "aura" and addonTable.State.CDM.auraMap[details.resource.spellID] then
    local spellID = addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local cooldownID = addonTable.State.CDM.auraMap[spellID]
    local auraIndex = addonTable.State.CDM.auraOrder[cooldownID]
    local aura = self.auraIcons[auraIndex]
    if aura then
      aura:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
      local frame = self.auraIconPool:Acquire()
      frame.details = details
      frame.auraIndex = auraIndex
      frame:Setup(aura, details)
      return frame
    else
      self.missingWidget = true
    end
  elseif details.resource.kind == "aura" and addonTable.Constants.AurasFromItems[details.resource.itemID] then
    local frame = self.auraFromItemPool:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame
  elseif details.resource.kind == "item" then
    if C_Item.GetItemCount(details.resource.itemID) < 1 then
      return
    end
    local frame = self.cooldownPool:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame
  elseif details.resource.kind == "equipment" then
    local location = ItemLocation:CreateFromEquipmentSlot(details.resource.equipmentSlot)
    if not C_Item.DoesItemExist(location) then
      return
    end
    local frame = self.cooldownPool:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame
  end
end

function addonTable.Display.LayoutManagerMixin:GetBar(details)
  if details.resource.kind == "aura" then
    local spellID = addonTable.Utilities.IsAuraSpellKnown(details.resource.spellID)
    if not spellID then
      return
    end
    local cooldownID = addonTable.State.CDM.auraMap[details.resource.spellID]
    local auraIndex = addonTable.State.CDM.barOrder[cooldownID]
    local aura = self.auraBars[auraIndex]
    if not aura then
      self.missingWidget = true
      return
    end
    local monitor = self.auraStatusBarPool:Acquire()
    monitor.auraIndex = auraIndex
    monitor:Show()
    monitor:Setup(aura, details)
    return monitor
  elseif details.resource.kind == "ability" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) then
      return
    end
    local frame = self.abilityBarPool:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "abilityCharge" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) then
      return
    end
    local frame = self.abilityChargesPipPool:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "class" then
    if not self.classPools[details.resource.resource] then
      addonTable.Utilities.Message("Unknown class resource")
      return
    end
    local bar = self.classPools[details.resource.resource]:Acquire()
    bar:Show()
    bar:Setup(details)
    return bar
  end
end

function addonTable.Display.LayoutManagerMixin:OnEvent(eventName, data)
  if eventName == "UPDATE_BONUS_ACTIONBAR" or eventName == "UPDATE_VEHICLE_ACTIONBAR" or eventName == "UPDATE_OVERRIDE_ACTIONBAR" then
    if (C_ActionBar.HasVehicleActionBar() and UnitVehicleSkin("player") and UnitVehicleSkin("player") ~= "") or
      (C_ActionBar.HasOverrideActionBar() and C_ActionBar.GetOverrideBarSkin() and C_ActionBar.GetOverrideBarSkin() ~= 0) then
      self.disabled.vehicle = true
      self:Delayout()
    elseif self.disabled.vehicle then
      self.disabled.vehicle = nil
      self:Layout()
    end
  elseif eventName == "PLAYER_REGEN_DISABLED" then
    self.inCombat = true
    self:ApplySituation()
  elseif eventName == "PLAYER_REGEN_ENABLED" then
    self.inCombat = false
    self:ApplySituation()
  elseif eventName == "PLAYER_MOUNT_DISPLAY_CHANGED" or eventName == "UPDATE_SHAPESHIFT_FORM" then
    C_Timer.After(0, function()
      self:ApplySituation()
    end)
  end
end

local isDruid = UnitClassBase("player") == "DRUID"

function addonTable.Display.LayoutManagerMixin:ApplySituation()
  self.root:SetAlpha(1)

  if self.inCombat then
    return
  end

  if IsMounted() or isDruid and GetShapeshiftForm() == 3 then
    self.root:SetAlpha(0.5)
  end
end
