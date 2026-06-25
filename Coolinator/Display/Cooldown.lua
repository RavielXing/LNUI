---@class addonTableCoolinator
local addonTable = select(2, ...)

addonTable.Display.CooldownMixin = {}
function addonTable.Display.CooldownMixin:OnLoad()
  self:SetSize(addonTable.Constants.nativeSize - 4, addonTable.Constants.nativeSize - 4)
  self:SetFlattensRenderLayers(true)

  self.Icon = self:CreateTexture(nil, "OVERLAY")
  self.Icon:SetSize(addonTable.Constants.nativeSize, addonTable.Constants.nativeSize)
  self.Icon:SetPoint("CENTER")
  self.NotUsable = self:CreateTexture(nil, "OVERLAY")
  self.NotUsable:SetAllPoints(self.Icon)
  self.NotUsable:SetTexture("Interface/AddOns/Coolinator/Assets/Special/white.png")
  self.NotUsable:SetVertexColor(0, 0, 0, 0.5)

  self.ChargesCooldown = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
  self.ChargesCooldown:SetAllPoints(self.Icon)
  self.ChargesCooldown:SetDrawSwipe(false)
  self.ChargesCooldown:SetSwipeTexture("Interface/HUD/UI-HUD-CoolDownManager-Icon-Swipe")

  self.BaseCooldown = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
  self.BaseCooldown:SetAllPoints(self.Icon)
  self.BaseCooldown:SetDrawEdge(false)
	self.BaseCooldown:SetSwipeColor(0, 0, 0, 0.8);
  self.BaseCooldown:SetSwipeTexture("Interface/HUD/UI-HUD-CoolDownManager-Icon-Swipe")

  self.CountFrame = CreateFrame("Frame", nil, self)
  self.CountFrame:SetAllPoints(self.Icon)
  self.CountFrame.text = self.CountFrame:CreateFontString(nil, nil, "NumberFontNormal")

  self.KeyBindingFrame = CreateFrame("Frame", nil, self)
  self.KeyBindingFrame:SetAllPoints(self.Icon)
  self.KeyBindingFrame.text = self.KeyBindingFrame:CreateFontString(nil, nil, "NumberFontNormal")
  self.KeyBindingFrame.text:SetWidth(addonTable.Constants.nativeSize - 6)
  self.KeyBindingFrame.text:SetWordWrap(false)
  self.KeyBindingFrame.text:SetJustifyH("RIGHT")

	self.SpellActivationAlert = CreateFrame("Frame", nil, self, "ActionButtonSpellAlertTemplate");
	local frameWidth, frameHeight = self:GetSize();
	self.SpellActivationAlert:SetSize(frameWidth * 1.4, frameHeight * 1.4);
	self.SpellActivationAlert:SetPoint("CENTER", self, "CENTER", 0, 0);
	self.SpellActivationAlert:SetFrameStrata("MEDIUM")

  self:SetScript("OnEvent", self.OnEvent)
  self:SetScript("OnEnter", self.OnEnter)
  self:SetScript("OnLeave", self.OnLeave)
end

function addonTable.Display.CooldownMixin:Style()
  addonTable.Display.StyleIcon({id = self.details.style}, self, self.Icon, self.CountFrame.text, self.KeyBindingFrame.text,
    {self.Icon, self.NotUsable},
    {{swipe = true, text = true, widget = self.BaseCooldown}, {text = true, widget = self.ChargesCooldown},}
  )
end

function addonTable.Display.CooldownMixin:OnEnter()
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  if self.spellID then
    GameTooltip:SetSpellByID(self.spellID)
  elseif self.itemID then
    GameTooltip:SetSpellByID(select(2, C_Item.GetItemSpell(self.itemID)))
  elseif self.equipmentSlot then
    GameTooltip:SetInventoryItem("player", self.equipmentSlot)
  end
end

function addonTable.Display.CooldownMixin:OnLeave()
  GameTooltip:Hide()
end

function addonTable.Display.CooldownMixin:OnEvent(eventName, data, ...)
  if eventName == "SPELL_UPDATE_COOLDOWN" then
    if self.spellID then
      self:UpdateSpellByID(self.spellID, true)
    elseif self.itemID then
      self:UpdateItemByID(self.itemID)
    elseif self.equipmentSlot then
      self:UpdateItemByEquipmentSlot(self.equipmentSlot)
    end
  elseif eventName == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and self.spellID and C_Spell.GetBaseSpell(data) == C_Spell.GetBaseSpell(self.spellID) then
    self:SetActivationAlert(true)
  elseif eventName == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" and self.spellID and C_Spell.GetBaseSpell(data) == C_Spell.GetBaseSpell(self.spellID) then
    self:SetActivationAlert(false)
  elseif eventName == "SPELL_RANGE_CHECK_UPDATE" and self.spellID and data == self.spellID then
    local isInRange, checkedRange = ...
    if not checkedRange or isInRange then
      self.Icon:SetVertexColor(1, 1, 1, 1)
    else
      self.Icon:SetVertexColor(0.8, 0, 0, 1)
    end
  elseif eventName == "SPELL_UPDATE_USABLE" and self.spellID then
    self.NotUsable:SetShown(not C_Spell.IsSpellUsable(self.spellID))
  elseif eventName == "SPELL_UPDATE_CHARGES" and self.spellID then
    self:UpdateSpellCharges()
  end
