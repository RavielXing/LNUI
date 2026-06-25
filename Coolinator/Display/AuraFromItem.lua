---@class addonTableCoolinator
local addonTable = select(2, ...)

local lastItemID = 0
hooksecurefunc(C_Item, "UseItemByName",function(itemID)
  if type(itemID) == "string" then
    itemID = C_Item.GetItemIDForItemInfo(itemID)
  end
  lastItemID = itemID
end)
hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
  local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
  if C_Item.DoesItemExist(location) then
    lastItemID = C_Item.GetItemID(location)
  end
end)

local trackerFrame = CreateFrame("Frame")
trackerFrame.recorded = {}
trackerFrame.callbacksBySpellID = {}
trackerFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
trackerFrame:RegisterEvent("PLAYER_DEAD")
trackerFrame:SetScript("OnEvent", function(_, eventName, _, _, spellID)
  if eventName == "UNIT_SPELLCAST_SUCCEEDED" then
    local data = addonTable.Constants.AurasFromItems[spellID]
    if data then
      if data.duration == -1 then
        trackerFrame.recorded[spellID] = {start = GetTime(), duration = data.itemIDs[lastItemID]}
      else
        trackerFrame.recorded[spellID] = {start = GetTime(), duration = data.duration}
      end
      if trackerFrame.callbacksBySpellID[spellID] then
        trackerFrame.callbacksBySpellID[spellID]()
      end
    end
  elseif eventName == "PLAYER_DEAD" then
    for spellID, time in pairs(trackerFrame.recorded) do
      if not addonTable.Constants.AurasFromItems[spellID].deathPersistent then
        trackerFrame.recorded[spellID] = nil
        if trackerFrame.callbacksBySpellID[spellID] then
          trackerFrame.callbacksBySpellID[spellID]()
        end
      end
    end
  end
end)

addonTable.Display.AuraFromItemMixin = {}

function addonTable.Display.AuraFromItemMixin:OnLoad()
  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
  self:SetFlattensRenderLayers(true)

  self.Icon = self:CreateTexture()
  self.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  self.Icon:SetPoint("CENTER")
  local mask = self:CreateMaskTexture()
  mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
  mask:SetAllPoints(self.Icon)
  self.Icon:AddMaskTexture(mask)

  local overlay = self:CreateTexture(nil, "OVERLAY")
  overlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
  overlay:SetSize(50+18, 50+16)

  self.BaseCooldown = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
  self.BaseCooldown:SetAllPoints()
  self.BaseCooldown:SetDrawEdge(false)
	self.BaseCooldown:SetSwipeColor(0, 0, 0, 0.8);
  self.BaseCooldown:SetSwipeTexture("Interface/HUD/UI-HUD-CoolDownManager-Icon-Swipe")

  self:SetScript("OnEnter", self.OnEnter)
  self:SetScript("OnLeave", self.OnLeave)

  self.BaseCooldown:SetScript("OnCooldownDone", function()
    self:Hide()
  end)
end

function addonTable.Display.AuraFromItemMixin:Disable()
  if self.details then
    trackerFrame.callbacksBySpellID[self.details.resource.spellID] = nil
  end
  self:UnregisterAllEvents()
end

function addonTable.Display.AuraFromItemMixin:Setup(details)
  self.details = details
  self.data = addonTable.Constants.AurasFromItems[details.resource.spellID]
  self.Icon:SetTexture(C_Spell.GetSpellTexture(self.details.resource.spellID))
  self:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
  self:Import()
  trackerFrame.callbacksBySpellID[self.details.resource.spellID] = function()
    self:Import()
  end
  self.BaseCooldown:SetDrawSwipe(details.showSwipe)
  addonTable.Display.StyleIcon({id  = details.style}, self, self.Icon, nil, nil, {self.Icon}, {{text = true, widget = self.BaseCooldown}})
end

function addonTable.Display.AuraFromItemMixin:Import()
  local record = trackerFrame.recorded[self.details.resource.spellID]
  if record and record.start + record.duration > GetTime() then
    self:Show()
    self.BaseCooldown:SetCooldown(record.start, record.duration)
  else
    self:Hide()
    self.BaseCooldown:Clear()
  end
end

function addonTable.Display.AuraFromItemMixin:OnEnter()
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  GameTooltip:SetSpellByID(self.details.resource.spellID)
end

function addonTable.Display.AuraFromItemMixin:OnLeave()
  GameTooltip:Hide()
end
