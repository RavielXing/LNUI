---@class addonTableCoolinator
local addonTable = select(2, ...)

local function GetVisibleAurasOrdered(layout, mapping)
  local activeBars = {}
  for _, group in ipairs(layout.entries) do
    if group.kind == "bar" then
      if group.resource.kind == "aura" then
        if mapping[group.resource.spellID] then
          table.insert(activeBars, mapping[group.resource.spellID])
        end
      end
    elseif group.kind == "group" then
      local newActiveBars = GetVisibleAurasOrdered(group, mapping)
      tAppendAll(activeBars, newActiveBars)
    end
  end

  return activeBars
end

local function GetColor(rgb, a)
  local color = CreateColorFromRGBHexString(rgb)
  return {r = color.r, g = color.g, b = color.b, a = a}
end

local cooldownCategories = {
	Enum.CooldownViewerCategory.Essential,
	Enum.CooldownViewerCategory.Utility,
	Enum.CooldownViewerCategory.TrackedBuff,
	Enum.CooldownViewerCategory.TrackedBar,
};

local SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES = 2;
local SAVE_FIELD_ID_LAYOUTS = 3;
local SAVE_FIELD_ID_LAYOUT_ID_DATA = 4;

local SAVE_FIELD_ID_COOLDOWN_ORDER = 1;
local SAVE_FIELD_ID_CATEGORY_OVERRIDES = 2;
local SAVE_FIELD_ID_ALERT_OVERRIDES = 3;
local SAVE_FIELD_ID_HIDDEN_GROUP_BUFFS = 4;
local SAVE_FIELD_ID_GROUP_BUFF_VISUAL_ALERTS = 5;

function addonTable.Core.GetCDMData(doNotTryAgain)
  local tag = CooldownViewerUtil.GetCurrentClassAndSpecTag()
  local raw = C_CooldownViewer.GetLayoutData()
  raw = raw:match("^%d%|(.*)$")
  if raw then
    local cdmData = C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(raw), Enum.CompressionMethod.Deflate))
    if cdmData[1] < 4 then
      CooldownViewerSettings.dataSerialization:WriteData()
      if not doNotTryAgain then
        return addonTable.Core.GetCDMData(true)
      end
    end
    assert(cdmData[1] == 4 or cdmData[1] == 5, "Layout has changed, contact developer - " .. tostring(cdmData[1]))

    return cdmData, tag
  end

  return nil, tag
end

function addonTable.Core.GetCDMLayoutName()
  return "Coolinator (" .. CooldownViewerUtil.GetCurrentClassAndSpecTag() .. ")"
end

