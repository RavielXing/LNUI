---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.LayoutManagerSharedMixin = CreateFromMixins(addonTable.Display.BaseLayoutManagerMixin)
function addonTable.Display.LayoutManagerSharedMixin:OnLoad()
  addonTable.Display.BaseLayoutManagerMixin.OnLoad(self)
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
  self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
  self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")

  self.disabled = {}

  self.pools = {
    group = addonTable.Display.GeneratePool(addonTable.Display.GroupMixin),
    auraIcon = addonTable.Display.GeneratePool(addonTable.Display.AuraIconMixin),
    cooldown = addonTable.Display.GeneratePool(addonTable.Display.CooldownMixin),
    abilityBar = addonTable.Display.GeneratePool(addonTable.Display.AbilityStatusBarMixin),
    abilityChargesPip = addonTable.Display.GeneratePool(addonTable.Display.AbilityChargesPipMixin),
    auraStatusBar = addonTable.Display.GeneratePool(addonTable.Display.AuraStatusBarMixin),
    castBar = addonTable.Display.GeneratePool(addonTable.Display.CastBarMixin),
  }
end

function addonTable.Display.LayoutManagerSharedMixin:Delayout()
  local oldPending = self.pending
  self.pending = true

  for _, p in pairs(self.pools) do
    p:ReleaseAll()
  end

  self.toArrange = {}

  self.pending = oldPending
end

function addonTable.Display.LayoutManagerSharedMixin:Layout()
  if next(self.disabled) then
    return
  end
  self.pending = true

  self.autoSize = addonTable.Config.Get(addonTable.Config.Options.COMPRESS_LAYOUT)

  self.currentLayout = addonTable.Core.GetCurrentDesign()

  self:Delayout()

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

function addonTable.Display.LayoutManagerSharedMixin:GetIcon(details)
  if details.resource.kind == "ability" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) or C_Spell.IsSpellPassive(details.resource.spellID) then
      return
    end
    local frame = self.pools.cooldown:Acquire()
    frame:Show()
    frame:Enable()
    frame.details = details
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "item" then
    if C_Item.GetItemCount(details.resource.itemID) < 1 then
      return
    end
    local frame = self.pools.cooldown:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame
  elseif details.resource.kind == "equipment" then
    local location = ItemLocation:CreateFromEquipmentSlot(details.resource.equipmentSlot)
    if not C_Item.DoesItemExist(location) then
      return
    end
    local frame = self.pools.cooldown:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame
  end
end

function addonTable.Display.LayoutManagerSharedMixin:GetBar(details)
  if details.resource.kind == "ability" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) then
      return
    end
    local frame = self.pools.abilityBar:Acquire()
    frame:Show()
    frame:Enable()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "abilityCharge" then
    if not addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) then
      return
    end
    local frame = self.pools.abilityChargesPip:Acquire()
    frame:Show()
    frame:Setup(details)
    return frame

  elseif details.resource.kind == "class" then
    if not self.pools["class-" .. details.resource.resource] then
      addonTable.Utilities.Message("Unknown class resource")
      return
    end
    local bar = self.pools["class-" .. details.resource.resource]:Acquire()
    bar:Show()
    bar:Setup(details)
    return bar

  elseif details.resource.kind == "cast" then
    local bar = self.pools.castBar:Acquire()
    bar:Show()
    bar:Enable()
    bar:Setup(details)
    return bar
  end
end

function addonTable.Display.LayoutManagerSharedMixin:OnEvent(eventName, data)
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

function addonTable.Display.LayoutManagerSharedMixin:ApplySituation()
  self.root:SetAlpha(1)

  if self.inCombat then
    return
  end

  if IsMounted() or isDruid and GetShapeshiftForm() == 3 then
    self.root:SetAlpha(0.5)
  end
end
