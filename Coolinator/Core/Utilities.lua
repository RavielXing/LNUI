---@class addonTableCoolinator
local addonTable = select(2, ...)

function addonTable.Utilities.Message(text)
  print("|cff96742a" .. addonTable.Locales.COOLINATOR .. "|r: " .. text)
end

function addonTable.Utilities.InitFrameWithMixin(parent, mixin)
  local f = CreateFrame("Frame", nil, parent)
  Mixin(f, mixin)
  f:OnLoad()
  return f
end

do
  local callbacksPending = {}
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(_, _, addonName)
    if callbacksPending[addonName] then
      for _, cb in ipairs(callbacksPending[addonName]) do
        xpcall(cb, CallErrorHandler)
      end
      callbacksPending[addonName] = nil
    end
  end)

  local AddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

  -- Necessary because cannot nest EventUtil.ContinueOnAddOnLoaded
  function addonTable.Utilities.OnAddonLoaded(addonName, callback)
    if select(2, AddOnLoaded(addonName)) then
      xpcall(callback, CallErrorHandler)
    else
      callbacksPending[addonName] = callbacksPending[addonName] or {}
      table.insert(callbacksPending[addonName], callback)
    end
  end
end

local prevSpec = 1
function addonTable.Utilities.GetSpecID()
  local specIndex = C_SpecializationInfo.GetSpecialization() or prevSpec
  local spec = C_SpecializationInfo.GetSpecializationInfo(specIndex)
  prevSpec = specIndex
  return spec
end

function addonTable.Utilities.PurgeKey(t, k)
  t[k] = nil
  local c = 42
  repeat
    if t[c] == nil then
      t[c] = nil
    end
    c = c + 1
  until issecurevariable(t, k)
end

function addonTable.Utilities.IsAuraSpellKnown(spellID)
  if addonTable.Constants.AurasFromItems[spellID] then
    return spellID
  end
  local mapped = addonTable.State.CDM.auraMap[spellID]
  if mapped then
    local isKnown = C_CooldownViewer.GetCooldownViewerCooldownInfo(mapped).isKnown
    if isKnown then
      return spellID
    end
  end
end

function addonTable.Utilities.IsAbilitySpellKnown(spellID)
  local newSpellID = C_Spell.GetOverrideSpell(spellID)
  if newSpellID then
    if C_SpellBook.IsSpellKnown(newSpellID, Enum.SpellBookSpellBank.Player) or C_SpellBook.IsSpellKnown(newSpellID, Enum.SpellBookSpellBank.Pet) then
      return newSpellID
    end
  end
  newSpellID = addonTable.SpellEquivalence[spellID]
  if newSpellID then
    if C_SpellBook.IsSpellKnown(newSpellID, Enum.SpellBookSpellBank.Player) or C_SpellBook.IsSpellKnown(newSpellID, Enum.SpellBookSpellBank.Pet) then
      return newSpellID
    end
  end
  if C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player) or C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Pet) then
    return spellID
  end
  if spellID == addonTable.Constants.GCD then
    return spellID
  end

  return nil
end