function addonTable.Core.ApplyLayoutToCDM(layout)
  local auraMapping = addonTable.Core.GetCDMMapping()
  local activeBars = GetVisibleAurasOrdered(layout, auraMapping)

  local cd1 = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Essential, true)
  local cd2 = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Utility, true)

  local part1 = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
  local part2 = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, true)

  local auras = {}
  tAppendAll(auras, part1)
  tAppendAll(auras, part2)
  local bars = {}

  for _, cdmID in ipairs(activeBars) do
    local index = tIndexOf(auras, cdmID)
    if index then
      table.remove(auras, index)
      table.insert(bars, cdmID)
    end
  end

  local abilitySpells = {}
  tAppendAll(abilitySpells, cd1)
  tAppendAll(abilitySpells, cd2)

  local compiledLayout = {
    [SAVE_FIELD_ID_COOLDOWN_ORDER] = nil,
    [SAVE_FIELD_ID_CATEGORY_OVERRIDES] = {
      [Enum.CooldownViewerCategory.TrackedBuff] = #auras > 0 and auras or nil,
      [Enum.CooldownViewerCategory.TrackedBar] = #bars > 0 and bars or nil,
      [Enum.CooldownViewerCategory.Essential] = abilitySpells,
    },
  }

  local emptyData = {
    [1] = 4,
    [2] = {},
    [3] = {},
    [4] = {},
  }

  local saved, wantedTag = addonTable.Core.GetCDMData()
  local cdmData = saved or emptyData

  assert(cdmData[1] == 4 or cdmData[1] == 5, "Layout format changed, contact developer")

  for key, value in pairs(emptyData) do
    if cdmData[key] == nil then
      cdmData[key] = value
    end
  end

  local layoutName = addonTable.Core.GetCDMLayoutName()

  local foundID
  for id, tag in pairs(cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA]) do
    if tag == layoutName then
      foundID = id
    end
  end
  if foundID then
    local compiledOverrides = compiledLayout[SAVE_FIELD_ID_CATEGORY_OVERRIDES]
    local foundOverrides = cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag][foundID][SAVE_FIELD_ID_CATEGORY_OVERRIDES] or {}
    if Enum.CooldownViewerCategory.GroupBuff then
      compiledOverrides[Enum.CooldownViewerCategory.GroupBuff] = foundOverrides[Enum.CooldownViewerCategory.GroupBuff]
    end
    compiledLayout[SAVE_FIELD_ID_ALERT_OVERRIDES] = cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag][foundID][SAVE_FIELD_ID_ALERT_OVERRIDES]
    compiledLayout[SAVE_FIELD_ID_HIDDEN_GROUP_BUFFS] = cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag][foundID][SAVE_FIELD_ID_HIDDEN_GROUP_BUFFS]
    compiledLayout[SAVE_FIELD_ID_GROUP_BUFF_VISUAL_ALERTS] = cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag][foundID][SAVE_FIELD_ID_GROUP_BUFF_VISUAL_ALERTS]
  end
  if not foundID then
    foundID = 1
    while cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA][foundID] do
      foundID = foundID + 1
    end
  end

  if cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag] == nil then
    cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag] = {}
  end
  cdmData[SAVE_FIELD_ID_LAYOUTS][wantedTag][foundID] = compiledLayout
  cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA][foundID] = layoutName

  if cdmData[SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES] == nil then
    cdmData[SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES] = {}
  end
  cdmData[SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES][wantedTag] = foundID

  local input = C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(cdmData), Enum.CompressionMethod.Deflate))
  C_CVar.SetCVar("cooldownViewerEnabled", "0")
  addonTable.Utilities.PurgeKey(CooldownViewerSettings.dataSerialization, "cachedSerializedData")
  addonTable.Utilities.PurgeKey(CooldownViewerSettings.dataProvider, "displayData")
  addonTable.Utilities.PurgeKey(CooldownViewerSettings.layoutManager, "activeLayoutID")
  C_CooldownViewer.SetLayoutData("1|" .. input)
  C_Timer.After(0, function()
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
  end)
end

function addonTable.Core.GetCDMMapping(activeOnly)
  local allAuras = {}

  tAppendAll(allAuras, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, not activeOnly))
  tAppendAll(allAuras, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, not activeOnly))
  local auraMapping = {}
  for _, cdmID in ipairs(allAuras) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdmID)
    auraMapping[info.spellID] = cdmID
    auraMapping[info.overrideSpellID] = cdmID
    auraMapping[C_Spell.GetBaseSpell(info.spellID)] = cdmID
    auraMapping[C_Spell.GetBaseSpell(info.overrideSpellID)] = cdmID
    if info.overrideTooltipSpellID then
      auraMapping[info.overrideTooltipSpellID] = cdmID
      auraMapping[C_Spell.GetBaseSpell(info.overrideTooltipSpellID)] = cdmID
    end
    for _, spellID in ipairs(info.linkedSpellIDs) do
      auraMapping[spellID] = cdmID
    end
  end

  local allAbilities = {}
  tAppendAll(allAbilities, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Essential, not activeOnly))
  tAppendAll(allAbilities, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Utility, not activeOnly))
  local abilityMapping = {}
  for _, cdmID in ipairs(allAbilities) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdmID)
    abilityMapping[info.spellID] = cdmID
    abilityMapping[info.overrideSpellID] = cdmID
    abilityMapping[C_Spell.GetBaseSpell(info.spellID)] = cdmID
    abilityMapping[C_Spell.GetBaseSpell(info.overrideSpellID)] = cdmID
    if info.overrideTooltipSpellID then
      abilityMapping[info.overrideTooltipSpellID] = cdmID
      abilityMapping[C_Spell.GetBaseSpell(info.overrideTooltipSpellID)] = cdmID
    end
    for _, spellID in ipairs(info.linkedSpellIDs) do
      abilityMapping[spellID] = cdmID
    end
  end

  return auraMapping, allAuras, abilityMapping, allAbilities
end

local function TriggerReload(reason)
  addonTable.Dialogs.ShowConfirm(addonTable.Locales.PLEASE_RELOAD_TO_GET_COOLINATOR_WORKING_REASON_X:format(reason), RELOADUI, CANCEL, ReloadUI)
