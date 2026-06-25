---@class addonTableCoolinator
local addonTable = select(2, ...)

local function Announce()
  addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
end

local Kind = {
  Spell = 1,
  Item = 2,
  Equipment = 3,
}
local function GetSpellIconDialog(allGetter, activeGetter, kind)
  local frame = addonTable.CustomiseDialog.Components.GetContentFrame("CoolinatorDesignerAuraInsertDialog", 300, 350)
  local container = CreateFrame("Frame", nil, frame)
  container:SetPoint("TOPLEFT", addonTable.Constants.ButtonFrameOffset, -25)
  container:SetPoint("BOTTOMRIGHT")
  
  frame.scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
  frame.scrollBox:SetPoint("TOPLEFT")
  frame.scrollBox:SetPoint("BOTTOMRIGHT", -10, 0)
  frame.scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
  frame.scrollBar:SetPoint("TOPRIGHT", -8, 0)
  frame.scrollBar:SetPoint("BOTTOMRIGHT", -8, 0)
  frame.view = CreateScrollBoxListGridView(6, 10, 10, 10, 10, 5, 5)
  frame.view:SetElementSizeCalculator(function()
    return 40, 40
  end)
  frame.view:SetElementInitializer("Button", function(button, data)
    if not button.setup then
      button.setup = true
      button.Icon = button:CreateTexture()
      button.Icon:SetAllPoints()
      button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
      button.Highlight:SetBlendMode("ADD")
      button.Highlight:SetTexture("Interface/Buttons/ButtonHilight-Square")
      button.Highlight:SetAllPoints()
    end
    button.Highlight:Hide()
    if kind == Kind.Spell then
      local override = C_Spell.GetOverrideSpell(data)
      button.Icon:SetDesaturated(not addonTable.Utilities.IsAuraSpellKnown(override) and not addonTable.Utilities.IsAbilitySpellKnown(override))
      button.Icon:SetTexture(C_Spell.GetSpellTexture(override))
    elseif kind == Kind.Item then
      button.Icon:SetDesaturated(C_Item.GetItemCount(data) == 0)
      button.Icon:SetTexture(C_Item.GetItemIconByID(data))
    elseif kind == Kind.Equipment then
      local location = ItemLocation:CreateFromEquipmentSlot(data)
      button.Icon:SetDesaturated(not C_Item.DoesItemExist(location))
      button.Icon:SetTexture(C_Item.DoesItemExist(location) and C_Item.GetItemIcon(location) or C_Item.GetItemIconByID(0))
    else
      assert(false)
    end
    button:SetScript("OnClick", function()
      frame.callback(data)
      frame:Hide()
    end)
    button:SetScript("OnEnter", function()
      button.Highlight:Show()
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      if kind == Kind.Spell then
        GameTooltip:SetSpellByID(C_Spell.GetOverrideSpell(data))
      elseif kind == Kind.Item then
        GameTooltip:SetItemByID(data)
      elseif kind == Kind.Equipment then
        if button.Icon:IsDesaturated() then
          GameTooltip:SetText(C_Item.GetItemInventorySlotInfo(data))
          GameTooltip:AddLine(addonTable.Locales.NOTHING_IN_SLOT)
          GameTooltip:Show()
        else
          GameTooltip:SetInventoryItem("player", data)
        end
      end
    end)
    button:SetScript("OnLeave", function()
      button.Highlight:Hide()
      GameTooltip:Hide()
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollBox, frame.scrollBar, frame.view)

  function frame:Update(callback)
    frame.callback = callback
    local all = allGetter()
    table.sort(all)
    local seen = activeGetter()
    all = tFilter(all, function(data)
      return not seen[data]
    end, true)
    frame.view:SetDataProvider(CreateDataProvider(all))
    frame:Show()
  end

  return frame
end

function addonTable.Designer.GetAuraDialog()
  local dialog = GetSpellIconDialog(addonTable.Core.GetAllAuras, function()
    return addonTable.Designer.GetActiveAuras(addonTable.Designer.GetCurrent())
  end, Kind.Spell)
  dialog:SetTitle(addonTable.Locales.CHOOSE_AURA)

  return dialog
end

function addonTable.Designer.GetAbilityDialog()
  local dialog = GetSpellIconDialog(addonTable.Core.GetAllAbilities, function()
    return addonTable.Designer.GetActiveAbilities(addonTable.Designer.GetCurrent())
  end, Kind.Spell)
  dialog:SetTitle(addonTable.Locales.CHOOSE_ABILITY)

  return dialog
end

function addonTable.Designer.GetPotionEffectDialog()
  local all = GetKeysArray(addonTable.Constants.AurasFromItems)
  local dialog = GetSpellIconDialog(function()
    return all
  end, function()
    return addonTable.Designer.GetActiveAuras(addonTable.Designer.GetCurrent())
  end, Kind.Spell)
  dialog:SetTitle(addonTable.Locales.CHOOSE_POTION_EFFECT)

  return dialog
end

function addonTable.Designer.GetItemDialog()
  local all = addonTable.Core.GetAllItems()
  local dialog = GetSpellIconDialog(function()
    return all
  end, function()
    return addonTable.Designer.GetActiveItems(addonTable.Designer.GetCurrent())
  end, Kind.Item)
  dialog:SetTitle(addonTable.Locales.CHOOSE_ITEM)

  return dialog
end

function addonTable.Designer.GetEquipmentDialog()
  local all = addonTable.Core.GetAllEquipment()
  local dialog = GetSpellIconDialog(function()
    return all
  end, function()
    return addonTable.Designer.GetActiveEquipment(addonTable.Designer.GetCurrent())
  end, Kind.Equipment)
  dialog:SetTitle(addonTable.Locales.CHOOSE_EQUIPMENT)

  return dialog
end