end

function addonTable.Display.CooldownMixin:SetActivationAlert(state)
  if state then
    self.SpellActivationAlert:Show()
	  self.SpellActivationAlert.ProcStartFlipbook:Show();
	  self.SpellActivationAlert.ProcLoopFlipbook:Show();
	  self.SpellActivationAlert.ProcAltGlow:Hide();
	  self.SpellActivationAlert.ProcStartAnim:Play();
	  self.SpellActivationAlert:Raise()
	else
	  self.SpellActivationAlert:Hide()
	  self.SpellActivationAlert.ProcStartAnim:Stop();
	end
end

function addonTable.Display.CooldownMixin:SetEnabled(state)
  if state then
    self:Enable()
  else
    self:Disable()
  end
end

function addonTable.Display.CooldownMixin:Enable()
  self.itemID = nil
  self.spellID = nil

  self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE")
  self:RegisterEvent("SPELL_UPDATE_USABLE")
  self:RegisterEvent("SPELL_UPDATE_CHARGES")

  addonTable.CallbackRegistry:RegisterCallback("Update.SpellIcons", function(_, spellID)
    if self.spellID and (not spellID or C_Spell.GetBaseSpell(self.spellID) == spellID) then
      self.Icon:SetTexture(C_Spell.GetSpellTexture(self.spellID))
    end
  end, self)
  addonTable.CallbackRegistry:RegisterCallback("Update.KeyBindings", function(_, spellID)
    self:UpdateBindingText()
  end, self)
  addonTable.CallbackRegistry:RegisterCallback("Update.SpellsDisplay", function(_, spellID)
    if not self.spellID then
      return
    end
    local override = C_Spell.GetOverrideSpell(self.details.resource.spellID)
    if override ~= self.spellID then
      self:UpdateSpellByID(override)
    end
  end, self)
end

function addonTable.Display.CooldownMixin:Disable()
  if self.spellID then
    C_Spell.EnableSpellRangeCheck(self.spellID, false)
  end
  self.itemID = nil
  self.spellID = nil

  self:UnregisterAllEvents()
  addonTable.CallbackRegistry:UnregisterCallback("Update.SpellIcons", self)
end

function addonTable.Display.CooldownMixin:Setup(details)
  self.details = details
  self.spellID = nil
  self.itemID = nil
  self.equipmentSlot = nil

  if details.resource.spellID then
    self.ignoreGCD = details.resource.spellID ~= addonTable.Constants.GCD and not addonTable.Config.Get(addonTable.Config.Options.SHOW_GCD_SWIPE)
    self:UpdateSpellByID(addonTable.Utilities.IsAbilitySpellKnown(details.resource.spellID) or details.resource.spellID)
  elseif details.resource.itemID then
    self:UpdateItemByID(details.resource.itemID)
  else
    self:UpdateItemByEquipmentSlot(details.resource.equipmentSlot)
  end

  self.BaseCooldown:SetScript("OnCooldownDone", nil)
  self.BaseCooldown:SetDrawSwipe(details.showSwipe)
  self.ChargesCooldown:SetDrawEdge(details.showSwipe)
  self.BaseCooldown:SetCountdownFormatter(addonTable.Display.GetDurationFormatter(details.texts.cooldown.showFractions))
  self.BaseCooldown:SetCountdownFormatter(addonTable.Display.GetDurationFormatter(details.texts.cooldown.showFractions))
  self.desaturateCooldown = details.desaturateCooldown

  self:UpdateBindingText()
  self:Style()

  self:SetMouseMotionEnabled(addonTable.Config.Get(addonTable.Config.Options.SHOW_TOOLTIPS))
end

function addonTable.Display.CooldownMixin:UpdateBindingText()
  if not addonTable.Config.Get(addonTable.Config.Options.SHOW_KEYBINDINGS) then
    self.KeyBindingFrame.text:SetText("")
    return
  end
  local binding
  if self.spellID then
    binding = addonTable.State.Bindings.spells[C_Spell.GetBaseSpell(self.spellID)]
  elseif self.itemID then
    binding = addonTable.State.Bindings.items[self.itemID]
  elseif self.equipmentSlot then
    local location = ItemLocation:CreateFromEquipmentSlot(self.equipmentSlot)
    if C_Item.DoesItemExist(location) then
      binding = addonTable.State.Bindings.items[C_Item.GetItemID(location)]
    end
  end
  self.KeyBindingFrame.text:SetText(binding and binding.binding or "")