end

function addonTable.Core.GetCDMOrder(layout)
  local cdmData, tag = addonTable.Core.GetCDMData()
  if not cdmData then
    TriggerReload(0)
    return
  end
  local id
  local correctName = addonTable.Core.GetCDMLayoutName()
  for i, name in pairs(cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA] or {}) do
    if name == correctName then
      id = i
      break
    end
  end
  if not id then
    TriggerReload(1)
    return
  end

  if cdmData[SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES][tag] ~= id then
    TriggerReload(2)
    return
  end

  if cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id][SAVE_FIELD_ID_COOLDOWN_ORDER] ~= nil or cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id][SAVE_FIELD_ID_CATEGORY_OVERRIDES][-2] ~= nil then
    TriggerReload(3)
    return
  end

  local bars = cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id][SAVE_FIELD_ID_CATEGORY_OVERRIDES][Enum.CooldownViewerCategory.TrackedBar] or {}
  local auraMappingAll, orderedAuras, abilityMappingAll, orderedAbilities = addonTable.Core.GetCDMMapping()
  local auraMappingActive, _, abilityMappingActive = addonTable.Core.GetCDMMapping(true)

  local aurasSaved = cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id][SAVE_FIELD_ID_CATEGORY_OVERRIDES][Enum.CooldownViewerCategory.TrackedBuff]
  local abilitiesSaved = cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id][SAVE_FIELD_ID_CATEGORY_OVERRIDES][Enum.CooldownViewerCategory.Essential]
  if aurasSaved == nil or #aurasSaved ~= (#orderedAuras - #bars) or abilitiesSaved == nil or #abilitiesSaved ~= #orderedAbilities then
    TriggerReload(4)
    return
  end

  local allBars = GetVisibleAurasOrdered(layout, auraMappingAll)

  if #bars ~= #allBars then
    TriggerReload(5)
    return
  end

  local auraOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, false)
  tAppendAll(auraOrder, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, false))

  local abilityOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Essential, false)
  tAppendAll(abilityOrder, C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Utility, false))

  local barOrder = {}

  for _, cdmID in ipairs(bars) do
    if tIndexOf(allBars, cdmID) == nil then
      TriggerReload(6)
      return
    end
  end

  for index = #auraOrder, 1, -1 do
    if tIndexOf(bars, auraOrder[index]) ~= nil then
      table.insert(barOrder, 1, auraOrder[index])
      table.remove(auraOrder, index)
    end
  end

  local auraOrderMap, barOrderMap, abilityOrderMap = {}, {}, {}
  local auraCount, barCount = 0, 0

  for index, cdmID in ipairs(auraOrder) do
    auraCount = auraCount + 1
    auraOrderMap[cdmID] = index
  end

  for index, cdmID in ipairs(barOrder) do
    barCount = barCount + 1
    barOrderMap[cdmID] = index
  end

  for index, cdmID in ipairs(abilityOrder) do
    abilityOrderMap[cdmID] = index
  end

  return {auraMap = auraMappingActive, abilityMap = abilityMappingActive, auraOrder = auraOrderMap, auraCount = auraCount, barOrder = barOrderMap, barCount = barCount, abilityOrder = abilityOrderMap}
end

function addonTable.Core.GetExistingLayoutName()
  local cdmData , tag = addonTable.Core.GetCDMData()
  if not cdmData or not cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA] then
    return nil
  end

  for id, label in pairs(cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA]) do
    if cdmData[SAVE_FIELD_ID_LAYOUTS][tag] ~= nil and cdmData[SAVE_FIELD_ID_LAYOUTS][tag][id] ~= nil and cdmData[SAVE_FIELD_ID_ACTIVE_LAYOUT_NAMES][tag] == id and label ~= addonTable.Core.GetCDMLayoutName() then
      return label
    end
  end
end

