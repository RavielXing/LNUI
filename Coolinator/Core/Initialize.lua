---@class addonTableCoolinator
local addonTable = select(2, ...)

-- 确保 Core 表存在，防止后续调用崩溃
addonTable.Core = addonTable.Core or {}

addonTable.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
addonTable.CallbackRegistry:OnLoad()
addonTable.CallbackRegistry:GenerateCallbackEvents(addonTable.Constants.Events)

local hidden = CreateFrame("Frame")
hidden:Hide()
addonTable.hiddenFrame = hidden

local function ImportExisting()
  local spec = addonTable.Utilities.GetSpecID()
  local existing = addonTable.Core.GetExistingLayoutName and addonTable.Core.GetExistingLayoutName()
  local assignments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
  -- Import existing layout (if set)
  if existing and (assignments[spec] == nil or assignments[spec] == addonTable.Constants.DefaultName) then
    local designs = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)[spec]
    local newName = addonTable.Locales.IMPORTED_X:format(existing)
    if not addonTable.Core.GenerateCoolinatorLayoutFromExisting then return false end
    local new = addonTable.Core.GenerateCoolinatorLayoutFromExisting(existing)
    if not new.entries[1] or #new.entries[1].entries == 0 then
      return
    end
    designs[newName] = new
    assignments[spec] = newName

    return true
  end
  return false
end

function addonTable.Core.AutoGenerateLayout(name)
  local spec = addonTable.Utilities.GetSpecID()
  local designs = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
  if not designs[spec] then
    designs[spec] = {}
  end
  if addonTable.Core.GenerateDefaultCDMLayout then
    designs[spec][name or addonTable.Constants.DefaultName] = addonTable.Core.GenerateDefaultCDMLayout()
  end
  local assignments = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)
  if assignments[spec] == nil then
    assignments[spec] = addonTable.Constants.DefaultName
  end
end

function addonTable.Core.Initialize()
  addonTable.Config.InitializeData()
  addonTable.SlashCmd.Initialize()

  if addonTable.Core.MigrateSettings then
    addonTable.Core.MigrateSettings()
  end

  addonTable.Assets.Initialize()
  addonTable.CustomiseDialog.Initialize()
  addonTable.Designer.Initialize()

  CreateFrame("Frame", "CoolinatorPrimaryGroupAnchor")

  addonTable.State.UsingMasque = C_AddOns.IsAddOnLoaded("Masque") and addonTable.Config.Get(addonTable.Config.Options.USE_MASQUE)
end

local function GetCDMActiveLayout()
  local id = CooldownViewerSettings.layoutManager.activeLayoutID
  local layout = CooldownViewerSettings.layoutManager.layouts[id]
  return layout and layout.layoutName
end

local function ValidateCDM()
  if GetCDMActiveLayout() ~= "Coolinator (" .. CooldownViewerUtil.GetCurrentClassAndSpecTag() .. ")" then
    addonTable.State.CDM = nil
    addonTable.Dialogs.ShowConfirm(addonTable.Locales.SPEC_MISMATCH_IN_BLIZZARD_CDM, RELOADUI, CANCEL, ReloadUI)
    return false
  end
  return true
end

local function TriggerUpdate()
  addonTable.CallbackRegistry:TriggerEvent("CDMUpdating", true)
  if addonTable.Core.GetFont then
    addonTable.CurrentNumberFont = addonTable.Core.GetFont()
  end

  addonTable.Utilities.RunInXFrames(3, function()
    if not addonTable.Core.AutoGenerateLayout then return end
    addonTable.Core.AutoGenerateLayout()
    if addonTable.Core.GenerateSpellOverrides then
      addonTable.SpellEquivalence = addonTable.Core.GenerateSpellOverrides()
    end
    ImportExisting()
    if not addonTable.Core.GetCurrentDesign then return end
    local layout = addonTable.Core.GetCurrentDesign()
    if layout then
      if addonTable.Core.ApplyPresets then
        addonTable.Core.ApplyPresets(layout)
      end
      if addonTable.Core.GetCDMMappingAuras then
        addonTable.State.CDM = {auraMap = addonTable.Core.GetCDMMappingAuras()}
      end
      if addonTable.Core.StoreKeyBindings then
        addonTable.State.Bindings = addonTable.Core.StoreKeyBindings()
      end
      addonTable.CallbackRegistry:TriggerEvent("CDMUpdating", false)
      addonTable.CallbackRegistry:TriggerEvent("Layout")
      addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
    end
  end)