end

function addonTable.Display.CooldownMixin:UpdateSpellByID(spellID, activationOff)
  self.spellID = spellID

  local chargesInfo = C_Spell.GetSpellCharges(spellID)
  local cooldownInfo = C_Spell.GetSpellCooldown(spellID)

  if chargesInfo and chargesInfo.isActive  then
    local chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
    self.ChargesCooldown:SetCooldownFromDurationObject(chargeDuration)
    self.ChargesCooldown:SetAlphaFromBoolean(C_Spell.GetSpellCharges(spellID))
    self.ChargesCooldown:SetHideCountdownNumbers(not self.details.texts.cooldown.visible or cooldownInfo.isActive and not cooldownInfo.isOnGCD)
  else
    self.ChargesCooldown:Clear()
  end

  if cooldownInfo.isActive then
    local baseDuration = C_Spell.GetSpellCooldownDuration(spellID, self.ignoreGCD)
    self.BaseCooldown:SetCooldownFromDurationObject(baseDuration)
    self.BaseCooldown:SetHideCountdownNumbers(not self.details.texts.cooldown.visible or cooldownInfo.isOnGCD)
    if self.desaturateCooldown and not cooldownInfo.isOnGCD then
      self.Icon:SetDesaturated(baseDuration:IsActive())
    else
      self.Icon:SetDesaturated(false)
    end
    self.BaseCooldown:SetScript("OnCooldownDone", function()
      self.Icon:SetDesaturated(false)
    end)
  else
    self.Icon:SetDesaturated(false)
  end

  self.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))
  self:UpdateSpellCharges()

  if not activationOff then
    self:SetActivationAlert(C_SpellActivationOverlay.IsSpellOverlayed(spellID))
  end
  C_Spell.EnableSpellRangeCheck(self.spellID, true)
  if C_Spell.IsSpellInRange(self.spellID, "target") == false then
    self.Icon:SetVertexColor(0.8, 0, 0, 1)
  else
    self.Icon:SetVertexColor(1, 1, 1, 1)
  end
  local isUsable = C_Spell.IsSpellUsable(self.spellID)
  self.NotUsable:SetShown(not isUsable)
end

function addonTable.Display.CooldownMixin:UpdateSpellCharges()
  local binding = addonTable.State.Bindings.spells[C_Spell.GetBaseSpell(self.spellID)]
  if binding then
    self.CountFrame.text:SetText(C_ActionBar.GetActionDisplayCount(binding.action))
  else
    self.CountFrame.text:SetText(C_Spell.GetSpellDisplayCount(self.spellID))
  end
end

function addonTable.Display.CooldownMixin:UpdateItemByID(itemID)
  self.itemID = itemID

  self.ChargesCooldown:Clear()
  local start, duration, enable = C_Item.GetItemCooldown(self.itemID)
  local durationObject = C_DurationUtil.CreateDuration()
  durationObject:SetTimeFromStart(start, duration)
  self.ChargesCooldown:SetCooldownFromDurationObject(durationObject)
  self.CountFrame.text:SetText(C_Item.GetItemCount(self.itemID, false, true))
  self.Icon:SetTexture(C_Item.GetItemIconByID(self.itemID))

  if C_Item.GetItemCount(self.itemID) == 0 then
    C_Timer.After(0, function()
      addonTable.CallbackRegistry:TriggerEvent("Layout")
    end)
  end

  self.NotUsable:Hide()
end

function addonTable.Display.CooldownMixin:UpdateItemByEquipmentSlot(equipmentSlot)
  self.equipmentSlot = equipmentSlot

  local location = ItemLocation:CreateFromEquipmentSlot(equipmentSlot)
  if not C_Item.DoesItemExist(location) then
    C_Timer.After(0, function()
      addonTable.CallbackRegistry:TriggerEvent("Layout")
    end)
    return
  end

  self.ChargesCooldown:Clear()
  local start, duration, enable = GetInventoryItemCooldown("player", equipmentSlot)
  local durationObject = C_DurationUtil.CreateDuration()
  durationObject:SetTimeFromStart(start, duration)
  self.BaseCooldown:SetCooldownFromDurationObject(durationObject)
  self.CountFrame.text:SetText(C_Item.GetItemCount(C_Item.GetItemID(location), false, true))
  self.Icon:SetTexture(C_Item.GetItemIcon(location))

  self.NotUsable:Hide()
end