function addonTable.Core.GenerateCoolinatorLayoutFromExisting(layoutName)
  local cdmData , tag = addonTable.Core.GetCDMData(true)
  if not cdmData then
    return
  end

  local layoutID
  local correctName = layoutName
  for i, name in pairs(cdmData[SAVE_FIELD_ID_LAYOUT_ID_DATA] or {}) do
    if name == correctName then
      layoutID = i
      break
    end
  end

  local overrides = cdmData[SAVE_FIELD_ID_LAYOUTS][tag][layoutID][SAVE_FIELD_ID_CATEGORY_OVERRIDES] or {}
  local barsSaved = overrides[Enum.CooldownViewerCategory.TrackedBar] or {}
  local aurasSaved = overrides[Enum.CooldownViewerCategory.TrackedBuff] or {}
  local essentialSaved = overrides[Enum.CooldownViewerCategory.Essential] or {}
  local utilitySaved = overrides[Enum.CooldownViewerCategory.Utility] or {}
  local hiddenAuras = overrides[Enum.CooldownViewerCategory.HiddenAura] or {}
  local hiddenAbilities = overrides[Enum.CooldownViewerCategory.HiddenSpell] or {}

  local essentialOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Essential, false)
  local utilityOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.Utility, false)

  local auraOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, false)
  local barOrder = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, false)

  local order = cdmData[SAVE_FIELD_ID_LAYOUTS][tag][layoutID][SAVE_FIELD_ID_COOLDOWN_ORDER]
  local orderMap = {}
  if order and #order > 0 then
    for index, cooldownID in ipairs(order) do
      orderMap[cooldownID] = index
    end
  else
    local complete = {}
    tAppendAll(complete, auraOrder)
    tAppendAll(complete, barOrder)
    tAppendAll(complete, essentialOrder)
    tAppendAll(complete, utilityOrder)

    for index, cooldownID in ipairs(complete) do
      orderMap[cooldownID] = index
    end
  end

  auraOrder = tFilter(auraOrder, function(cooldownID)
    return tIndexOf(hiddenAuras, cooldownID) == nil
  end, true)
  barOrder = tFilter(barOrder, function(cooldownID)
    return tIndexOf(hiddenAuras, cooldownID) == nil
  end, true)

  essentialOrder = tFilter(essentialOrder, function(cooldownID)
    return tIndexOf(hiddenAbilities, cooldownID) == nil
  end, true)
  utilityOrder = tFilter(utilityOrder, function(cooldownID)
    return tIndexOf(hiddenAbilities, cooldownID) == nil
  end, true)

  for index = #essentialOrder, 1, -1 do
    local cooldownID = essentialOrder[index]
    if tIndexOf(utilitySaved, cooldownID) ~= nil then
      table.remove(essentialOrder, index)
    elseif C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID).flags ~= Enum.CooldownSetSpellFlags.HideByDefault and tIndexOf(essentialSaved, cooldownID) == nil then
      table.insert(essentialSaved, cooldownID)
    end
  end

  for index = #utilityOrder, 1, -1 do
    local cooldownID = utilityOrder[index]
    if tIndexOf(essentialSaved, cooldownID) ~= nil then
      table.remove(utilityOrder, index)
    elseif C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID).flags ~= Enum.CooldownSetSpellFlags.HideByDefault and tIndexOf(utilitySaved, cooldownID) == nil then
      table.insert(utilitySaved, cooldownID)
    end
  end

  for index = #auraOrder, 1, -1 do
    local cooldownID = auraOrder[index]
    local flags = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID).flags
    if tIndexOf(barsSaved, cooldownID) ~= nil then
      table.remove(auraOrder, index)
    elseif bit.band(flags, Enum.CooldownSetSpellFlags.HideByDefault) == 0 and bit.band(flags, Enum.CooldownSetSpellFlags.HideAura) == 0 and tIndexOf(barsSaved, cooldownID) == nil then
      table.insert(aurasSaved, cooldownID)
    end
  end

  for index = #barOrder, 1, -1 do
    local cooldownID = barOrder[index]
    local flags = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID).flags
    if tIndexOf(aurasSaved, cooldownID) ~= nil then
      table.remove(barOrder, index)
    elseif bit.band(flags, Enum.CooldownSetSpellFlags.HideByDefault) == 0 and bit.band(flags, Enum.CooldownSetSpellFlags.HideAura) == 0 and tIndexOf(barsSaved, cooldownID) == nil then
      table.insert(barsSaved, cooldownID)
    end
  end

  table.sort(essentialSaved, function(a, b) return (orderMap[a] or 100000) < (orderMap[b] or 100000) end)
  table.sort(utilitySaved, function(a, b) return (orderMap[a] or 100000) < (orderMap[b] or 100000) end)
  table.sort(aurasSaved, function(a, b) return (orderMap[a] or 100000) < (orderMap[b] or 100000) end)
  table.sort(barsSaved, function(a, b) return (orderMap[a] or 100000) < (orderMap[b] or 100000) end)

  local result = {
    kind = "group",
    layout = "vertical",
    anchor = {"BOTTOM", "UIParent", "BOTTOM", 0, 200},
    preset = "DEFAULT",
    padding = 0.2,
    alpha = 1,
    scale = 1,
    alignment = "CENTER",
    entries = {
      {
        kind = "group",
        layout = "horizontal",
        direction = "right",
        padding = 0.1,
        alpha = 1,
        scale = 0.8,
        preset = "UTILITY",
        alignment = "CENTER",
        entries = {},
      },
      {
        kind = "group",
        layout = "horizontal",
        direction = "right",
        padding = 0.1,
        alpha = 1,
        scale = 1.25,
        preset = "ESSENTIAL",
        alignment = "CENTER",
        entries = {},
      },
      {
        kind = "group",
        layout = "horizontal",
        direction = "right",
        padding = 0.1,
        alpha = 1,
        scale = 1,
        preset = "AURAS",
        alignment = "CENTER",
        entries = {},
      },
    }
  }

  local seen = {}
  for _, id in ipairs(utilitySaved) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info then
      local spellID = addonTable.Core.GetSpellFromCDMInfo(info)
      if not seen[spellID] then
        local entry = CopyTable(addonTable.Designer.Defaults.AbilityIcon)
        entry.preset = "UTILITY"
        entry.resource.spellID = spellID
        table.insert(result.entries[1].entries, entry)
      end
      seen[spellID] = true
    end
  end

  for _, id in ipairs(essentialSaved) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info then
      local spellID = addonTable.Core.GetSpellFromCDMInfo(info)
      if not seen[spellID] then
        local entry = CopyTable(addonTable.Designer.Defaults.AbilityIcon)
        entry.preset = "ESSENTIAL"
        entry.resource.spellID = spellID
        table.insert(result.entries[2].entries, entry)
      end
      seen[spellID] = true
    end
  end

  for _, id in ipairs(aurasSaved) do
    local entry = CopyTable(addonTable.Designer.Defaults.AuraIcon)
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info then
      entry.preset = "AURA"
      entry.resource.spellID = addonTable.Core.GetSpellFromCDMInfo(info)
      table.insert(result.entries[3].entries, entry)
    end
  end

  local barGroups = {
    kind = "group",
    layout = "vertical",
    padding = 0.2,
    alpha = 1,
    alignment = "CENTER",
    scale = 1,
    preset = "AURA_BARS",
    entries = {
    }
  }
  for _, id in ipairs(barsSaved) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info then
      local spellID = addonTable.Core.GetSpellFromCDMInfo(info)
      print(C_Spell.GetSpellName(spellID))
      table.insert(barGroups.entries, {
        kind = "bar",
        resource = {kind = "aura", spellID = spellID},
        width = 1, --0 -- widest of the entries just above or just below in the layout
        height = 1,
        scale = 1.5,
        layout = "horizontal",
        direction = "right",
        icon = {show = true, position = "left"},
        alpha = 1,
        preset = "DEFAULT",
        foreground = {
          asset = "Cooli: Fade Bottom",
          color = {r = 0, g = 1, b = 0},
        },
        background = {
          asset = "Cooli: Solid White",
          color = GetColor("94ff21", 0.3),
        },
        border = {
          asset = "Cooli: Blizzard Midnight",
          color = {r = 1, g = 1, b = 1},
        },
      })
    end
  end

  table.insert(result.entries, barGroups)

  --[[table.insert(result.entries, {
    kind = "bar",
    resource = {kind = "class", resource = "icicles"},
    width = 2, --0, -- widest of the entries just above or just below in the layout
    height = 0.65,
    scale = 1.5,
    alpha = 1,
    layout = "horizontal",
    direction = "left",
    icon = {show = true, position = "right"},
    foreground = {
      asset = "Cooli: Fade Right",
      color = {r = 0, g = 0, b = 1},
    },
    background = {
      asset = "Cooli: Solid White",
      color = GetColor("6bcbff", 0.3),
    },
    border = {
      asset = "Platy: Round Thin",
      color = {r = 0, g = 0, b = 0},
    },
  })]]

  local final = {
    kind = "group",
    version = 2,
    layout = "standalone",
    entries = {
      result
    },
  }
  addonTable.Core.GeneratePresetsFromDesign(final, false)
  addonTable.Core.RemoveDeadGroups(final)
  return final
end