end
addonTable.CallbackRegistry:RegisterCallback("RefreshStateChange", function(_, refreshState)
  if refreshState[addonTable.Constants.RefreshReason.Design] then
    TriggerUpdate()
  elseif refreshState[addonTable.Constants.RefreshReason.Reload] then
    addonTable.Dialogs.ShowConfirm(addonTable.Locales.SETTING_CHANGED_THAT_REQUIRES_A_RELOAD, RELOADUI, CANCEL, ReloadUI)
  end
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("UPDATE_MACROS")
frame:RegisterEvent("GROUP_FORMED")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("PVP_MATCH_STATE_CHANGED") -- Cooldowns sometimes reset on this event (PvP Shuffle rounds)
frame:RegisterUnitEvent("UNIT_PET", "player")
frame:RegisterEvent("ITEM_PUSH")
frame:SetScript("OnEvent", function(_, eventName, data1, data2)
  if eventName == "ADDON_LOADED" and data1 == "Coolinator" then
    addonTable.Core.Initialize()
  elseif (eventName == "TRAIT_CONFIG_UPDATED" or eventName == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or eventName == "GROUP_FORMED") and addonTable.State.CDM then
    TriggerUpdate()
  elseif eventName == "SPELL_UPDATE_ICON" and addonTable.State.CDM then
    addonTable.CallbackRegistry:TriggerEvent("Update.SpellIcons", data1)
  elseif eventName == "PLAYER_ENTERING_WORLD" and (not data1 and not data2) and addonTable.State.CDM then
    addonTable.CallbackRegistry:TriggerEvent("Layout")
    addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
  elseif eventName == "PLAYER_EQUIPMENT_CHANGED" and addonTable.State.CDM then
    addonTable.CallbackRegistry:TriggerEvent("Layout")
    addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
  elseif eventName == "PVP_MATCH_STATE_CHANGED" then
    addonTable.CallbackRegistry:TriggerEvent("Layout")
  elseif eventName == "UPDATE_BINDINGS" or eventName == "ACTIONBAR_SLOT_CHANGED" or eventName == "UPDATE_MACROS" or eventName == "UPDATE_SHAPESHIFT_FORM" then
    if addonTable.Core.StoreKeyBindings then
      addonTable.State.Bindings = addonTable.Core.StoreKeyBindings()
    end
    addonTable.CallbackRegistry:TriggerEvent("Update.KeyBindings")
  elseif eventName == "SPELLS_CHANGED" and addonTable.State.CDM then
    local layout = addonTable.Core.GetCurrentDesign and addonTable.Core.GetCurrentDesign()
    addonTable.State.CDM = addonTable.Core.GetCDMOrderAurasOnly and addonTable.Core.GetCDMOrderAurasOnly()
    if layout then
      addonTable.CallbackRegistry:TriggerEvent("Update.SpellsDisplay")
    end
  elseif eventName == "UNIT_PET" and addonTable.State.CDM then
    local layout = addonTable.Core.GetCurrentDesign and addonTable.Core.GetCurrentDesign()
    addonTable.State.CDM = addonTable.Core.GetCDMOrderAurasOnly and addonTable.Core.GetCDMOrderAurasOnly()
    if layout then
      addonTable.CallbackRegistry:TriggerEvent("Layout")
    end
  elseif eventName == "ITEM_PUSH" and addonTable.Constants.PushedItemIcons[data2] then
    frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  elseif eventName == "UNIT_INVENTORY_CHANGED" then
    frame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    addonTable.CallbackRegistry:TriggerEvent("Layout")
    addonTable.CallbackRegistry:TriggerEvent("Designer.Layout")
  end
end)

-- 登录初始化增加安全检查和延迟重试，防止文件加载顺序导致的 nil 调用
local loginRetryCount = 0
local function SafePlayerLoginInit()
  -- 如果关键函数还未就绪，延迟重试（最多10次/5秒）
  if (not addonTable.Core.GetCDMOrderAurasOnly or not addonTable.Core.GetCurrentDesign) and loginRetryCount < 10 then
    loginRetryCount = loginRetryCount + 1
    C_Timer.After(0.5, SafePlayerLoginInit)
    return
  end

  if addonTable.Core.GetFont then
    addonTable.CurrentNumberFont = addonTable.Core.GetFont()
  end
  if addonTable.Core.GetCDMOrderAurasOnly then
    addonTable.State.CDM = addonTable.Core.GetCDMOrderAurasOnly()
  end
  if addonTable.Core.GenerateSpellOverrides then
    addonTable.SpellEquivalence = addonTable.Core.GenerateSpellOverrides()
  end
  if addonTable.Core.AutoGenerateLayout then
    addonTable.Core.AutoGenerateLayout()
  end
  local layout = addonTable.Core.GetCurrentDesign and addonTable.Core.GetCurrentDesign()
  if layout and addonTable.Core.ApplyPresets then
    addonTable.Core.ApplyPresets(layout)
  end

  addonTable.Display.LayoutManager = addonTable.Utilities.InitFrameWithMixin(UIParent, addonTable.Display.LayoutManagerNextMixin)
  addonTable.Designer.LayoutManager = addonTable.Utilities.InitFrameWithMixin(UIParent, addonTable.Designer.LayoutManagerMixin)
end
EventUtil.ContinueOnPlayerLogin(SafePlayerLoginInit)

EventUtil.ContinueAfterAllEvents(function()
  if ImportExisting() then
    local layout = addonTable.Core.GetCurrentDesign and addonTable.Core.GetCurrentDesign()
    if layout and addonTable.Core.ApplyPresets then
      addonTable.Core.ApplyPresets(layout)
    end
  end

  C_CVar.SetCVar("cooldownViewerEnabled", "0")

  addonTable.CallbackRegistry:TriggerEvent("Layout")
end, "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "COOLDOWN_VIEWER_DATA_LOADED", "SPELLS_CHANGED")

function addonTable.Core.GetCurrentDesign()
  local spec = addonTable.Utilities.GetSpecID()
  local assignment = addonTable.Config.Get(addonTable.Config.Options.DESIGN_ASSIGNMENTS)[spec]
  local designs = addonTable.Config.Get(addonTable.Config.Options.DESIGNS)
  if not designs[spec] then
    return
  end
  return designs[spec][assignment or addonTable.Constants.DefaultName]
end