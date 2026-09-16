---@class Data
local Data = select(2, ...)
if not Data.L then
  Data.L = setmetatable({}, {
    __index = function(_, k)
      return k
    end,
  })
  print("|cffff0000BattleGroundEnemiesFixed|r: Locales.lua failed to load. Reinstall the addon.")
end
local L = Data.L
local LSM = LibStub("LibSharedMedia-3.0")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
-- local LibChangelog = LibStub("LibChangelog") -- Removed

--upvalues
local _G = _G
local math_random = math.random
local math_min = math.min
local pairs = pairs
-- local print = print
local time = time
local type = type
local unpack = unpack

local C_PvP = C_PvP
local C_Spell = C_Spell
local CreateFrame = CreateFrame
local CTimerNewTicker = C_Timer.NewTicker
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
-- local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellName
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local SetBattlefieldScoreFaction = SetBattlefieldScoreFaction
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitName = UnitName
local UnitRace = UnitRace

local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local IsWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local HasSpeccs = not not GetSpecialization -- Mists of Pandaria

local MaxLevel = GetMaxPlayerLevel()

-- local LGIST -- Removed LibGroupInSpecT

-- binding definitions
--BINDING_HEADER_BATTLEGROUNDENEMIES = "BattleGroundEnemies"
_G["BINDING_NAME_CLICK BGEAllies:Button4"] = L.TargetPreviousAlly
_G["BINDING_NAME_CLICK BGEAllies:Button5"] = L.TargetNextAlly
_G["BINDING_NAME_CLICK BGEEnemies:Button4"] = L.TargetPreviousEnemy
_G["BINDING_NAME_CLICK BGEEnemies:Button5"] = L.TargetNextEnemy

LSM:Register("statusbar", "UI-StatusBar", "Interface\\TargetingFrame\\UI-StatusBar")

---@class BattleGroundEnemies: frame
BattleGroundEnemies = CreateFrame("Frame", "BattleGroundEnemies", UIParent)

local BattleGroundEnemies = BattleGroundEnemies
BattleGroundEnemies.Counter = {}

function BattleGroundEnemies:CanonicalName(name)
  if not name or type(name) ~= "string" then
    return name
  end
  if issecretvalue and issecretvalue(name) then
    return name
  end
  if name:find("-", 1, true) then
    return name
  end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  if not realm or realm == "" then
    return name
  end
  return name .. "-" .. realm
end

function BattleGroundEnemies:GetCanonicalUnitName(unitID)
  if type(unitID) ~= "string" then
    return nil
  end
  if not UnitExists(unitID) then
    return nil
  end

  -- Compound tokens can return nil from UnitIsPlayer even when UnitName can
  -- resolve their player endpoint, so reject only an explicit non-player.
  if UnitIsPlayer(unitID) == false then
    return nil
  end

  local name, server = UnitName(unitID)
  if issecretvalue and (issecretvalue(name) or issecretvalue(server)) then
    return nil
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  -- Blizzard's own raid UI treats this UnitName placeholder as unresolved,
  -- not as player identity.
  if name == UNKNOWNOBJECT then
    return nil
  end

  if type(server) == "string" and server ~= "" then
    return self:CanonicalName(name .. "-" .. server)
  end
  return self:CanonicalName(name)
end

BattleGroundEnemies._scoreboardFaction = -1
hooksecurefunc("SetBattlefieldScoreFaction", function(factionEnum)
  BattleGroundEnemies._scoreboardFaction = factionEnum
end)

--move unitID update for allies

-- for Clique Support
ClickCastFrames = ClickCastFrames or {}

--[[
Ally frames use Scoreboard, FakePlayers, GroupMembers,
Enemy frames use Scoreboard, FakePlayers, ArenaPlayers
]]

BattleGroundEnemies.consts = {}
BattleGroundEnemies.consts.PlayerSources = {
  Scoreboard = "Scoreboard",
  GroupMembers = "GroupMembers",
  ArenaPlayers = "ArenaPlayers",
  FakePlayers = "FakePlayers",
}
BattleGroundEnemies.consts.PlayerTypes = {
  Allies = "Allies",
  Enemies = "Enemies",
}

-- Battleground max player corrections (GetInstanceInfo returns wrong values for some BGs)
-- Maps instance ID to correct max players per team
local bgMaxPlayerCorrections = {
  -- Classic/Legacy IDs (may still be used in some contexts)
  [443] = 10, -- Warsong Gulch (Classic)
  [461] = 15, -- Arathi Basin (Classic)
  [401] = 40, -- Alterac Valley (Classic)
  [607] = 15, -- Strand of the Ancients

  -- Epic Battlegrounds (40v40)
  [30] = 40, -- Alterac Valley
  [628] = 40, -- Isle of Conquest
  [2118] = 40, -- Battle for Wintergrasp
  [2197] = 40, -- Korrak's Revenge (Brawl)
  [1280] = 40, -- Tarren Mill vs Southshore (Brawl)
  [1191] = 40, -- Ashran

  -- 15v15 Battlegrounds
  [566] = 15, -- Eye of the Storm
  [968] = 15, -- Eye of the Storm (alternate)
  [2107] = 15, -- Arathi Basin
  [2245] = 15, -- Deepwind Gorge
  [1105] = 15, -- Deepwind Gorge (alternate ID)

  -- 10v10 Battlegrounds
  [726] = 10, -- Twin Peaks
  [761] = 10, -- Battle for Gilneas
  [998] = 10, -- Temple of Kotmogu
  [727] = 10, -- Silvershard Mines
  [1803] = 10, -- Seething Shore
  [2656] = 10, -- Deephaul Ravine
  [2106] = 10, -- Warsong Gulch
}

function BattleGroundEnemies:GetCorrectedMaxPlayers()
  if C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() then
    return 8
  end
  if C_PvP and C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground() then
    return 10
  end
  local _, _, _, _, maxPlayers, _, _, instanceID = GetInstanceInfo()
  if instanceID and bgMaxPlayerCorrections[instanceID] then
    return bgMaxPlayerCorrections[instanceID]
  end
  return maxPlayers or 0
end

local previousCvarRaidOptionIsShown

--variables used in multiple functions, if a variable is only used by one function its declared above that function
BattleGroundEnemies.currentTarget = false
BattleGroundEnemies.currentFocus = false

BattleGroundEnemies.Testmode = {
  PlayerCountTestmode = 10,
  FakePlayerAuras = {}, --key = playerbutton, value = {}
  FakePlayerDRs = {}, --key = playerButtonTable, value = {categoryname = {state = 0, expirationTime}
  RandomTrinkets = false, -- key = number, value = spellId-- key = number, value = spellId
}

BattleGroundEnemies.ButtonModules = {} --contains moduleFrames, key is the module name
BattleGroundEnemies.UserFaction = UnitFactionGroup("player")
BattleGroundEnemies.UserButton = false --the button of the Player himself
BattleGroundEnemies.scoreboardSpecByName = {}

BattleGroundEnemies.states = {
  testmodeActive = false,
  testmodeAnimationEnabled = true,
  userIsAlive = not UnitIsDeadOrGhost("player"),
  ---@type bgeState
  real = {
    WOW_PROJECT_ID = WOW_PROJECT_ID,
    isInArena = false,
    isInBattleground = false,
    currentMapId = false,
    isRatedBG = false,
    isSoloRBG = false,
  },
  ---@type bgeState
  test = {
    WOW_PROJECT_ID = WOW_PROJECT_ID,
    isInArena = false,
    isInBattleground = false,
    currentMapId = false,
    isRatedBG = false,
    isSoloRBG = false,
  },
}

---@return bgeState
function BattleGroundEnemies:GetActiveStates()
  if self:IsTestmodeActive() then
    return self.states.test
  else
    return self.states.real
  end
end

function BattleGroundEnemies:GetBattlegroundAuras()
  local states = self:GetActiveStates()
  if not states then
    return
  end

  return Data.BattlegroundspezificBuffs and Data.BattlegroundspezificBuffs[states.currentMapId]
end

function BattleGroundEnemies:IsTestmodeActive()
  return self.states.testmodeActive
end

function BattleGroundEnemies:FlipButtonModuleSettingsHorizontally(moduleName, dbLocation)
  local newSettings = {}

  local moduleFrame = self.ButtonModules[moduleName]
  if not moduleFrame or moduleFrame.attachSettingsToButton then
    newSettings = CopyTable(dbLocation, false)
  else
    for k, v in pairs(dbLocation) do
      if type(v) == "table" then
        if k == "Points" then
          local newPointsData = CopyTable(v, false)
          for i = 1, #v do
            local pointsData = v[i]
            if pointsData.Point then
              newPointsData[i].Point = Data.Helpers.getOppositeHorizontalPoint(pointsData.Point) or pointsData.Point
            end
            if pointsData.RelativePoint then
              newPointsData[i].RelativePoint = Data.Helpers.getOppositeHorizontalPoint(pointsData.RelativePoint)
                or pointsData.RelativePoint
            end
            if pointsData.OffsetX then
              newPointsData[i].OffsetX = -pointsData.OffsetX
            end
          end
          newSettings[k] = newPointsData
        elseif k == "Container" then
          local newContainerSettings = CopyTable(v, false)
          local newHorizontalGrowDirection

          local horizontalGrowdirection = v.HorizontalGrowDirection
          if horizontalGrowdirection then
            newHorizontalGrowDirection = Data.Helpers.getOppositeDirection(horizontalGrowdirection)
              or horizontalGrowdirection
          end
          newContainerSettings.HorizontalGrowDirection = newHorizontalGrowDirection
          newSettings[k] = newContainerSettings
        else
          newSettings[k] = self:FlipButtonModuleSettingsHorizontally(moduleName, v)
        end
      else
        newSettings[k] = v
      end
    end
  end

  return newSettings
end

function BattleGroundEnemies:FlipSettingsHorizontallyRecursive(dblocation)
  local dbLocationFlippedHorizontally = {}
  for k, v in pairs(dblocation) do
    if type(v) == "table" then
      if k == "ButtonModules" then
        dbLocationFlippedHorizontally[k] = {}
        for moduleName, moduleSettings in pairs(v) do
          dbLocationFlippedHorizontally[k][moduleName] =
            self:FlipButtonModuleSettingsHorizontally(moduleName, moduleSettings)
        end
      else
        dbLocationFlippedHorizontally[k] = self:FlipSettingsHorizontallyRecursive(v)
      end
    else
      dbLocationFlippedHorizontally[k] = v
    end
  end
  return dbLocationFlippedHorizontally
end

function BattleGroundEnemies:GetPlayerCountsFromConfig(playerCountConfig)
  if type(playerCountConfig) ~= "table" then
    error("playerCountConfig must be a table")
  end
  local minPlayers = playerCountConfig.minPlayerCount
  local maxPlayers = playerCountConfig.maxPlayerCount
  return minPlayers, maxPlayers
end

function BattleGroundEnemies:GetPlayerCountConfigNameLocalized(playerCountConfig, isCustom)
  local minPlayers, maxPlayers = self:GetPlayerCountsFromConfig(playerCountConfig)
  return (isCustom and "*" or "") .. minPlayers .. "–" .. maxPlayers .. " " .. L.players
end

function BattleGroundEnemies:GetPlayerCountConfigName(playerCountConfig)
  local minPlayers, maxPlayers = self:GetPlayerCountsFromConfig(playerCountConfig)
  return minPlayers .. "–" .. maxPlayers .. " " .. "players"
end

-- returns true if <frame> or one of the frames that <frame> is dependent on is anchored to <otherFrame> and nil otherwise
-- dont ancher to otherframe is
function BattleGroundEnemies:IsFrameDependentOnFrame(frame, otherFrame)
  if frame == nil then
    return false
  end

  if otherFrame == nil then
    return false
  end

  if frame == otherFrame then
    return true
  end

  local points = frame:GetNumPoints()
  for i = 1, points do
    local _, relFrame = frame:GetPoint(i)
    if relFrame and self:IsFrameDependentOnFrame(relFrame, otherFrame) then
      return true
    end
  end
end

function BattleGroundEnemies:IsModuleEnabledOnThisExpansion(moduleName)
  local moduleFrame = self.ButtonModules[moduleName]
  if moduleFrame then
    return moduleFrame.enabledInThisExpansion
  end
  return false
end

local function copySettingsWithoutOverwrite(src, dest)
  if not src or type(src) ~= "table" then
    return
  end
  if type(dest) ~= "table" then
    dest = {}
  end

  for k, v in pairs(src) do
    if type(v) == "table" then
      dest[k] = copySettingsWithoutOverwrite(v, dest[k])
    elseif type(v) ~= type(dest[k]) then -- only overwrite if the type in dest is different
      dest[k] = v
    end
  end

  return dest
end

local function copyModuleDefaultsIntoDefaults(location, moduleName, moduleDefaults)
  location.ButtonModules = location.ButtonModules or {}
  location.ButtonModules[moduleName] = location.ButtonModules[moduleName] or {}
  copySettingsWithoutOverwrite(moduleDefaults, location.ButtonModules[moduleName])
end

function BattleGroundEnemies:NewButtonModule(moduleSetupTable)
  if type(moduleSetupTable) ~= "table" then
    return error("Tried to register a Module but the parameter wasn't a table")
  end
  if not moduleSetupTable.moduleName then
    return error("NewButtonModule error: No moduleName specified")
  end
  local moduleName = moduleSetupTable.moduleName
  if not moduleSetupTable.localizedModuleName then
    return error("NewButtonModule error for module: " .. moduleName .. " No localizedModuleName specified")
  end
  if moduleSetupTable.enabledInThisExpansion == nil then
    return error("NewButtonModule error for module: " .. moduleName .. " enabledInThisExpansion is nil")
  end

  if self.ButtonModules[moduleName] then
    return error("module " .. moduleName .. " is already registered")
  end
  local moduleFrame = CreateFrame("Frame", nil, UIParent)

  moduleSetupTable.flags = moduleSetupTable.flags or {}
  Mixin(moduleFrame, moduleSetupTable)

  for k in pairs(self.consts.PlayerTypes) do
    for j = 1, #Data.defaultSettings.profile[k].playerCountConfigs do
      local playerCountConfig = Data.defaultSettings.profile[k].playerCountConfigs[j]
      copyModuleDefaultsIntoDefaults(playerCountConfig, moduleName, moduleSetupTable.defaultSettings)
    end

    local customPlayerCountConfigGeneric = Data.defaultSettings.profile[k].customPlayerCountConfigs["**"]
    copyModuleDefaultsIntoDefaults(customPlayerCountConfigGeneric, moduleName, moduleSetupTable.defaultSettings)
  end

  if moduleSetupTable.generalDefaults then
    copyModuleDefaultsIntoDefaults(Data.defaultSettings.profile, moduleName, moduleSetupTable.generalDefaults)
  end

  self.ButtonModules[moduleName] = moduleFrame
  return moduleFrame
end

function BattleGroundEnemies:GetBigDebuffsSpellPriority(spellId)
  if not BattleGroundEnemies.db.profile.UseBigDebuffsPriority then
    return
  end
  if not BigDebuffs then
    return
  end
  local priority = BigDebuffs.GetDebuffPriority and BigDebuffs:GetDebuffPriority(spellId)
  if not priority then
    return
  end
  if priority == 0 then
    return
  end
  return priority
end

function BattleGroundEnemies:GetSpellPriority(spellId)
  local priority = nil
  pcall(function()
    priority = self:GetBigDebuffsSpellPriority(spellId) or Data.SpellPriorities[spellId]
  end)
  return priority
end

function BattleGroundEnemies:IsInPvPInstance()
  local _, zone = IsInInstance()
  return zone == "pvp" or zone == "arena"
end

BattleGroundEnemies:SetScript("OnEvent", function(self, event, ...)
  if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" then
    if not self:IsInPvPInstance() then
      return
    end
  end
  if self[event] then
    self[event](self, ...)
  end
end)

function BattleGroundEnemies:GetColoredName(playerButton)
  if not playerButton.PlayerDetails then
    return
  end
  local name = playerButton.PlayerDetails.PlayerName
  local tbl = playerButton.PlayerDetails.PlayerClassColor
  return ("|cFF%02x%02x%02x%s|r"):format(tbl.r * 255, tbl.g * 255, tbl.b * 255, name)
end

BattleGroundEnemies.FakePlayersUpdateTicker = nil

local function stopFakePlayersTicker()
  if BattleGroundEnemies.FakePlayersUpdateTicker then
    BattleGroundEnemies.FakePlayersUpdateTicker:Cancel()
    BattleGroundEnemies.FakePlayersUpdateTicker = nil
  end
end

local function createFakePlayersTicker(seconds, callback)
  local ticker = CTimerNewTicker(seconds, callback)
  stopFakePlayersTicker()
  BattleGroundEnemies.FakePlayersUpdateTicker = ticker
  return ticker
end

function BattleGroundEnemies:SetupTestmode()
  if not self.Testmode.RandomTrinkets then
    self.Testmode.RandomTrinkets = {}
    for triggerSpellID, trinketData in pairs(Data.TrinketData) do
      if type(triggerSpellID) == "string" then --support for classic, IsClassic
        table.insert(self.Testmode.RandomTrinkets, triggerSpellID)
      else
        local spellExists = GetSpellName(triggerSpellID)

        if spellExists and spellExists ~= "" then
          table.insert(self.Testmode.RandomTrinkets, triggerSpellID)
        end
      end
    end
  end

  wipe(self.Testmode.FakePlayerAuras)
  wipe(self.Testmode.FakePlayerDRs)

  local mapIDs = {}
  if Data.BattlegroundspezificBuffs then
    for mapID, data in pairs(Data.BattlegroundspezificBuffs) do
      table.insert(mapIDs, mapID)
    end
  end
  local mandomm = math_random(1, #mapIDs)
  local randomMapID = mapIDs[mandomm]

  BattleGroundEnemies.states.test.currentMapId = randomMapID
  BattleGroundEnemies.states.test.isInBattleground = true
  BattleGroundEnemies.states.test.isRatedBG = true

  self:CreateFakePlayers()
  self:CheckEnableState()
end

do
  local counter

  function BattleGroundEnemies:FillFakePlayerData(amount, mainFrame, role)
    for i = 1, amount do
      local name, classToken, specName

      if HasSpeccs then
        local randomSpec
        randomSpec = Data.RolesToSpec[role][math_random(1, #Data.RolesToSpec[role])]
        classToken = randomSpec.classToken
        specName = randomSpec.specName
      else
        classToken = Data.ClassList[math_random(1, #Data.ClassList)]
      end
      local nameprefix = mainFrame.PlayerType == self.consts.PlayerTypes.Enemies and "Enemy" or "Ally"
      name = L[nameprefix] .. counter .. "-Realm" .. counter

      mainFrame:AddPlayerToSource(self.consts.PlayerSources.FakePlayers, {
        name = name,
        raceName = nil,
        classToken = classToken,
        specName = specName,
        additionalData = {
          isFakePlayer = true,
          PlayerLevel = i == 1 and MaxLevel or math_random(MaxLevel - 10, MaxLevel - 1),
        },
      })
      counter = counter + 1
    end
  end

  function BattleGroundEnemies:CreateFakePlayers()
    local count = self.Testmode.PlayerCountTestmode or 10

    for number, mainFrame in pairs({ self.Allies, self.Enemies }) do
      local remaining = count
      if
        mainFrame == self.Allies
        and type(BattleGroundEnemies.UserButton) == "table"
        and BattleGroundEnemies.UserButton.PlayerDetails
      then

        remaining = remaining - 1
      end
      mainFrame:BeforePlayerSourceUpdate(self.consts.PlayerSources.FakePlayers)

      local healerAmount = math_random(2, 3)
      healerAmount = math_min(healerAmount, remaining)
      remaining = remaining - healerAmount
      local tankAmount = math_random(1)
      tankAmount = math_min(tankAmount, remaining)
      remaining = remaining - tankAmount
      local damagerAmount = remaining

      counter = 1
      BattleGroundEnemies:FillFakePlayerData(healerAmount, mainFrame, "HEALER")
      BattleGroundEnemies:FillFakePlayerData(tankAmount, mainFrame, "TANK")
      BattleGroundEnemies:FillFakePlayerData(damagerAmount, mainFrame, "DAMAGER")

      mainFrame:AfterPlayerSourceUpdate()

      for name, playerButton in pairs(mainFrame.Players) do
        -- if IsRetail then
        -- 	playerButton.Covenant:UpdateCovenant(math_random(1, #Data.CovenantIcons))
        -- end
      end
    end
  end
end

local function fakePlayersTestmodeTicker()
  for number, mainFrame in pairs({ BattleGroundEnemies.Allies, BattleGroundEnemies.Enemies }) do
    mainFrame:OnTestmodeTick()
  end
end

local function setupFakePlayersTestmodeTicker()
  createFakePlayersTicker(1, fakePlayersTestmodeTicker)
end

function BattleGroundEnemies.ToggleTestmodeOnUpdate()
  -- Track the intent in a persistent flag rather than inferring it from the
  -- ticker's existence. Otherwise any settings change (-> ApplyAllSettings ->
  -- Enable) would recreate the ticker and resurrect an animation the user had
  -- just paused.
  local enabled = not BattleGroundEnemies.states.testmodeAnimationEnabled
  BattleGroundEnemies.states.testmodeAnimationEnabled = enabled
  if enabled then
    setupFakePlayersTestmodeTicker()
    -- Resume the swipe timers so they animate alongside the fake events again.
    BattleGroundEnemies:ResumeAllCooldowns()
    BattleGroundEnemies:Information(L.FakeEventsEnabled)
  else
    stopFakePlayersTicker()
    -- Freeze the swipe timers too — they run on WoW's clock, not the ticker,
    -- so without this they keep counting down after the animation is paused.
    BattleGroundEnemies:PauseAllCooldowns()
    BattleGroundEnemies:Information(L.FakeEventsDisabled)
  end
end

function BattleGroundEnemies:EnableTestMode()
  if InCombatLockdown() then
    return BattleGroundEnemies:Information(L.ErrorTestmodeInCombat)
  end
  self.states.testmodeActive = true
  self.states.testmodeAnimationEnabled = true
  self:ResumeAllCooldowns()
  self.Allies._warnedNoCustomProfile = nil
  self.Enemies._warnedNoCustomProfile = nil
  self:SetupTestmode()

  self:ApplyAllSettings()

  self.Allies:OnTestmodeEnabled()
  self.Enemies:OnTestmodeEnabled()
  self:Information(L.TestmodeEnabled)
end

function BattleGroundEnemies:DisableTestMode()
  self.states.testmodeActive = false
  self:Information(L.TestmodeDisabled)
  self.Allies:OnTestmodeDisabled()
  self.Enemies:OnTestmodeDisabled()
  self:CheckEnableState()
end

function BattleGroundEnemies.ToggleTestmode()
  if BattleGroundEnemies.states.testmodeActive then --disable testmode
    BattleGroundEnemies:DisableTestMode()
  else --enable Testmode
    BattleGroundEnemies:EnableTestMode()
  end
end

local RequestFrame = CreateFrame("Frame", nil, BattleGroundEnemies)
RequestFrame:Hide()
do
  local TimeSinceLastOnUpdate = 0
  local UpdatePeroid = 2 --update every second
  local function RequestTicker(self, elapsed) --OnUpdate runs if the frame RequestFrame is shown
    TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
    if TimeSinceLastOnUpdate > UpdatePeroid then
      RequestBattlefieldScoreData()
      TimeSinceLastOnUpdate = 0
    end
  end
  RequestFrame:SetScript("OnUpdate", RequestTicker)
end

BattleGroundEnemies.ArenaIDToPlayerButton = {} --key = arenaID: arenaX, value = playerButton of that unitID

BattleGroundEnemies:RegisterEvent("PLAYER_LOGIN") --Fired on reload UI and on initial loading screen

BattleGroundEnemies.GeneralEvents = {
  "UNIT_HEALTH_FREQUENT",
  "UPDATE_MOUSEOVER_UNIT",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_FOCUS_CHANGED",
  "ARENA_OPPONENT_UPDATE", --fires when a arena enemy appears and a frame is ready to be shown
  "ARENA_CROWD_CONTROL_SPELL_UPDATE", --fires when data requested by C_PvP.RequestCrowdControlSpell(unitID) is available
  "ARENA_COOLDOWNS_UPDATE", --fires when a arenaX enemy used a trinket or racial to break cc, C_PvP.GetArenaCrowdControlInfo(unitID) shoudl be called afterwards to get used CCs
  "UNIT_TARGET",
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_POWER_FREQUENT",
  "UNIT_POWER_UPDATE",
  "UNIT_MAXPOWER",
  "PLAYER_SOFT_ENEMY_CHANGED",
  "PVP_MATCH_STATE_CHANGED",
  "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED",
  "RAID_TARGET_UPDATE",
}

BattleGroundEnemies.RetailEvents = {
  "UNIT_HEAL_PREDICTION",
  "UNIT_ABSORB_AMOUNT_CHANGED",
  "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
}

BattleGroundEnemies.ClassicEvents = {
  "UNIT_HEALTH_FREQUENT",
}

BattleGroundEnemies.WrathEvents = {
  "UNIT_HEALTH_FREQUENT",
}

function BattleGroundEnemies:RegisterEvents()
  local allEvents = Data.Helpers.JoinArrays(self.GeneralEvents, self.ClassicEvents, self.WrathEvents, self.RetailEvents)
  if C_EventUtils and C_EventUtils.IsEventValid then
    for i = 1, #allEvents do
      local event = allEvents[i]
      if C_EventUtils.IsEventValid(event) then
        pcall(function()
          self:RegisterEvent(event)
        end)
      end
    end
  else
    for i = 1, #self.GeneralEvents do
      pcall(function()
        self:RegisterEvent(self.GeneralEvents[i])
      end)
    end
    if IsClassic then
      for i = 1, #self.ClassicEvents do
        pcall(function()
          self:RegisterEvent(self.ClassicEvents[i])
        end)
      end
    end
    if IsWrath then
      for i = 1, #self.WrathEvents do
        pcall(function()
          self:RegisterEvent(self.WrathEvents[i])
        end)
      end
    end
    if IsRetail then
      for i = 1, #self.RetailEvents do
        pcall(function()
          self:RegisterEvent(self.RetailEvents[i])
        end)
      end
    end
  end
end

function BattleGroundEnemies:UnregisterEvents()
  local allEvents = Data.Helpers.JoinArrays(self.GeneralEvents, self.ClassicEvents, self.WrathEvents, self.RetailEvents)
  for i = 1, #allEvents do
    if self:IsEventRegistered(allEvents[i]) then
      self:UnregisterEvent(allEvents[i])
    end
  end
end

-- if lets say raid1 leaves all remaining players get shifted up, so raid2 is the new raid1, raid 3 gets raid2 etc.

function BattleGroundEnemies.CropImage(texture, width, height, hasTexcoords)
  local left, right, top, bottom = 0.075, 0.925, 0.075, 0.925
  local ratio = height / width
  if ratio > 1 then --crop the sides
    ratio = 1 / ratio
    texture:SetTexCoord(left + ((1 - ratio) / 2), right - ((1 - ratio) / 2), top, bottom)
  elseif ratio == 1 then
    texture:SetTexCoord(left, right, top, bottom)
  else
    -- crop the height
    texture:SetTexCoord(left, right, top + ((1 - ratio) / 2), bottom - ((1 - ratio) / 2))
  end
end

-- CreateFont needs a unique global name; hand them out from a counter.
local bgeNextFontID = 1

local function ApplyFontStringSettings(fs, settings, isCooldown)
  local globals = Mixin({}, BattleGroundEnemies.db.profile.Text)
  if isCooldown then
    globals = Mixin({}, globals, BattleGroundEnemies.db.profile.Cooldown)
  end

  local configTable = Mixin({}, globals, settings)

  if not fs.bgeFont then
    fs.bgeFont = CreateFont("BGEFont" .. bgeNextFontID)
    bgeNextFontID = bgeNextFontID + 1
  end
  local fontObj = fs.bgeFont

  fontObj:SetFont(LSM:Fetch("font", configTable.Font), configTable.FontSize, configTable.FontOutline)

  if configTable.ShadowColor then
    fontObj:SetShadowColor(unpack(configTable.ShadowColor))
  end
  if configTable.EnableShadow then
    -- Historical (1, -1) fallback for profiles saved before these keys existed.
    fontObj:SetShadowOffset(configTable.ShadowOffsetX or 1, configTable.ShadowOffsetY or -1)
  else
    fontObj:SetShadowOffset(0, 0)
  end

  -- SetFontObject resets justify/wordwrap/text color to the object's defaults,
  -- so every per-fontstring override below MUST be applied AFTER this call.
  fs:SetFontObject(fontObj)

  --idk why, but without this the SetJustifyH and SetJustifyV dont seem to work sometimes even tho GetJustifyH returns the new, correct value
  fs:GetRect()
  fs:GetStringHeight()
  fs:GetStringWidth()

  if configTable.JustifyH then
    fs:SetJustifyH(configTable.JustifyH)
  end

  if configTable.JustifyV then
    fs:SetJustifyV(configTable.JustifyV)
  end

  if configTable.WordWrap ~= nil then
    fs:SetWordWrap(configTable.WordWrap)
  end

  if configTable.FontColor then
    fs:SetTextColor(unpack(configTable.FontColor))
  end
end

local function ApplyCooldownSettings(self, config, cdReverse, swipeColor)
  -- Manual merge instead of Mixin() to avoid Lua taint
  local configTable = {}
  for k, v in pairs(BattleGroundEnemies.db.profile.Cooldown) do
    configTable[k] = v
  end
  for k, v in pairs(config) do
    configTable[k] = v
  end
  self:SetReverse(cdReverse)
  self:SetDrawSwipe(configTable.DrawSwipe)
  self:SetDrawEdge(configTable.DrawSwipe)
  if swipeColor then
    self:SetSwipeColor(unpack(swipeColor))
  end
  self:SetHideCountdownNumbers(not configTable.ShowNumber)
  if self.Text then
    self.Text:ApplyFontStringSettings(config, true)
  end
end

---comment
---@param parent Frame
function BattleGroundEnemies.MyCreateFontString(parent)
  ---@class MyFontString: fontstring
  ---@field DisplayedName string
  local fontString = parent:CreateFontString(nil, "OVERLAY")
  fontString.ApplyFontStringSettings = ApplyFontStringSettings
  fontString:SetDrawLayer("OVERLAY", 2)
  return fontString
end

---comment
---@param frame cooldown
---@return fontstring?
function BattleGroundEnemies.GrabFontString(frame)
  for _, region in pairs({ frame:GetRegions() }) do
    if region:GetObjectType() == "FontString" then
      return region
    end
  end
end

function BattleGroundEnemies.AttachCooldownSettings(cooldown)
  cooldown.ApplyCooldownSettings = ApplyCooldownSettings
  -- Find fontstring of the cooldown
  local fontstring = BattleGroundEnemies.GrabFontString(cooldown)
  if fontstring then
    ---@class MyFontString
    cooldown.Text = fontstring
    cooldown.Text.ApplyFontStringSettings = ApplyFontStringSettings
  end
end

BattleGroundEnemies.AllCooldowns = BattleGroundEnemies.AllCooldowns or {}

function BattleGroundEnemies.MyCreateCooldown(parent)
  local cooldown = CreateFrame("Cooldown", nil, parent)
  cooldown:SetAllPoints()
  cooldown:SetSwipeTexture("Interface/Buttons/WHITE8X8")

  BattleGroundEnemies.AttachCooldownSettings(cooldown)

  BattleGroundEnemies.AllCooldowns[#BattleGroundEnemies.AllCooldowns + 1] = cooldown

  return cooldown
end

-- Pause/Resume every cooldown swipe. Only ever called from the test-mode
-- animation toggle (and EnableTestMode), so it never touches real-match cooldowns.
function BattleGroundEnemies:PauseAllCooldowns()
  local cds = self.AllCooldowns
  for i = 1, #cds do
    local cd = cds[i]
    if cd and not cd:IsPaused() then
      cd:Pause()
    end
  end
end

function BattleGroundEnemies:ResumeAllCooldowns()
  local cds = self.AllCooldowns
  for i = 1, #cds do
    local cd = cds[i]
    if cd and cd:IsPaused() then
      cd:Resume()
    end
  end
end

local buttonUpdateTicker = nil
local BUTTON_UPDATE_PERIOD = 0.3

local function UpdateAllPlayerButtons()
  if not BattleGroundEnemies.enabled or not BattleGroundEnemies.states.userIsAlive then
    return
  end
  local containers = { BattleGroundEnemies.Enemies, BattleGroundEnemies.Allies }
  for c = 1, #containers do
    local container = containers[c]
    if container and container.enabled and container.Players then
      for _, playerButton in pairs(container.Players) do
        if not playerButton.PlayerDetails.isFakePlayer then
          if playerButton.PlayerIsEnemy then
            playerButton:UpdateAll()
          else
            if playerButton ~= BattleGroundEnemies.UserButton then
              playerButton:UpdateRangeViaLibRangeCheck(playerButton.unitID)
            else
              playerButton:UpdateRange(true)
            end
          end
        end
      end
    end
  end
end

local function StartButtonUpdateTicker()
  if buttonUpdateTicker then
    buttonUpdateTicker:Cancel()
  end
  buttonUpdateTicker = CTimerNewTicker(BUTTON_UPDATE_PERIOD, UpdateAllPlayerButtons)
end

local function StopButtonUpdateTicker()
  if buttonUpdateTicker then
    buttonUpdateTicker:Cancel()
    buttonUpdateTicker = nil
  end
end

function BattleGroundEnemies:Disable()
  self.enabled = false
  self:UnregisterEvents()
  RequestFrame:Hide()
  stopFakePlayersTicker()
  StopButtonUpdateTicker()
  self:StopTargetScanTicker()
  self:StopCombatIndicatorTicker()
  if self.allyRosterRetryTimer then
    self.allyRosterRetryTimer:Cancel()
    self.allyRosterRetryTimer = nil
  end
  self.Allies:Disable()
  self.Enemies:Disable()

  self.Allies:RemoveAllPlayersFromAllSources()
  self.Enemies:RemoveAllPlayersFromAllSources()
end

function BattleGroundEnemies:Enable()
  self.enabled = true

  self._harvestedThisMatch = nil
  wipe(self.scoreboardSpecByName)
  self._allySpecCount = nil

  self:RegisterEvents()
  StartButtonUpdateTicker()
  self:StartTargetScanTicker()
  self:StartCombatIndicatorTicker()
  if BattleGroundEnemies:IsTestmodeActive() then
    if BattleGroundEnemies.states.testmodeAnimationEnabled then
      setupFakePlayersTestmodeTicker()
    end
    RequestFrame:Hide()
  else
    RequestFrame:Show()
    stopFakePlayersTicker()
  end
  self.Allies:CheckEnableState()
  self.Enemies:CheckEnableState()

  self:GROUP_ROSTER_UPDATE()
end

function BattleGroundEnemies:CheckEnableState()
  local states = BattleGroundEnemies:GetActiveStates()
  if states.isInArena and BattleGroundEnemies.db.profile.ShowBGEInArena then
    return self:Enable()
  end
  if states.isInBattleground and BattleGroundEnemies.db.profile.ShowBGEInBattleground then
    return self:Enable()
  end
  self:Disable()
end

function BattleGroundEnemies:ApplyAllSettings()
  BattleGroundEnemies:CheckEnableState()
  if BattleGroundEnemies.Allies then
    BattleGroundEnemies.Allies:SelectPlayerCountProfile(true)
  end
  if BattleGroundEnemies.Enemies then
    BattleGroundEnemies.Enemies:SelectPlayerCountProfile(true)
  end
  BattleGroundEnemies:ToggleArenaFrames()
  BattleGroundEnemies:ToggleRaidFrames()
end

local function PVPMatchScoreboard_OnHide()
  if PVPMatchScoreboard.selectedTab ~= 1 then
    -- user was looking at another tab than all players
    SetBattlefieldScoreFaction() -- request a UPDATE_BATTLEFIELD_SCORE
  end
end

--Triggered immediately before PLAYER_ENTERING_WORLD on login and UI Reload, but NOT when entering/leaving instances.
function BattleGroundEnemies:PLAYER_LOGIN()
  self.UserDetails = {
    PlayerName = self:CanonicalName(UnitName("player")),
    PlayerClass = select(2, UnitClass("player")),
    isGroupLeader = UnitIsGroupLeader("player"),
    isGroupAssistant = UnitIsGroupAssistant("player"),
    unit = "player",
    GUID = UnitGUID("player"),
  }

  self.db = LibStub("AceDB-3.0"):New("BattleGroundEnemiesDB", Data.defaultSettings, true)

  self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
  self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
  self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")
  if self.db.global and self.db.global.PlayerHistory then
    local cutoff = time() - (180 * 86400)
    for k, v in pairs(self.db.global.PlayerHistory) do
      if type(v) ~= "table" or not v.lastSeenAt or v.lastSeenAt < cutoff then
        self.db.global.PlayerHistory[k] = nil
      end
    end
  end

  if self.db.profile then
    if self.db.profile.DebugToSV_ResetOnPlayerLogin then
      self.db.profile.log = nil
    end
  end

  BattleGroundEnemies:UpgradeProfiles(self.db)

  BattleGroundEnemies:UpgradeProfiles(self.db)

  if self.ApplyAllSettings then
    self:ApplyAllSettings()
  end

  -- self:RegisterEvent("GROUP_ROSTER_UPDATE") ... (Keeping event registration flow intact)

  self:RegisterEvent("GROUP_ROSTER_UPDATE") --Fired whenever a group or raid is formed or disbanded, players are leaving or joining the group or raid.
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PARTY_LEADER_CHANGED") --Fired when the player's leadership changed.
  self:RegisterEvent("PLAYER_ALIVE") --Fired when the player releases from death to a graveyard; or accepts a resurrect before releasing their spirit. Does not fire when the player is alive after being a ghost. PLAYER_UNGHOST is triggered in that case.
  self:RegisterEvent("PLAYER_UNGHOST") --Fired when the player is alive after being a ghost.
  self:RegisterEvent("PLAYER_DEAD") --Fired when the player has died.
  self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  -- self:RegisterEvent("PVP_MATCH_STATE_CHANGED")

  self:SetupOptions()

  AceConfigDialog:SetDefaultSize("BattleGroundEnemiesFixed", 800, 700)

  AceConfigDialog:AddToBlizOptions("BattleGroundEnemiesFixed", "BattleGroundEnemiesFixed")

  if PVPMatchScoreboard then -- for TBCC, IsTBCC
    PVPMatchScoreboard:HookScript("OnHide", PVPMatchScoreboard_OnHide)
  end

  --DBObjectLib:ResetProfile(noChildren, noCallbacks)

  self:GROUP_ROSTER_UPDATE() --Scan again, the user could have reloaded the UI so GROUP_ROSTER_UPDATE didnt fire

  -- Register permanently so the combat lockdown queue always drains,
  -- even after UnregisterEvents() runs during Disable().
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")

  -- Secure-action block diagnostics (logged only under /bge debug). Cheap —
  -- these fire only when a protected action is actually denied.
  self:RegisterEvent("ADDON_ACTION_BLOCKED")
  self:RegisterEvent("ADDON_ACTION_FORBIDDEN")

  self:UnregisterEvent("PLAYER_LOGIN")
end

function BattleGroundEnemies:NotifyChange()
  AceConfigRegistry:NotifyChange("BattleGroundEnemiesFixed")
  self:ProfileChanged()
end

function BattleGroundEnemies:ProfileChanged()
  self:UpgradeProfile(self.db.profile, self.db:GetCurrentProfile())
  self:SetupOptions()
  self:ApplyAllSettings()
end

function BattleGroundEnemies:ProfileReset()
  self:SetCurrentDbVerion(self.db.profile)
  BattleGroundEnemies:NotifyChange()
end

local timer = nil
function BattleGroundEnemies:ApplyAllSettingsDebounce()
  if timer then
    timer:Cancel()
  end -- use a timer to apply changes after 0.2 second, this prevents the UI from getting laggy when the user uses a slider option
  timer = CTimerNewTicker(0.2, function()
    BattleGroundEnemies:ApplyAllSettings()
    timer = nil
  end, 1)
end

local playerCountChangedTimer = nil
function BattleGroundEnemies:TestModePlayerCountChanged(value)
  if playerCountChangedTimer then
    playerCountChangedTimer:Cancel()
  end -- use a timer to apply changes after 0.2 second, this prevents the UI from getting laggy when the user uses a slider option
  self.Testmode.PlayerCountTestmode = value
  playerCountChangedTimer = CTimerNewTicker(0.2, function()
    if self:IsTestmodeActive() then
      self:CreateFakePlayers()
      self.Allies:SelectPlayerCountProfile(true)
      self.Enemies:SelectPlayerCountProfile(true)
    end
    playerCountChangedTimer = nil
  end, 1)
end

local sentDebugMessages = {}
function BattleGroundEnemies:OnetimeDebug(...)
  local message = table.concat({ ... }, ", ")
  if sentDebugMessages[message] then
    return
  end
  sentDebugMessages[message] = true
end

-- function BattleGroundEnemies:EnableDebugging()
--   self.db.profile.Debug = true
--   self:NotifyChange()
-- end

local sentMessages = {}
function BattleGroundEnemies:OnetimeInformation(...)
  local message = table.concat({ ... }, ", ")
  if sentMessages[message] then
    return
  end
  print("|cff0099ffBattleGroundEnemies:|r", message)
  sentMessages[message] = true
end

function BattleGroundEnemies:Information(...)
  print("|cff0099ffBattleGroundEnemies:|r", ...)
end

--fires when a arena enemy appears and a frame is ready to be shown
function BattleGroundEnemies:ARENA_OPPONENT_UPDATE(unitID, unitEvent)
  --unitEvent can be: "seen", "unseen", "destroyed", "cleared"
  if unitEvent == "cleared" then --"unseen", "cleared" or "destroyed"
    local playerButton = self.ArenaIDToPlayerButton[unitID]
    if playerButton then
      self.ArenaIDToPlayerButton[unitID] = nil
      playerButton:UpdateEnemyUnitID("Arena", false)
      playerButton:DispatchEvent("ArenaOpponentHidden")
    end
  end
  self:CheckForArenaEnemies()
end

local function IsEnemyUnit(unitID)
  local _, instanceType = IsInInstance()
  if instanceType == "pvp" then
    return not UnitIsFriend("player", unitID)
  end
  return true
end
-- Expose for Mainframe.lua
BattleGroundEnemies.IsEnemyUnit = IsEnemyUnit

function BattleGroundEnemies:GetPlayerbuttonByUnitID(unitID, playerType, ignoreExistingArena)
  if type(unitID) ~= "string" or not UnitExists(unitID) then
    return nil
  end
  if playerType == "Allies" or UnitIsPlayer(unitID) == false then
    return nil
  end
  if not IsEnemyUnit(unitID) then
    return nil
  end

  local playerName = self:GetCanonicalUnitName(unitID)
  if not playerName then
    return nil
  end
  if self.Allies and self.Allies.Players and self.Allies.Players[playerName] then
    return nil
  end
  return self.Enemies and self.Enemies.Players and self.Enemies.Players[playerName] or nil
end

-- Pre-built unit ID tables to avoid string concatenation every scan cycle
local arenaUnits = {}
for i = 1, 5 do
  arenaUnits[i] = "arena" .. i
end

local nameplateUnits = {}
for i = 1, 40 do
  nameplateUnits[i] = "nameplate" .. i
end

local nameplateTargetUnits = {}
for i = 1, 40 do
  nameplateTargetUnits[i] = "nameplate" .. i .. "target"
end

local raidTargetUnits = {}
for i = 1, 40 do
  raidTargetUnits[i] = "raid" .. i .. "target"
end

local partyTargetUnits = {}
for i = 1, 5 do
  partyTargetUnits[i] = "party" .. i .. "target"
end

local arenaTargetUnits = {}
for i = 1, 5 do
  arenaTargetUnits[i] = "arena" .. i .. "target"
end

local raidPetTargetUnits = {}
for i = 1, 40 do
  raidPetTargetUnits[i] = "raidpet" .. i .. "target"
end

local partyPetTargetUnits = {}
for i = 1, 5 do
  partyPetTargetUnits[i] = "partypet" .. i .. "target"
end

function BattleGroundEnemies:ScanTargets()
  if not self.states.userIsAlive then
    return
  end

  self.Enemies.UnitTargets = self.Enemies.UnitTargets or {}
  if IsInRaid() then
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
      local targetUnitID = raidTargetUnits[i]
      local sourceUnit = "raid" .. i
      if targetUnitID and UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
        local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
        local oldButton = self.Enemies.UnitTargets[sourceUnit]

        if oldButton and oldButton ~= btn then
          self.Enemies:RemoveGroupTarget(oldButton, sourceUnit)
        end

        if btn then
          self.Enemies:AddGroupTarget(btn, sourceUnit, targetUnitID)
          self.Enemies.UnitTargets[sourceUnit] = btn
          btn:UpdateRangeViaLibRangeCheck(targetUnitID)
        else
          self.Enemies.UnitTargets[sourceUnit] = nil
        end
      else
        local oldButton = self.Enemies.UnitTargets[sourceUnit]
        if oldButton then
          self.Enemies:RemoveGroupTarget(oldButton, sourceUnit)
          self.Enemies.UnitTargets[sourceUnit] = nil
        end
      end
    end
  elseif IsInGroup() then
    local numMembers = GetNumGroupMembers() - 1
    for i = 1, numMembers do
      local targetUnitID = partyTargetUnits[i]
      local sourceUnit = "party" .. i
      if targetUnitID and UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
        local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
        local oldButton = self.Enemies.UnitTargets[sourceUnit]

        if oldButton and oldButton ~= btn then
          self.Enemies:RemoveGroupTarget(oldButton, sourceUnit)
        end

        if btn then
          self.Enemies:AddGroupTarget(btn, sourceUnit, targetUnitID)
          self.Enemies.UnitTargets[sourceUnit] = btn
          -- Inline health/power writes removed (see scanRaid note above).
          btn:UpdateRangeViaLibRangeCheck(targetUnitID)
        else
          self.Enemies.UnitTargets[sourceUnit] = nil
        end
      else
        local oldButton = self.Enemies.UnitTargets[sourceUnit]
        if oldButton then
          self.Enemies:RemoveGroupTarget(oldButton, sourceUnit)
          self.Enemies.UnitTargets[sourceUnit] = nil
        end
      end
    end
  end

  local haveAllyButtons = false
  if self.Allies and self.Allies.Players then
    for _ in pairs(self.Allies.Players) do
      haveAllyButtons = true
      break
    end
  end

  if haveAllyButtons then
    for _, allyButton in pairs(self.Allies.Players) do
      if allyButton ~= self.UserButton then
        allyButton:UpdateTarget()
      end
    end
  else
    self._virtualAllySources = self._virtualAllySources or {}
    self._allyTargeterSlot = self._allyTargeterSlot or {}

    local function scanAllyTargeter(slotKey, allyUnit)
      if self.UserButton and UnitIsUnit(allyUnit, "player") then
        return
      end

      local newBtn
      local targetUnit = allyUnit .. "target"
      if UnitExists(targetUnit) and IsEnemyUnit(targetUnit) then
        newBtn = self:GetPlayerbuttonByUnitID(targetUnit, "Enemies")
      end

      local source = self._virtualAllySources[slotKey]
      if not source then
        source = { PlayerDetails = {} }
        self._virtualAllySources[slotKey] = source
      end

      local oldBtn = self._allyTargeterSlot[slotKey]
      if oldBtn and oldBtn ~= newBtn then
        if oldBtn.UnitIDs and oldBtn.UnitIDs.TargetedByEnemy then
          oldBtn.UnitIDs.TargetedByEnemy[source] = nil
        end
        oldBtn:DispatchEvent("UpdateTargetIndicators")
      end

      if newBtn and newBtn.UnitIDs and newBtn.UnitIDs.TargetedByEnemy then
        local _, classToken = UnitClass(allyUnit)
        local color = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken]
        if color then
          source.PlayerDetails.PlayerClassColor = color
          source.Target = newBtn
          newBtn.UnitIDs.TargetedByEnemy[source] = true
          newBtn:DispatchEvent("UpdateTargetIndicators")
        else
          newBtn = nil
        end
      else
        newBtn = nil
      end

      if not newBtn then
        source.Target = nil
      end
      self._allyTargeterSlot[slotKey] = newBtn
    end

    if IsInRaid() then
      for i = 1, GetNumGroupMembers() do
        scanAllyTargeter("raid" .. i, "raid" .. i)
      end
    elseif IsInGroup() then
      scanAllyTargeter("player", "player")
      for i = 1, GetNumGroupMembers() - 1 do
        scanAllyTargeter("party" .. i, "party" .. i)
      end
    end
  end

  -- Scan arena units (direct refs — exist in arena AND objective BGs like flags/orbs)
  for i = 1, 5 do
    local unitID = arenaUnits[i]
    if UnitExists(unitID) then
      local btn = self:GetPlayerbuttonByUnitID(unitID, "Enemies")
      if btn then
        btn:UNIT_HEALTH(unitID)
        btn:UNIT_POWER_FREQUENT(unitID)
        btn:UpdateRangeViaLibRangeCheck(unitID)
      end
    end
  end

  -- Scan nameplates (enemy only)
  local maxNameplate = self.maxNameplateIndex or 40
  for i = 1, maxNameplate do
    local unitID = nameplateUnits[i]
    if UnitExists(unitID) and IsEnemyUnit(unitID) then
      local btn = self:GetPlayerbuttonByUnitID(unitID, "Enemies")
      if btn then
        -- Persist the Nameplate token if not already assigned to this button.
        -- Catches tokens that NAME_PLATE_UNIT_ADDED missed while unit data was unavailable.
        if btn.UnitIDs and btn.UnitIDs.Nameplate ~= unitID then
          -- Clean up any other button that had this nameplate token
          if self.Enemies and self.Enemies.Players then
            for _, otherBtn in pairs(self.Enemies.Players) do
              if otherBtn ~= btn and otherBtn.UnitIDs and otherBtn.UnitIDs.Nameplate == unitID then
                otherBtn:UpdateEnemyUnitID("Nameplate", false)
                break
              end
            end
          end
          btn:UpdateEnemyUnitID("Nameplate", unitID)
        end
        btn:UNIT_HEALTH(unitID)
        btn:UNIT_POWER_FREQUENT(unitID)
        btn:UpdateRangeViaLibRangeCheck(unitID)
      end
    end
  end

  -- Scan nameplate targets (what visible enemies are targeting)
  self.Enemies.NameplateTargets = self.Enemies.NameplateTargets or {}
  self.Allies.NameplateTargets = self.Allies.NameplateTargets or {}

  for i = 1, maxNameplate do
    local sourceUnit = nameplateUnits[i]
    local targetUnitID = nameplateTargetUnits[i]

    -- Track enemy nameplates targeting other enemies
    if UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
      local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
      local oldButton = self.Enemies.NameplateTargets[sourceUnit]

      if oldButton and oldButton ~= btn then
        self.Enemies:RemoveNameplateTarget(oldButton, sourceUnit)
      end

      if btn then
        -- Inline health/power writes removed (see scanRaid note above).
        btn:UpdateRangeViaLibRangeCheck(targetUnitID)
        self.Enemies:AddNameplateTarget(btn, sourceUnit, targetUnitID)
        self.Enemies.NameplateTargets[sourceUnit] = btn
      else
        self.Enemies.NameplateTargets[sourceUnit] = nil
      end

      -- Track enemy nameplates targeting allies (for ally target indicators)
    elseif UnitExists(targetUnitID) and UnitIsFriend("player", targetUnitID) then
      -- Get the enemy button for the nameplate doing the targeting
      local enemyBtn = self:GetPlayerbuttonByUnitID(sourceUnit, "Enemies")

      local targetName = self:GetCanonicalUnitName(targetUnitID)
      local allyBtn = targetName and self.Allies.Players and self.Allies.Players[targetName]

      local oldAllyButton = self.Allies.NameplateTargets[sourceUnit]
      if oldAllyButton then
        -- Get the old enemy button to remove
        local oldEnemyBtn = self.Allies.NameplateTargetMap and self.Allies.NameplateTargetMap[oldAllyButton]
        if oldEnemyBtn and type(oldEnemyBtn) == "table" then
          for oldEnemy in pairs(oldEnemyBtn) do
            if oldEnemy ~= enemyBtn then
              self.Allies:RemoveNameplateTarget(oldAllyButton, oldEnemy)
            end
          end
        end
      end

      if allyBtn and enemyBtn then
        -- Pass the enemy button (not the sourceUnit string)
        self.Allies:AddNameplateTarget(allyBtn, enemyBtn)
        self.Allies.NameplateTargets[sourceUnit] = allyBtn
      else
        self.Allies.NameplateTargets[sourceUnit] = nil
      end

      -- Clear any enemy→enemy target for this nameplate
      local oldEnemyButton = self.Enemies.NameplateTargets[sourceUnit]
      if oldEnemyButton then
        self.Enemies:RemoveNameplateTarget(oldEnemyButton, sourceUnit)
        self.Enemies.NameplateTargets[sourceUnit] = nil
      end
    else
      -- Clear both if no valid target
      local oldButton = self.Enemies.NameplateTargets[sourceUnit]
      if oldButton then
        self.Enemies:RemoveNameplateTarget(oldButton, sourceUnit)
        self.Enemies.NameplateTargets[sourceUnit] = nil
      end
      local oldAllyButton = self.Allies.NameplateTargets[sourceUnit]
      if oldAllyButton then
        -- Get the enemy button that was targeting this ally
        local enemyBtn = self:GetPlayerbuttonByUnitID(sourceUnit, "Enemies")
        if enemyBtn then
          self.Allies:RemoveNameplateTarget(oldAllyButton, enemyBtn)
        end
        self.Allies.NameplateTargets[sourceUnit] = nil
      end
    end
  end

  -- Scan pettarget (your pet's target — direct reference)
  -- Persist PetTarget token to fill gaps when UNIT_TARGET event missed in combat.
  if UnitExists("pettarget") and IsEnemyUnit("pettarget") then
    local btn = self:GetPlayerbuttonByUnitID("pettarget", "Enemies")
    local oldBtn = self.Enemies.PetTargetButton
    if oldBtn and oldBtn ~= btn then
      oldBtn:UpdateEnemyUnitID("PetTarget", nil)
      self.Enemies.PetTargetButton = nil
    end
    if btn then
      btn:UpdateEnemyUnitID("PetTarget", "pettarget")
      self.Enemies.PetTargetButton = btn
      -- Inline health/power writes removed (see scanRaid note above).
      btn:UpdateRangeViaLibRangeCheck("pettarget")
    end
  else
    local oldBtn = self.Enemies.PetTargetButton
    if oldBtn then
      oldBtn:UpdateEnemyUnitID("PetTarget", nil)
      self.Enemies.PetTargetButton = nil
    end
  end

  -- Scan focustarget (your focus's target — indirect)
  -- Persist FocusTarget token to fill gaps when UNIT_TARGET event missed in combat.
  if UnitExists("focustarget") and IsEnemyUnit("focustarget") then
    local btn = self:GetPlayerbuttonByUnitID("focustarget", "Enemies")
    local oldBtn = self.Enemies.FocusTargetButton
    if oldBtn and oldBtn ~= btn then
      oldBtn:UpdateEnemyUnitID("FocusTarget", nil)
      self.Enemies.FocusTargetButton = nil
    end
    if btn then
      btn:UpdateEnemyUnitID("FocusTarget", "focustarget")
      self.Enemies.FocusTargetButton = btn
      -- Inline health/power writes removed (see scanRaid note above).
      btn:UpdateRangeViaLibRangeCheck("focustarget")
    end
  else
    local oldBtn = self.Enemies.FocusTargetButton
    if oldBtn then
      oldBtn:UpdateEnemyUnitID("FocusTarget", nil)
      self.Enemies.FocusTargetButton = nil
    end
  end

  if UnitExists("targettarget") and IsEnemyUnit("targettarget") then
    local btn = self:GetPlayerbuttonByUnitID("targettarget", "Enemies")
    local oldBtn = self.Enemies.TargetTargetButton
    if oldBtn and oldBtn ~= btn then
      oldBtn:UpdateEnemyUnitID("TargetTarget", nil)
      self.Enemies.TargetTargetButton = nil
    end
    if btn then
      btn:UpdateEnemyUnitID("TargetTarget", "targettarget")
      self.Enemies.TargetTargetButton = btn
      btn:UpdateRangeViaLibRangeCheck("targettarget")
    end
  else
    local oldBtn = self.Enemies.TargetTargetButton
    if oldBtn then
      oldBtn:UpdateEnemyUnitID("TargetTarget", nil)
      self.Enemies.TargetTargetButton = nil
    end
  end

  -- Scan arena targets (what arena enemies are targeting)
  self.Enemies.ArenaTargets = self.Enemies.ArenaTargets or {}
  self.Allies.ArenaTargets = self.Allies.ArenaTargets or {}

  for i = 1, 5 do
    local sourceUnit = arenaUnits[i]
    local targetUnitID = arenaTargetUnits[i]

    -- Track arena enemies targeting other enemies
    if UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
      local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
      local oldButton = self.Enemies.ArenaTargets[sourceUnit]

      if oldButton and oldButton ~= btn then
        self.Enemies:RemoveArenaTarget(oldButton, sourceUnit)
      end

      if btn then
        -- Inline health/power writes removed (see scanRaid note above).
        btn:UpdateRangeViaLibRangeCheck(targetUnitID)
        self.Enemies:AddArenaTarget(btn, sourceUnit, targetUnitID)
        self.Enemies.ArenaTargets[sourceUnit] = btn
      else
        self.Enemies.ArenaTargets[sourceUnit] = nil
      end

      -- Track arena enemies targeting allies (for ally target indicators)
    elseif UnitExists(targetUnitID) and UnitIsFriend("player", targetUnitID) then
      -- Get the enemy button for the arena unit doing the targeting
      local enemyBtn = self.ArenaIDToPlayerButton[sourceUnit]
      if not enemyBtn then
        enemyBtn = self:GetPlayerbuttonByUnitID(sourceUnit, "Enemies")
      end

      local targetName = self:GetCanonicalUnitName(targetUnitID)
      local allyBtn = targetName and self.Allies.Players and self.Allies.Players[targetName]

      local oldAllyButton = self.Allies.ArenaTargets[sourceUnit]
      if oldAllyButton then
        -- Get the old enemy button to remove
        local oldEnemyBtns = self.Allies.ArenaTargetMap and self.Allies.ArenaTargetMap[oldAllyButton]
        if oldEnemyBtns and type(oldEnemyBtns) == "table" then
          for oldEnemy in pairs(oldEnemyBtns) do
            if oldEnemy ~= enemyBtn then
              self.Allies:RemoveArenaTarget(oldAllyButton, oldEnemy)
            end
          end
        end
      end

      if allyBtn and enemyBtn then
        -- Pass the enemy button (not the sourceUnit string)
        self.Allies:AddArenaTarget(allyBtn, enemyBtn)
        self.Allies.ArenaTargets[sourceUnit] = allyBtn
      else
        self.Allies.ArenaTargets[sourceUnit] = nil
      end

      -- Clear any enemy→enemy target for this arena unit
      local oldEnemyButton = self.Enemies.ArenaTargets[sourceUnit]
      if oldEnemyButton then
        self.Enemies:RemoveArenaTarget(oldEnemyButton, sourceUnit)
        self.Enemies.ArenaTargets[sourceUnit] = nil
      end
    else
      -- Clear both if no valid target
      local oldButton = self.Enemies.ArenaTargets[sourceUnit]
      if oldButton then
        self.Enemies:RemoveArenaTarget(oldButton, sourceUnit)
        self.Enemies.ArenaTargets[sourceUnit] = nil
      end
      local oldAllyButton = self.Allies.ArenaTargets[sourceUnit]
      if oldAllyButton then
        -- Get the enemy button that was targeting this ally
        local enemyBtn = self.ArenaIDToPlayerButton[sourceUnit]
        if not enemyBtn then
          enemyBtn = self:GetPlayerbuttonByUnitID(sourceUnit, "Enemies")
        end
        if enemyBtn then
          self.Allies:RemoveArenaTarget(oldAllyButton, enemyBtn)
        end
        self.Allies.ArenaTargets[sourceUnit] = nil
      end
    end
  end

  -- Scan group pet targets (what allies' pets are targeting)
  self.Enemies.GroupPetTargets = self.Enemies.GroupPetTargets or {}
  if IsInRaid() then
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
      local sourceUnit = "raidpet" .. i
      local targetUnitID = raidPetTargetUnits[i]
      if targetUnitID and UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
        local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
        local oldButton = self.Enemies.GroupPetTargets[sourceUnit]

        if oldButton and oldButton ~= btn then
          self.Enemies:RemoveGroupPetTarget(oldButton, sourceUnit)
        end

        if btn then
          -- Inline health/power writes removed (see scanRaid note above).
          btn:UpdateRangeViaLibRangeCheck(targetUnitID)
          self.Enemies:AddGroupPetTarget(btn, sourceUnit, targetUnitID)
          self.Enemies.GroupPetTargets[sourceUnit] = btn
        else
          self.Enemies.GroupPetTargets[sourceUnit] = nil
        end
      else
        local oldButton = self.Enemies.GroupPetTargets[sourceUnit]
        if oldButton then
          self.Enemies:RemoveGroupPetTarget(oldButton, sourceUnit)
          self.Enemies.GroupPetTargets[sourceUnit] = nil
        end
      end
    end
  elseif IsInGroup() then
    local numMembers = GetNumGroupMembers() - 1
    for i = 1, numMembers do
      local sourceUnit = "partypet" .. i
      local targetUnitID = partyPetTargetUnits[i]
      if targetUnitID and UnitExists(targetUnitID) and IsEnemyUnit(targetUnitID) then
        local btn = self:GetPlayerbuttonByUnitID(targetUnitID, "Enemies")
        local oldButton = self.Enemies.GroupPetTargets[sourceUnit]

        if oldButton and oldButton ~= btn then
          self.Enemies:RemoveGroupPetTarget(oldButton, sourceUnit)
        end

        if btn then
          -- Inline health/power writes removed (see scanRaid note above).
          btn:UpdateRangeViaLibRangeCheck(targetUnitID)
          self.Enemies:AddGroupPetTarget(btn, sourceUnit, targetUnitID)
          self.Enemies.GroupPetTargets[sourceUnit] = btn
        else
          self.Enemies.GroupPetTargets[sourceUnit] = nil
        end
      else
        local oldButton = self.Enemies.GroupPetTargets[sourceUnit]
        if oldButton then
          self.Enemies:RemoveGroupPetTarget(oldButton, sourceUnit)
          self.Enemies.GroupPetTargets[sourceUnit] = nil
        end
      end
    end
  end

  local sweepList = self.Enemies and self.Enemies.PlayerList
  if sweepList then
    local targetPending = self._targetChangeTimer ~= nil
    for i = 1, #sweepList do
      local btn = sweepList[i]
      local uid = btn.unitID
      local compoundCC = btn.SpecClassPriority and btn.SpecClassPriority:IsCompoundLiveCCUnit(uid)
      if
        uid
        and not (btn.PlayerDetails and btn.PlayerDetails.isFakePlayer)
        and not (targetPending and uid == "target")
        and UnitExists(uid)
      then
        btn:UNIT_HEALTH(uid)
        btn:UNIT_POWER_FREQUENT(uid)
        if compoundCC then
          -- Secure aura containers cannot be identity-pinned to volatile
          -- compound aliases. SyncLiveCCUnit clears rather than binds them.
          btn.SpecClassPriority:SyncLiveCCUnit(uid, true)
        end
      elseif compoundCC then
        -- Roster shrink can strand an old raidNtarget/raidpetNtarget outside
        -- the loops above. Clear a binding whose elected token no longer exists.
        btn.SpecClassPriority:SetLiveCCUnit(nil)
      end
    end
  end
end

function BattleGroundEnemies:StartTargetScanTicker()
  if self.TargetScanTicker then
    self.TargetScanTicker:Cancel()
  end

  local oocSkip = false
  self.TargetScanTicker = C_Timer.NewTicker(0.3, function()
    if not self.enabled then
      return
    end
    if InCombatLockdown() then
      oocSkip = false
    else
      oocSkip = not oocSkip
      if oocSkip then
        return
      end
    end
    self:ScanTargets()
  end)
end

function BattleGroundEnemies:StopTargetScanTicker()
  if self.TargetScanTicker then
    self.TargetScanTicker:Cancel()
    self.TargetScanTicker = nil
  end
end

function BattleGroundEnemies:PLAYER_SOFT_ENEMY_CHANGED()
  if not self.states.userIsAlive then
    return
  end
  local btn = self:GetPlayerbuttonByUnitID("softenemy", "Enemies")
  if btn then
    btn:UNIT_HEALTH("softenemy")
    btn:UNIT_POWER_FREQUENT("softenemy")
    btn:UpdateRangeViaLibRangeCheck("softenemy")
  end
end

function BattleGroundEnemies:HandleAllyTargetChanged(newTarget)
  -- Hide previous ally target highlight
  if BattleGroundEnemies.currentAllyTarget then
    BattleGroundEnemies.currentAllyTarget.MyTarget:Hide()
  end

  if newTarget then
    -- Show target highlight on ally button
    newTarget.MyTarget:Show()
    BattleGroundEnemies.currentAllyTarget = newTarget
  else
    BattleGroundEnemies.currentAllyTarget = false
  end
end

function BattleGroundEnemies:HandleAllyFocusChanged(newFocus)
  -- Hide previous ally focus highlight
  if BattleGroundEnemies.currentAllyFocus then
    BattleGroundEnemies.currentAllyFocus.MyFocus:Hide()
  end

  if newFocus then
    -- Show focus highlight on ally button
    newFocus.MyFocus:Show()
    BattleGroundEnemies.currentAllyFocus = newFocus
  else
    BattleGroundEnemies.currentAllyFocus = false
  end
end

function BattleGroundEnemies:HandleTargetChanged(newTarget)
  if BattleGroundEnemies.currentTarget then
    BattleGroundEnemies.currentTarget:UpdateEnemyUnitID("Target", false)

    if self.UserButton then
      self.UserButton:IsNoLongerTarging(BattleGroundEnemies.currentTarget)
    end
    BattleGroundEnemies.currentTarget.MyTarget:Hide()
  end

  if newTarget then --i target an existing player
    newTarget:UpdateEnemyUnitID("Target", "target")
    if self.UserButton then
      self.UserButton:IsNowTargeting(newTarget)
    end
    newTarget.MyTarget:Show()
    BattleGroundEnemies.currentTarget = newTarget

    -- if BattleGroundEnemies.states.real.isRatedBG and self.db.profile.RBG.TargetCalling_SetMark and IamTargetcaller() then -- i am the target caller
    -- 	SetRaidTarget("target", 8)
    -- end
  else
    BattleGroundEnemies.currentTarget = false
  end
end

function BattleGroundEnemies:PLAYER_TARGET_CHANGED()
  if self._targetChangeTimer then
    self._targetChangeTimer:Cancel()
  end
  self._targetChangeTimer = C_Timer.NewTimer(0, function()
    self._targetChangeTimer = nil
    self:PLAYER_TARGET_CHANGED_Deferred()
  end)
end

function BattleGroundEnemies:HandleFocusChanged(newFocus)
  if BattleGroundEnemies.currentFocus then
    BattleGroundEnemies.currentFocus:UpdateEnemyUnitID("Focus", false)

    BattleGroundEnemies.currentFocus.MyFocus:Hide()
  end
  if newFocus then
    newFocus:UpdateEnemyUnitID("Focus", "focus")

    newFocus.MyFocus:Show()
    BattleGroundEnemies.currentFocus = newFocus
  else
    BattleGroundEnemies.currentFocus = false
  end
end

-- Target and focus use the same exact canonical UnitName key as every other
-- token consumer.
local function GetTrackedPlayerByUnitName(self, unitID)
  local playerName = self:GetCanonicalUnitName(unitID)
  if not playerName then
    return nil, false
  end

  local allyButton = self.Allies and self.Allies.Players and self.Allies.Players[playerName]
  if allyButton then
    return allyButton, true
  end
  return self.Enemies and self.Enemies.Players and self.Enemies.Players[playerName] or nil, false
end

function BattleGroundEnemies:PLAYER_TARGET_CHANGED_Deferred()
  self._lastClickedEnemyTarget = nil
  self._lastClickedEnemyTargetTime = nil

  local btn, isAlly = GetTrackedPlayerByUnitName(self, "target")
  if not btn then
    self:HandleTargetChanged(nil)
    self:HandleAllyTargetChanged(nil)
  elseif isAlly then
    self:HandleTargetChanged(nil)
    self:HandleAllyTargetChanged(btn)
  else
    self:HandleAllyTargetChanged(nil)
    self:HandleTargetChanged(btn)
  end
end

function BattleGroundEnemies:PLAYER_FOCUS_CHANGED()
  self._lastClickedEnemyFocus = nil
  self._lastClickedEnemyFocusTime = nil

  local btn, isAlly = GetTrackedPlayerByUnitName(self, "focus")
  if not btn then
    self:HandleFocusChanged(nil)
    self:HandleAllyFocusChanged(nil)
  elseif isAlly then
    self:HandleFocusChanged(nil)
    self:HandleAllyFocusChanged(btn)
  else
    self:HandleAllyFocusChanged(nil)
    self:HandleFocusChanged(btn)
  end
end

function BattleGroundEnemies:UPDATE_MOUSEOVER_UNIT()
  local enemyButton = self.Enemies:GetPlayerbuttonByUnitID("mouseover", "Enemies")
  if enemyButton then --unit is a shown enemy
    enemyButton:UpdateAll("mouseover")
  end
end

function BattleGroundEnemies:RAID_TARGET_UPDATE()
  local containers = { self.Enemies, self.Allies }
  for c = 1, #containers do
    local container = containers[c]
    if container and container.Players then
      for _, playerButton in pairs(container.Players) do
        playerButton:UpdateRaidTargetIcon()
      end
    end
  end
end

local function IsObjectiveBG(mapId)
  return mapId == 417 or mapId == 206 or mapId == 1339 or mapId == 112 or mapId == 397 or mapId == 2345
end

--fires when data requested by C_PvP.RequestCrowdControlSpell(unitID) is available
function BattleGroundEnemies:ARENA_CROWD_CONTROL_SPELL_UPDATE(unitID, ...)
  local playerButton = nil
  local isArenaUnit = unitID and unitID:match("^arena%d")
  local states = self:GetActiveStates()
  local isObjectiveMap = states and IsObjectiveBG(states.currentMapId)

  -- In objective BGs, ONLY process arena units - skip target/raid/nameplate/etc entirely
  -- This prevents duplicate trinket display when the same spell triggers for multiple unit types
  if isObjectiveMap and not isArenaUnit then
    return
  end

  -- Check ArenaIDToPlayerButton first for arena units
  if isArenaUnit then
    playerButton = self.ArenaIDToPlayerButton[unitID]
  end

  -- Fall back to exact-name matching, but not in objective BGs for arena units.
  -- In objective BGs, arena tokens are only assigned to flag/orb carriers, so if not in
  -- ArenaIDToPlayerButton, this player doesn't have an objective and shouldn't get trinket updates
  if not playerButton then
    if not (isArenaUnit and isObjectiveMap) then
      playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")
    end
  end

  local spellId, itemID = ...

  -- Cache the spell data keyed by unitID. This handles the race condition where
  -- ARENA_CROWD_CONTROL_SPELL_UPDATE fires before the ally button has its unitID assigned
  -- (common for "player" which Blizzard fires automatically on zone-in). When the button
  -- registers its unitID later, it checks this cache and applies the icon immediately.
  self._ccSpellCache = self._ccSpellCache or {}
  if unitID then
    self._ccSpellCache[unitID] = { spellId = spellId, itemID = itemID }
  end

  -- Also check ally buttons — RequestCrowdControlSpell is now called for party members
  -- and "player" so this event fires for allies too, letting us show their trinket icon
  -- in the lobby just like enemies. Ally-side lookup uses the direct token map.
  if not playerButton then
    playerButton = self.Allies:GetAllyButtonByUnitID(unitID)
  end

  if playerButton and playerButton.Trinket then
    -- For allies: show the trinket icon so we can see what CC-break they have.
    -- For enemies: do NOT show the icon here. This event only announces which
    -- trinket the unit HAS, not that they used it. Showing it preemptively is
    -- misleading (especially in solo shuffle where CDs reset between rounds).
    -- Enemy trinket icons are set in ARENA_COOLDOWNS_UPDATE when actually used.
    if not playerButton.PlayerIsEnemy then
      playerButton.Trinket:DisplayTrinket(spellId, itemID)
    end
  end

  --if spellId ~= 72757 then --cogwheel (30 sec cooldown trigger by racial)
  --end
end

--fires when a arenaX enemy used a trinket or racial to break cc, C_PvP.GetArenaCrowdControlInfo(unitID) shoudl be called afterwards to get used CCs
--this event is kinda stupid, it doesn't say which unit used which cooldown, it justs says that somebody used some sort of trinket
function BattleGroundEnemies:ARENA_COOLDOWNS_UPDATE(unitID)
  local states = self:GetActiveStates()
  local isObjectiveMap = states and IsObjectiveBG(states.currentMapId)

  if unitID then
    -- Specific unit fired — this unit likely used their trinket
    local playerButton = nil
    local isArenaUnit = unitID and unitID:match("^arena%d")

    -- Check ArenaIDToPlayerButton first for arena units (same fix as target/focus)
    if isArenaUnit then
      playerButton = self.ArenaIDToPlayerButton[unitID]
    end

    -- Fall back to exact-name matching, but not in objective BGs for arena units.
    -- In objective BGs, arena tokens are only assigned to flag/orb carriers, so if not in
    -- ArenaIDToPlayerButton, this player doesn't have an objective and shouldn't get trinket updates
    if not playerButton then
      if not (isArenaUnit and isObjectiveMap) then
        playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")
      end
    end

    if playerButton then
      local gotRealData = playerButton:UpdateCrowdControlCooldown(unitID)
      if not gotRealData then
        -- API returned nothing (taint-restricted, not in arena, etc.)
        -- Use a fake cooldown since we know THIS specific unit triggered the event.
        -- StartFakeCooldown() guards against re-triggers internally.
        playerButton:ApplyFakeTrinketCooldown()
      end
    end

    -- Also check allies (party/raid members using their trinket) — direct
    -- token map.
    if not playerButton then
      local allyButton = self.Allies:GetAllyButtonByUnitID(unitID)
      if allyButton then
        allyButton:UpdateAllyCrowdControlCooldown(unitID)
      end
    end
  else
    -- No unitID: general refresh. Only apply real API data, never fake.
    for i = 1, 4 do
      local arenaUnit = "arena" .. i
      -- Use ArenaIDToPlayerButton directly for arena units
      local playerButton = self.ArenaIDToPlayerButton[arenaUnit]
      -- Skip exact-name fallback in objective BGs (no objective = no trinket updates).
      if not playerButton and not isObjectiveMap then
        playerButton = self:GetPlayerbuttonByUnitID(arenaUnit, "Enemies")
      end
      if playerButton then
        playerButton:UpdateCrowdControlCooldown(arenaUnit)
      end
    end

    -- Refresh all ally trinkets on general update
    if self.Allies and self.Allies.Players then
      for _, allyButton in pairs(self.Allies.Players) do
        local allyUnitID = allyButton.unitID
        if allyUnitID and UnitExists(allyUnitID) then
          allyButton:UpdateAllyCrowdControlCooldown(allyUnitID)
        end
      end
    end
  end
end

-- DR tracking: route C_SpellDiminish events to the correct playerButton's DRTracking container
function BattleGroundEnemies:UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED(unitToken, stateInfo)
  if not unitToken or not stateInfo then
    return
  end

  -- DR data is unusable in BGs: C_SpellDiminish returns a secret-tagged
  -- category in BG context (the DiminishStateUpdated handler bails on it
  -- downstream), and the LoC poll fallback gets no usable spellID for
  -- enemy units. Skip the matcher lookup + per-button DispatchEvent
  -- fan-out entirely in BGs. DR still works in arena / world PvP.
  if self.states.real.isInBattleground then
    return
  end

  -- Find the playerButton that owns this unitToken
  local playerButton = self.ArenaIDToPlayerButton[unitToken]
  if not playerButton then
    playerButton = self:GetPlayerbuttonByUnitID(unitToken, "Enemies")
  end

  if playerButton then
    playerButton:DispatchEvent("DiminishStateUpdated", unitToken, stateInfo)
  end
end

function BattleGroundEnemies:UNIT_HEALTH(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
  local playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")

  -- If not found (rejected friendly unit), check ally buttons by unitID
  if not playerButton and UnitIsFriend("player", unitID) then
    if self.Allies and self.Allies.Players then
      for _, allyButton in pairs(self.Allies.Players) do
        if allyButton.unitID == unitID then
          playerButton = allyButton
          break
        end
      end
    end
  end

  if playerButton then --unit is a shown player
    playerButton:UNIT_HEALTH(unitID)
  end
end

BattleGroundEnemies.UNIT_HEALTH_FREQUENT = BattleGroundEnemies.UNIT_HEALTH --used to be used only in tbc, now its only used in classic and wrath

-- UNIT_MAXHEALTH gets its own handler (was aliased to UNIT_HEALTH): the
-- health bar refreshes its min/max range ONLY when the max actually changed
-- (CompactUnitFrame model — range set on UNIT_MAXHEALTH, SetValue per health
-- write). Body mirrors BattleGroundEnemies:UNIT_HEALTH above; the per-button
-- handler flags the bar's range dirty and then runs the normal health path.
function BattleGroundEnemies:UNIT_MAXHEALTH(unitID)
  local playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")

  -- If not found (rejected friendly unit), check ally buttons by unitID
  if not playerButton and UnitIsFriend("player", unitID) then
    if self.Allies and self.Allies.Players then
      for _, allyButton in pairs(self.Allies.Players) do
        if allyButton.unitID == unitID then
          playerButton = allyButton
          break
        end
      end
    end
  end

  if playerButton then --unit is a shown player
    playerButton:UNIT_MAXHEALTH(unitID)
  end
end

BattleGroundEnemies.UNIT_HEAL_PREDICTION = BattleGroundEnemies.UNIT_HEALTH
BattleGroundEnemies.UNIT_ABSORB_AMOUNT_CHANGED = BattleGroundEnemies.UNIT_HEALTH
BattleGroundEnemies.UNIT_HEAL_ABSORB_AMOUNT_CHANGED = BattleGroundEnemies.UNIT_HEALTH

function BattleGroundEnemies:UNIT_POWER_FREQUENT(unitID, powerToken)
  local playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")

  -- If not found (rejected friendly unit), check ally buttons by unitID
  if not playerButton and UnitIsFriend("player", unitID) then
    if self.Allies and self.Allies.Players then
      for _, allyButton in pairs(self.Allies.Players) do
        if allyButton.unitID == unitID then
          playerButton = allyButton
          break
        end
      end
    end
  end

  if playerButton then
    playerButton:UNIT_POWER_FREQUENT(unitID, powerToken)
  end
end

BattleGroundEnemies.UNIT_POWER_UPDATE = BattleGroundEnemies.UNIT_POWER_FREQUENT
BattleGroundEnemies.UNIT_MAXPOWER = BattleGroundEnemies.UNIT_POWER_FREQUENT

BattleGroundEnemies.PendingUpdates = {}
function BattleGroundEnemies:QueueForUpdateAfterCombat(tbl, funcName)
  --dont add the same function twice
  for i = 1, #BattleGroundEnemies.PendingUpdates do
    local pendingUpdate = BattleGroundEnemies.PendingUpdates[i]
    if pendingUpdate.tbl == tbl and pendingUpdate.funcName == funcName then
      return
    end
  end

  table.insert(self.PendingUpdates, { tbl = tbl, funcName = funcName })
end

local DEBUG_LOG_CAP = 1000

function BattleGroundEnemies:IsDebug()
  return (self.db and self.db.global and self.db.global.debugMode) and true or false
end

function BattleGroundEnemies:Debug(...)
  if not (self.db and self.db.global and self.db.global.debugMode) then
    return
  end
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring((select(i, ...)))
  end
  local msg = table.concat(parts, " ")
  print("|cff33ff99[BGE debug]|r", msg)
  -- Persist to the SavedVariables ring buffer (BattleGroundEnemiesDB.global.debugLog)
  -- so issues survive past chat scrollback / a crash — review with /bge debug dump,
  -- or read the SV file off disk. Scoped to this addon's own DB.
  local log = self.db.global.debugLog
  if not log then
    log = {}
    self.db.global.debugLog = log
  end
  log[#log + 1] = date("%m/%d %H:%M:%S") .. "  " .. msg
  if #log >= DEBUG_LOG_CAP * 2 then
    -- amortized trim: rebuild keeping only the newest DEBUG_LOG_CAP entries
    local keep = {}
    for i = #log - DEBUG_LOG_CAP + 1, #log do
      keep[#keep + 1] = log[i]
    end
    self.db.global.debugLog = keep
  end
end

function BattleGroundEnemies:ADDON_ACTION_BLOCKED(blockedAddon, blockedFunc)
  self:Debug(
    "ADDON_ACTION_BLOCKED",
    "addon=" .. tostring(blockedAddon),
    "func=" .. tostring(blockedFunc),
    InCombatLockdown() and "(in combat)" or "(out of combat)"
  )
end

function BattleGroundEnemies:ADDON_ACTION_FORBIDDEN(forbiddenAddon, forbiddenFunc)
  self:Debug(
    "ADDON_ACTION_FORBIDDEN",
    "addon=" .. tostring(forbiddenAddon),
    "func=" .. tostring(forbiddenFunc),
    InCombatLockdown() and "(in combat)" or "(out of combat)"
  )
end

function BattleGroundEnemies:PLAYER_REGEN_ENABLED()
  --Check if there are any outstanding updates that have been hold back due to being in combat
  for i = 1, #self.PendingUpdates do
    local tbl = self.PendingUpdates[i].tbl
    local funcName = self.PendingUpdates[i].funcName
    tbl[funcName](tbl)
  end
  wipe(self.PendingUpdates)

  -- Hide any buttons that were deferred during combat
  for _, buttons in pairs({
    self.Enemies and self.Enemies.InactivePlayerButtons,
    self.Allies and self.Allies.InactivePlayerButtons,
  }) do
    if buttons then
      for _, btn in ipairs(buttons) do
        if btn.pendingHide then
          btn:Hide()
          btn.pendingHide = nil
        end
      end
    end
  end

  for _, mf in ipairs({ self.Enemies, self.Allies }) do
    if mf and mf.enabled and (mf.NumPlayers or 0) > 0 and not mf:IsShown() then
      mf:Show()
    end
  end

  for _, mf in ipairs({ self.Enemies, self.Allies }) do
    if mf and mf.PlayerList and mf.NumPlayers and #mf.PlayerList > mf.NumPlayers and mf.NumPlayers > 0 then
      if mf.PlayerType == BattleGroundEnemies.consts.PlayerTypes.Enemies then
        BattleGroundEnemies._lastEnemyCount = nil
        if BattleGroundEnemies.UPDATE_BATTLEFIELD_SCORE then
          BattleGroundEnemies:UPDATE_BATTLEFIELD_SCORE()
        end
      else
        if BattleGroundEnemies.GROUP_ROSTER_UPDATE then
          BattleGroundEnemies:GROUP_ROSTER_UPDATE()
        end
      end
    end
  end
end

function BattleGroundEnemies:PLAYER_REGEN_DISABLED()
  if self.states.testmodeActive then
    self:DisableTestMode()
  end
end

function BattleGroundEnemies:PlayerDead()
  self.states.userIsAlive = false
  local mainframes = { self.Enemies, self.Allies }
  for _, mf in ipairs(mainframes) do
    if mf and mf.PlayerList then
      for i = 1, #mf.PlayerList do
        local playerButton = mf.PlayerList[i]
        playerButton:UpdateRange(false, true)
        local unitID = playerButton.unitID
        if playerButton.SpecClassPriority and playerButton.SpecClassPriority:IsCompoundLiveCCUnit(unitID) then
          -- ScanTargets pauses while the viewer is dead, so these compound
          -- endpoints cannot be revalidated until scanning resumes.
          playerButton.SpecClassPriority:SetLiveCCUnit(nil)
        end
      end
    end
  end
end

function BattleGroundEnemies:PlayerAlive()
  local mainframes = { self.Enemies, self.Allies }
  for _, mf in ipairs(mainframes) do
    if mf and mf.PlayerList then
      for i = 1, #mf.PlayerList do
        mf.PlayerList[i]:UpdateRange(false, true)
      end
    end
  end
  --recheck the targets of groupmembers
  for allyName, allyButton in pairs(self.Allies.Players) do
    allyButton:UpdateTarget()
  end
  self.states.userIsAlive = true
  if self.RefreshObjectiveCarriers then
    self:RefreshObjectiveCarriers()
  end
end

function BattleGroundEnemies:PLAYER_ALIVE()
  if UnitIsGhost("player") then --Releases his ghost to a graveyard.
    self:PlayerDead()
  else --alive (revived while not being a ghost)
    self:PlayerAlive()
  end
end

function BattleGroundEnemies:PLAYER_DEAD()
  self:PlayerDead()
end

-- Reset isDead on all buttons and force a health refresh.
-- Used between solo shuffle rounds so bars don't stay empty.
function BattleGroundEnemies:ResetAllDeadStates()
  local mainframes = { self.Allies, self.Enemies }
  for _, mf in ipairs(mainframes) do
    if mf and mf.Players then
      for _, playerButton in pairs(mf.Players) do
        if playerButton.isDead then
          playerButton:PlayerIsAlive()
        end
        -- Push synthetic 100% directly via UpdateHealth (bypassing
        -- UNIT_HEALTH, which is blocked by the betweenRounds guard).
        -- The 3-second timer will clear betweenRounds and re-query
        -- real health once units have respawned.
        playerButton:UpdateHealth(nil, 1, 0, 100, 1)
        -- Clear stale raid target icons — players swap sides between
        -- rounds so old markers are no longer valid.
        playerButton.RaidTargetIconIndex = nil
        playerButton:DispatchEvent("UpdateRaidTargetIcon", nil)
        -- Clear trinket icons — players swap sides between rounds
        -- so an ally's trinket shouldn't carry over to their enemy button.
        if playerButton.Trinket then
          playerButton.Trinket:Reset()
        end
      end
    end
  end
end

function BattleGroundEnemies:UNIT_TARGET(unitID)
  local playerButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")

  if playerButton and playerButton ~= self.UserButton then --we use Player_target_changed for the player
    playerButton:UpdateTarget()
  end

  -- Enhancement: Snapshot update for the unit being targeted
  -- Restriction: Only check targets of friendly players (party/raid) to avoid secret value crashes for nameplates
  if string.find(unitID, "^party") or string.find(unitID, "^raid") or unitID == "player" then
    local targetUnitID = unitID .. "target"
    if UnitExists(targetUnitID) then
      local targetName = self:GetCanonicalUnitName(targetUnitID)
      local enemyButton = targetName and self.Enemies.Players[targetName]
      if enemyButton then
        -- Force an update since we have a valid unitID pointing to them right now
        enemyButton:UNIT_HEALTH(targetUnitID)
        enemyButton:UNIT_POWER_FREQUENT(targetUnitID)
      end
    end
  end
end

local function changeVisibility(frame, visible)
  -- Use the original scale setter to avoid Edit Mode's secret anchor loop.
  local setScale = frame.SetScaleBase or frame.SetScale

  if visible then
    frame:SetAlpha(1)
    setScale(frame, 1)
  else
    frame:SetAlpha(0)
    setScale(frame, 0.001)
  end
end

local function disableArenaFrames()
  if ArenaEnemyFrames then
    if ArenaEnemyFrames_Disable then
      ArenaEnemyFrames_Disable(ArenaEnemyFrames)
    end
  elseif ArenaEnemyFramesContainer then
    changeVisibility(ArenaEnemyFramesContainer, false)
  end
  if CompactArenaFrame then
    changeVisibility(CompactArenaFrame, false)
  end
end

local function checkEffectiveEnableStateForArenaFrames()
  if ArenaEnemyFrames then
    if ArenaEnemyFrames_CheckEffectiveEnableState then
      ArenaEnemyFrames_CheckEffectiveEnableState(ArenaEnemyFrames)
    end
  elseif ArenaEnemyFramesContainer then
    changeVisibility(ArenaEnemyFramesContainer, true)
  end
  if CompactArenaFrame then
    changeVisibility(CompactArenaFrame, true)
  end
end

function BattleGroundEnemies:ToggleArenaFrames()
  if InCombatLockdown() then
    return self:QueueForUpdateAfterCombat(self, "ToggleArenaFrames")
  end
  if
    (BattleGroundEnemies.states.real.isInArena and self.db.profile.DisableArenaFramesInArena)
    or (BattleGroundEnemies.states.real.isInBattleground and self.db.profile.DisableArenaFramesInBattleground)
  then
    return disableArenaFrames()
  end

  checkEffectiveEnableStateForArenaFrames()
end

local function restoreShowRaidFrameCVar()
  if not previousCvarRaidOptionIsShown then
    return
  end --we didn't modify it so no need to restore it
  SetCVar("raidOptionIsShown", previousCvarRaidOptionIsShown)
end

local function disableRaidFrames()
  if previousCvarRaidOptionIsShown == nil then
    previousCvarRaidOptionIsShown = GetCVar("raidOptionIsShown")
  end
  if GetCVar("raidOptionIsShown") == "1" then
    SetCVar("raidOptionIsShown", false)
  end
end

function BattleGroundEnemies:ToggleRaidFrames()
  if InCombatLockdown() then
    return self:QueueForUpdateAfterCombat(self, "ToggleRaidFrames")
  end
  if
    (BattleGroundEnemies.states.real.isInArena and self.db.profile.DisableRaidFramesInArena)
    or (BattleGroundEnemies.states.real.isInBattleground and self.db.profile.DisableRaidFramesInBattleground)
  then
    return disableRaidFrames()
  end

  restoreShowRaidFrameCVar()
end

function BattleGroundEnemies:UpdateArenaPlayers()
  self.Enemies:CreateArenaEnemies()

  local states = self:GetActiveStates()
  local mapId = states and states.currentMapId
  if IsObjectiveBG(mapId) then
    return
  end

  if #BattleGroundEnemies.Enemies.CurrentPlayerOrder > 0 or #BattleGroundEnemies.Allies.CurrentPlayerOrder > 0 then --this ensures that we checked for enemies and the flag carrier will be shown (if its an enemy)
    local desiredByArenaID = {}
    local numArenaOpponents = GetNumArenaOpponents()
    for i = 1, 15 do
      local unitID = "arena" .. i
      local fallbackButton
      for _, btn in ipairs(BattleGroundEnemies.Enemies.PlayerList) do
        if btn.PlayerDetails and btn.PlayerDetails.PlayerArenaUnitID == unitID then
          if btn.status == 1 then
            -- A combat-deferred source update can temporarily leave both the
            -- newly claimed row and a stale unclaimed duplicate in PlayerList.
            -- Prefer the row claimed by this rebuild; normal completed passes
            -- reset every active button to status 2 and use the fallback below.
            desiredByArenaID[unitID] = btn
            break
          end
          fallbackButton = fallbackButton or btn
        end
      end
      -- Blizzard's CompactArenaFrame falls back to the live opponent count
      -- when an arena has no prep-specialization roster. In that state BGE's
      -- scoreboard row has no structural PlayerArenaUnitID yet, so attach it
      -- by the same exact UnitName join used everywhere else in 12.1.
      if not desiredByArenaID[unitID] and not fallbackButton and i <= numArenaOpponents then
        fallbackButton = self:GetPlayerbuttonByUnitID(unitID, "Enemies")
      end
      desiredByArenaID[unitID] = desiredByArenaID[unitID] or fallbackButton
    end

    -- Capture the complete desired slot map before clearing stale bindings.
    -- In Solo Shuffle two existing buttons can swap arenaN slots in one source
    -- rebuild; clearing the first old binding also clears its mirrored
    -- PlayerArenaUnitID, so resolving and mutating one slot at a time would
    -- make the second button disappear from this pass.
    for i = 1, 15 do
      local unitID = "arena" .. i
      local previousButton = self.ArenaIDToPlayerButton[unitID]
      if previousButton and previousButton ~= desiredByArenaID[unitID] then
        self.ArenaIDToPlayerButton[unitID] = nil
        previousButton:UpdateEnemyUnitID("Arena", false)
        previousButton:DispatchEvent("ArenaOpponentHidden")
      end
    end

    for i = 1, 15 do
      local unitID = "arena" .. i
      local playerButton = desiredByArenaID[unitID]
      if playerButton then
        -- A stale binding cleared above may have erased this structural mirror
        -- while the button moved to a different slot. Restore the source-of-
        -- truth slot before rebuilding the secure binding.
        playerButton.PlayerDetails.PlayerArenaUnitID = unitID
        if i <= numArenaOpponents then
          playerButton:ArenaOpponentShown(unitID)
        elseif playerButton.SetBindings then
          -- Prep specialization data can build structural slots before the
          -- arena units exist. Keep the secure arenaN click attribute prepared
          -- without pretending that the unit is currently visible/live.
          playerButton:SetBindings()
        end
      end
    end
  elseif self.Enemies:ShouldBeEnabled() then
    -- Both player orders are empty. Only keep retrying while enemy frames are
    -- ENABLED for this bracket -- i.e. we're genuinely waiting for arena
    -- opponents to load. If enemies are disabled for the bracket (the
    -- ghost-frame gate tore the ArenaPlayers source down), both orders are
    -- empty BY DESIGN, and without this guard the C_Timer.After below would
    -- self-reschedule every second for the entire match.
    C_Timer.After(1, function()
      self:UpdateArenaPlayers()
    end)
  end
end

local UpdateArenaPlayersTicker

--too avoid calling UpdateArenaPlayers too many times within a second
function BattleGroundEnemies:DebounceUpdateArenaPlayers()
  if UpdateArenaPlayersTicker then
    UpdateArenaPlayersTicker:Cancel()
  end -- use a timer to apply changes after half second, this prevents from too many updates after each player is found

  if not self.states.real.isInArena and not self.states.real.isInBattleground then
    return
  end
  UpdateArenaPlayersTicker = CTimerNewTicker(0.5, function()
    BattleGroundEnemies:UpdateArenaPlayers()
    UpdateArenaPlayersTicker = nil
  end, 1)
end

function BattleGroundEnemies:CheckForArenaEnemies()
  -- returns valid data on PLAYER_ENTERING_WORLD
  if GetNumArenaOpponents() == 0 then
    C_Timer.After(2, function()
      self:DebounceUpdateArenaPlayers()
    end)
  else
    self:DebounceUpdateArenaPlayers()
  end
end

BattleGroundEnemies.PLAYER_UNGHOST = BattleGroundEnemies.PlayerAlive --player is alive again

function BattleGroundEnemies:GetBuffsAndDebuffsForMap(mapId)
  if not mapId then
    return
  end
  -- Returns only the Buffs table for the given map. The second-return
  -- (Debuffs) was dropped on 2026-05-02 — see GetBattlegroundAuras above
  -- for the migration rationale. Function name kept for source-history
  -- continuity even though it now returns just the buffs.
  return Data.BattlegroundspezificBuffs and Data.BattlegroundspezificBuffs[mapId]
end

function BattleGroundEnemies:UpdateMapID(retries)
  retries = retries or 0
  --	SetMapToCurrentZone() apparently removed in 8.0
  local mapId = C_Map.GetBestMapForUnit("player")

  if mapId and mapId ~= -1 and mapId ~= 0 then -- when this values occur the map ID is not real
    self.states.real.currentMapId = mapId
  else
    self.states.real.currentMapId = false
    if retries > 5 then
      return
    end
    C_Timer.After(2, function() --Delay this check, since its happening sometimes that this data is not ready yet
      self:UpdateMapID(retries + 1)
    end)
  end
end

-- #10a (UBS allocation): pool the per-row score tables so a 40-row epic lobby
-- tick reuses tables instead of allocating ~40 fresh ones every fire.
-- scoreRowPool[i] is the reusable table for scoreboard row i; parseBattlefieldScore
-- fills a caller-supplied `result` after nil-clearing every field. SCORE_ROW_FIELDS
-- is the EXHAUSTIVE field set (21 base PVPScoreInfo + 6 GetPlayerInfoByGUID), so the
-- clear is deterministic — a reused row whose guid is nil this tick can't leak the
-- prior occupant's localizedClass/sex/realmName onto the new button.
local scoreRowPool = {}
local SCORE_ROW_FIELDS = {
  "name",
  "guid",
  "killingBlows",
  "honorableKills",
  "deaths",
  "honorGained",
  "faction",
  "raceName",
  "className",
  "classToken",
  "damageDone",
  "healingDone",
  "rating",
  "ratingChange",
  "prematchMMR",
  "mmrChange",
  "postmatchMMR",
  "talentSpec",
  "honorLevel",
  "roleAssigned",
  "stats",
  -- GetPlayerInfoByGUID-derived (only written when guid resolves):
  "localizedClass",
  "englishClass",
  "localizedRace",
  "englishRace",
  "sex",
  "realmName",
}

local function parseBattlefieldScore(index, result)
  local scoreInfo = C_PvP.GetScoreInfo(index)
  if not scoreInfo then
    return
  end

  for fi = 1, #SCORE_ROW_FIELDS do
    result[SCORE_ROW_FIELDS[fi]] = nil
  end
  result.name = scoreInfo.name
  result.guid = scoreInfo.guid
  result.killingBlows = scoreInfo.killingBlows
  result.honorableKills = scoreInfo.honorableKills
  result.deaths = scoreInfo.deaths
  result.honorGained = scoreInfo.honorGained
  result.faction = scoreInfo.faction
  result.raceName = scoreInfo.raceName
  result.className = scoreInfo.className
  result.classToken = scoreInfo.classToken
  result.damageDone = scoreInfo.damageDone
  result.healingDone = scoreInfo.healingDone
  result.rating = scoreInfo.rating
  result.ratingChange = scoreInfo.ratingChange
  result.prematchMMR = scoreInfo.prematchMMR
  result.mmrChange = scoreInfo.mmrChange
  result.postmatchMMR = scoreInfo.postmatchMMR
  result.talentSpec = scoreInfo.talentSpec
  result.honorLevel = scoreInfo.honorLevel
  result.roleAssigned = scoreInfo.roleAssigned
  result.stats = scoreInfo.stats

  if not scoreInfo.guid then
    return result
  end

  local ok, localizedClass, englishClass, localizedRace, englishRace, sex, _, realmName =
    pcall(GetPlayerInfoByGUID, scoreInfo.guid)

  if ok then
    result.localizedClass = localizedClass
    result.englishClass = englishClass
    result.localizedRace = localizedRace
    result.englishRace = englishRace
    result.sex = sex
    result.realmName = realmName
  end

  return result
end

function BattleGroundEnemies:UpdateFriendlyScoreboardSpecs()
  if self.AllyFaction == nil or not self.Allies:ShouldBeEnabled() then
    return
  end

  for i = 1, GetNumBattlefieldScores() do
    local scoreInfo = C_PvP.GetScoreInfo(i)
    if scoreInfo and scoreInfo.faction == self.AllyFaction and type(scoreInfo.name) == "string" then
      local playerButton = self.Allies.Players[self:CanonicalName(scoreInfo.name)]
      local playerDetails = playerButton and playerButton.PlayerDetails
      local talentSpec = scoreInfo.talentSpec
      local hasTalentSpec = type(talentSpec) == "string"
      if hasTalentSpec and not (issecretvalue and issecretvalue(talentSpec)) then
        hasTalentSpec = talentSpec ~= ""
      end
      if playerDetails and hasTalentSpec then
        playerDetails.PlayerSpecNameScoreboard = talentSpec
        if playerButton.SpecName then
          playerButton.SpecName:SetSpec()
        end
      end
    end
  end
end


function BattleGroundEnemies:PVP_MATCH_STATE_CHANGED()
  local state = C_PvP.GetActiveMatchState()

  local function setLiveCCForAllRows(enabled)
    local mainframes = { self.Enemies, self.Allies }
    for i = 1, #mainframes do
      local mainframe = mainframes[i]
      if mainframe and mainframe.PlayerList then
        for j = 1, #mainframe.PlayerList do
          local playerButton = mainframe.PlayerList[j]
          local module = playerButton.SpecClassPriority
          if module then
            if not enabled then
              module:SetLiveCCUnit(nil)
            else
              local unitID = playerButton.unitID
              local playerName = unitID and self:GetCanonicalUnitName(unitID)
              local exactButton = playerName and mainframe.Players and mainframe.Players[playerName]
              if exactButton == playerButton then
                module:SyncLiveCCUnit(unitID, true)
              else
                module:SetLiveCCUnit(nil)
              end
            end
          end
        end
      end
    end
  end

  if state == Enum.PvPMatchState.Complete or state == Enum.PvPMatchState.Inactive then
    -- Clear cached trinket spells so stale data doesn't bleed into the next match.
    self._ccSpellCache = nil
  end

  if state == Enum.PvPMatchState.Engaged then
    self.betweenRounds = false
    -- Resume only rows whose current unit token still resolves to this exact
    -- player. Arena slot changes reconcile asynchronously after this event;
    -- mismatched rows stay unbound until that structural pass completes.
    setLiveCCForAllRows(true)
    -- UNIT_NAME_UPDATE is not documented to fire when the PvP name exception
    -- becomes available. Reconcile arenaN slots explicitly at gates-open so
    -- startup placeholders become exact Name-Realm rows immediately.
    if self.states.real.isInArena then
      self:CheckForArenaEnemies()
    end
    -- Refresh raid target icons — updates during the lobby were
    -- swallowed by the DispatchEvent block, so icons may be stale
    -- (e.g. a player swapped sides but kept their old marker).
    self:RAID_TARGET_UPDATE()
  elseif state == Enum.PvPMatchState.Complete or state == Enum.PvPMatchState.PostRound then
    self:UPDATE_BATTLEFIELD_SCORE()

    -- Harvest non-secret player identity from the now-readable scoreboard.
    -- SecretInActivePvPMatch only applies to StartUp/Engaged; PostRound
    -- and Complete return full PVPScoreInfo (talentSpec, roleAssigned,
    -- honorLevel, guid, ...) non-secret. PostRound runs every solo-shuffle
    -- round so leavers get captured before they vanish on Complete.
    --
    -- On Complete, clear the per-match harvest gate first so every player
    -- gets re-written with the freshest scoreboard data — and as a safety
    -- net for anyone PostRound had to skip (e.g. still-secret guid).
    if state == Enum.PvPMatchState.Complete then
      self._harvestedThisMatch = nil
    end
    self:HarvestPlayerHistory()

    if state == Enum.PvPMatchState.PostRound then
      -- Clear cached trinket spells so stale data from the previous round
      -- doesn't get applied to buttons that swap sides in solo shuffle.
      self._ccSpellCache = nil

      self:ResetAllDeadStates()
      self.betweenRounds = true
      setLiveCCForAllRows(false)
    else
      self:Disable()
    end
  elseif state == Enum.PvPMatchState.Inactive then
    self.betweenRounds = false
    -- New match coming. Clear the per-match harvest set so the next
    -- PostRound/Complete window can re-write entries (honorLevel, lastSpec,
    -- lastRole all evolve over time — let them refresh).
    self._harvestedThisMatch = nil
  end
end

-- Account-shared player identity harvest. Called from PVP_MATCH_STATE_CHANGED
-- on PostRound and Complete (non-secret scoreboard window). Idempotent within
-- a match via _harvestedThisMatch (cleared on Inactive). Reads survive across
-- sessions in db.global.PlayerHistory; pruned on PLAYER_LOGIN.
function BattleGroundEnemies:HarvestPlayerHistory()
  local db = self.db and self.db.global
  if not db then
    return
  end
  db.PlayerHistory = db.PlayerHistory or {}
  self._harvestedThisMatch = self._harvestedThisMatch or {}

  -- Force factionEnum -1 so GetNumBattlefieldScores / GetScoreInfo see
  -- BOTH teams. If the user (or Blizzard's PVPMatch UI) had a single-faction
  -- tab selected, our iteration would silently miss half the players.
  -- SetBattlefieldScoreFaction fires UBS synchronously; the existing UBS
  -- handler honors _reassertingScoreboard to avoid recursion.
  if self._scoreboardFaction ~= -1 then
    self._reassertingScoreboard = true
    self._scoreboardFaction = -1
    SetBattlefieldScoreFaction(-1)
    self._reassertingScoreboard = false
  end

  -- Retain the legacy auxiliary-history merge without putting those fields
  -- back into exact identity matching. A same-name button can contribute a
  -- value only if some independent path already supplied it; otherwise the
  -- existing saved entry and GetPlayerInfoByGUID fallbacks below remain.
  local nameToButton = {}
  for _, mf in ipairs({ self.Enemies, self.Allies }) do
    if mf and mf.Players then
      for nm, btn in pairs(mf.Players) do
        nameToButton[nm] = btn
      end
    end
  end

  local now = time()
  local numScores = GetNumBattlefieldScores()
  for i = 1, numScores do
    local scoreInfo = C_PvP.GetScoreInfo(i)
    local nameOk = scoreInfo
      and type(scoreInfo.name) == "string"
      and not (issecretvalue and issecretvalue(scoreInfo.name))
      and scoreInfo.classToken
      and type(scoreInfo.guid) == "string"
      and not (issecretvalue and issecretvalue(scoreInfo.guid))
      and scoreInfo.guid:match("^Player%-%d+%-[%dA-Fa-f]+$") ~= nil
    if nameOk then
      local key = self:CanonicalName(scoreInfo.name)
      if key and not self._harvestedThisMatch[key] then
        local existing = db.PlayerHistory[key] or {}

        local LEGACY_TO_MODERN_SEX = { [1] = 2, [2] = 0, [3] = 1 }
        local sex, realm, guild, powerType
        local btn = nameToButton[key]
        if btn and btn.PlayerDetails then
          local g = btn.PlayerDetails.gender
          if g and not (issecretvalue and issecretvalue(g)) then
            sex = g -- already modern enum
          end
          local gn = btn.PlayerDetails.GuildName
          -- `gn ~= nil` (not `if gn`) so `false` (confirmed guildless)
          -- is captured as a real value, not skipped as falsy.
          if gn ~= nil and not (issecretvalue and issecretvalue(gn)) then
            guild = gn
          end
          local pt = btn.PlayerDetails.lastPowerType
          if pt then
            powerType = pt
          end
        end
        -- GetPlayerInfoByGUID: realm always; sex only if button source
        -- didn't have it. Convert legacy → modern.
        if scoreInfo.guid and not (issecretvalue and issecretvalue(scoreInfo.guid)) then
          local ok, _, _, _, _, gpiSex, _, rl = pcall(GetPlayerInfoByGUID, scoreInfo.guid)
          if ok then
            -- realm is declared above; intentional realm-or-rl fallback, not uninitialized
            -- luacheck: ignore 321
            realm = realm or rl
            if not sex and gpiSex then
              sex = LEGACY_TO_MODERN_SEX[gpiSex] or gpiSex
            end
          end
        end

        -- `guild` may be `false` (confirmed guildless). Lua's `a or b`
        -- short-circuits on falsy values so `guild or existing.GuildName`
        -- would silently discard a `false` value. Use explicit nil check.
        local guildToStore
        if guild ~= nil then
          guildToStore = guild
        else
          guildToStore = existing.GuildName
        end
        db.PlayerHistory[key] = {
          name = key,
          guid = scoreInfo.guid,
          classToken = scoreInfo.classToken,
          raceName = scoreInfo.raceName,
          gender = sex or existing.gender,
          GuildName = guildToStore,
          lastPowerType = powerType or existing.lastPowerType,
          realmName = realm or existing.realmName,
          lastSpec = scoreInfo.talentSpec,
          lastRole = scoreInfo.roleAssigned,
          honorLevel = scoreInfo.honorLevel,
          seenCount = (existing.seenCount or 0) + 1,
          lastSeenAt = now,
        }
        self._harvestedThisMatch[key] = true
      end
    end
  end
end

function BattleGroundEnemies:HarvestRaidRoster()
  local db = self.db and self.db.global
  if not db then
    return
  end
  if not self:IsInPvPInstance() then
    return
  end
  db.PlayerHistory = db.PlayerHistory or {}

  local now = time()

  local function harvestUnit(unit)
    if not UnitExists(unit) then
      return
    end
    -- Real player characters only — skip pets, NPCs, vehicles.
    local isPlayer = UnitIsPlayer(unit)
    if not isPlayer then
      return
    end
    local guid = UnitGUID(unit)
    -- Real-player GUIDs are exactly "Player-{realmID}-{characterHex}". Bot
    -- GUIDs in comp stomp / Brawl have extra segments and would pollute
    -- PlayerHistory if accepted.
    if type(guid) ~= "string" or guid:match("^Player%-%d+%-[%dA-Fa-f]+$") == nil then
      return
    end

    -- Use the same canonical Name-Realm key as live row identity and
    -- HarvestPlayerHistory.
    local key = self:GetCanonicalUnitName(unit)
    if not key then
      return
    end

    local existing = db.PlayerHistory[key] or {}

    local _, classToken = UnitClassBase(unit)
    local raceName = UnitRace(unit) -- 1st return: localized; matches scoreboard.raceName
    if not classToken and not raceName then
      return
    end

    local gender = UnitSexBase(unit) -- modern enum (0=Male, 1=Female, 2=None); Nilable=true
    local honor = UnitHonorLevel(unit)
    local powerType = UnitPowerType(unit) -- numeric enum; MayReturnNothing

    local guildName = GetGuildInfo(unit)
    local guildToStore
    if guildName then
      guildToStore = guildName
    else
      guildToStore = false
    end

    local realm
    local okGpi, _, _, _, _, _, _, rl = pcall(GetPlayerInfoByGUID, guid)
    if okGpi and type(rl) == "string" and rl ~= "" then
      realm = rl
    end

    db.PlayerHistory[key] = {
      name = key,
      guid = guid,
      classToken = classToken or existing.classToken,
      raceName = raceName or existing.raceName,
      gender = gender or existing.gender,
      GuildName = guildToStore,
      lastPowerType = powerType or existing.lastPowerType,
      realmName = realm or existing.realmName,
      lastSpec = existing.lastSpec, -- raid source can't provide; preserve
      lastRole = existing.lastRole, -- bitmask format mismatch; preserve
      honorLevel = honor or existing.honorLevel,
      seenCount = existing.seenCount or 0, -- only end-of-match increments
      lastSeenAt = now,
    }
  end

  harvestUnit("player")
  if IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
      harvestUnit("raid" .. i)
    end
  elseif IsInGroup() then
    -- party1..N (excludes self; "player" was already harvested above)
    local n = (GetNumGroupMembers() or 0) - 1
    for i = 1, n do
      harvestUnit("party" .. i)
    end
  end
end

function BattleGroundEnemies:SetAllyFaction(allyFaction)
  local changed = self.AllyFaction ~= allyFaction
  self.EnemyFaction = allyFaction == 0 and 1 or 0
  self.AllyFaction = allyFaction
  if changed then
    if self.Enemies and self.Enemies.UpdatePlayerCountText then
      self.Enemies:UpdatePlayerCountText()
    end
    if self.Allies and self.Allies.UpdatePlayerCountText then
      self.Allies:UpdatePlayerCountText()
    end
  end
end

function BattleGroundEnemies:UPDATE_BATTLEFIELD_SCORE()
  -- Re-assert factionEnum -1 if the user (or Blizzard's PVPMatch UI) clicked
  -- a faction tab and filtered the scoreboard to one team — without -1 our
  -- GetNumBattlefieldScores / GetScoreInfo iteration would only see that
  -- team's rows. Skip while the user is actively looking at the scoreboard
  -- so we don't yank their tab view out from under them; the next UBS tick
  -- after they close it will re-assert.
  local scoreboardShown = (PVPMatchScoreboard and PVPMatchScoreboard:IsShown())
    or (PVPMatchResults and PVPMatchResults:IsShown())
  -- Hard re-entry guard: SetBattlefieldScoreFaction fires UPDATE_BATTLEFIELD_SCORE
  -- synchronously (plus Blizzard's scoreboard UI updates may also fire UBS
  -- mid-call). Without this, we recurse infinitely:
  -- handler → SetFaction → UBS → handler → SetFaction → ... stack overflow.
  if self._reassertingScoreboard then
    return
  end
  if not scoreboardShown then
    if self._scoreboardFaction ~= -1 then
      self._reassertingScoreboard = true
      self._scoreboardFaction = -1
      SetBattlefieldScoreFaction(-1)
      self._reassertingScoreboard = false
      return
    end
  end

  if self.AllyFaction == nil then
    if not self._pvpGracePeriodElapsed then
      return
    end

    local ok, myInfo = pcall(C_PvP.GetScoreInfoByPlayerGuid, UnitGUID("player"))
    if
      ok
      and myInfo
      and myInfo.faction ~= nil
      and type(myInfo.name) == "string"
      and not (issecretvalue and issecretvalue(myInfo.name))
    then
      local raidNames = nil
      if IsInRaid() then
        raidNames = {}
        for i = 1, GetNumGroupMembers() or 0 do
          local memberName = GetRaidRosterInfo(i)
          if
            type(memberName) == "string"
            and not (issecretvalue and issecretvalue(memberName))
            and memberName ~= myInfo.name
          then
            raidNames[memberName] = true
          end
        end
      end

      if raidNames and next(raidNames) then
        local REQUIRED_PEERS = 2
        local agreed = 0
        for i = 1, GetNumBattlefieldScores() do
          local row = C_PvP.GetScoreInfo(i)
          if row and type(row.name) == "string" and row.faction ~= nil and raidNames[row.name] then
            if row.faction == myInfo.faction then
              agreed = agreed + 1
              if agreed >= REQUIRED_PEERS then
                self:SetAllyFaction(myInfo.faction)
                break
              end
            else
              -- Disagreement: at least one peer says different team.
              -- Don't commit; retry next tick.
              break
            end
          end
        end
      end
    end
  end

  -- If still unknown (scoreboard not populated, or no peer to validate
  -- against yet), bail. Empty enemy panel for one or more ticks is the
  -- explicit, deliberate behavior — never show real teammates as enemies.
  if self.AllyFaction == nil then
    return
  end

  -- This must run before the enemy-only enable/count gates below. Friendly
  -- specs can arrive without any enemy roster-count change.
  self:UpdateFriendlyScoreboardSpecs()

  local _, _, _, _, numEnemies = GetBattlefieldTeamInfo(self.EnemyFaction)

  if numEnemies then
    self.Enemies:SetRealPlayerCount(numEnemies)
  end

  if not self.Enemies:ShouldBeEnabled() then
    if not self.Enemies._disabledTeardownDone then
      self.Enemies:RemoveAllPlayersFromAllSources()
      self._lastEnemyCount = nil
      self.Enemies._disabledTeardownDone = true
    end
    return
  end
  self.Enemies._disabledTeardownDone = nil

  if numEnemies and self._lastEnemyCount == numEnemies then
    return
  end
  self._lastEnemyCount = numEnemies

  BattleGroundEnemies.Enemies:BeforePlayerSourceUpdate(self.consts.PlayerSources.Scoreboard)

  wipe(BattleGroundEnemies.scoreboardSpecByName)

  local numScores = GetNumBattlefieldScores()
  for i = 1, numScores do
    local row = scoreRowPool[i]
    if not row then
      row = {}
      scoreRowPool[i] = row
    end
    local score = parseBattlefieldScore(i, row)
    -- parseBattlefieldScore returns nil (NOT `row`) when GetScoreInfo has no data
    -- for a stale index, so a nil `score` is skipped.
    if score and score.faction and score.name and score.classToken then
      if score.faction == self.EnemyFaction then
        BattleGroundEnemies.Enemies:AddPlayerToSource(self.consts.PlayerSources.Scoreboard, score)
      elseif score.faction == self.AllyFaction then
        -- Key = non-secret name; value = talentSpec (secret mid-match, stored as a
        -- pure pass-through). Read back in AddGroupMember without any evaluation.
        BattleGroundEnemies.scoreboardSpecByName[self:CanonicalName(score.name)] = score.talentSpec
      end
    end
  end

  BattleGroundEnemies.Enemies:AfterPlayerSourceUpdate()

  local allySpecCount = 0
  for _ in pairs(BattleGroundEnemies.scoreboardSpecByName) do
    allySpecCount = allySpecCount + 1
  end
  local grew = allySpecCount > (self._allySpecCount or 0)
  self._allySpecCount = allySpecCount
  if grew and self.GROUP_ROSTER_UPDATE then
    self:GROUP_ROSTER_UPDATE()
  end

  if self.RefreshObjectiveCarriers then
    self:RefreshObjectiveCarriers()
  end
end

function BattleGroundEnemies:GROUP_ROSTER_UPDATE()
  local _, instanceType = IsInInstance()
  if instanceType ~= "pvp" and instanceType ~= "arena" and not self:IsTestmodeActive() then
    return
  end
  self.Allies:BeforePlayerSourceUpdate(self.consts.PlayerSources.GroupMembers)
  self.Allies.groupLeader = nil
  self.Allies.assistants = {}

  --IsInGroup returns true when user is in a Raid and In a 5 man group

  -- GetRaidRosterInfo also works when in a party (not raid) but i am not 100% sure how the party unitID maps to the index in GetRaidRosterInfo()

  local numGroupMembers = GetNumGroupMembers()
  self.Allies:SetRealPlayerCount(numGroupMembers)

  local addedCount = 0

  -- Capture the user's own raid role so we can pass it to the explicit
  -- self-add below (the raid loop skips self, but GetRaidRosterInfo is
  -- the only source for raid-assigned MAINTANK / MAINASSIST).
  local selfRaidRole = nil

  local buildAllies = self.Allies:ShouldBeEnabled()

  if buildAllies then
    if IsInRaid() then
      for i = 1, numGroupMembers do -- the player itself only shows up here when he is in a raid
        local name, rank, _, _, _, classToken, _, _, _, role, _, _ = GetRaidRosterInfo(i)

        -- Canonicalize the GetRaidRosterInfo name so it can be compared with
        -- UserDetails.PlayerName (canonical post-refactor). For same-realm
        -- members (always true for the user themselves) GetRaidRosterInfo
        -- returns short "Name"; UserDetails.PlayerName is "Name-Realm". The
        -- old direct compare would have silently missed self-identification
        -- after the canonicalization refactor.
        if type(name) == "string" and self:CanonicalName(name) == self.UserDetails.PlayerName then
          selfRaidRole = role
        elseif type(name) == "string" and rank and classToken then
          -- `role` is the 10th return: "MAINTANK", "MAINASSIST", or "" for
          -- regular members. Pass it through so the sort comparator can
          -- put MT/MA tiers before plain TANK.
          self.Allies:AddGroupMember(name, rank == 2, rank == 1, classToken, "raid" .. i, role)
          addedCount = addedCount + 1
        end
      end
    else
      -- we are in a party, 5 man group — no raid-assigned roles exist here.
      for i = 1, numGroupMembers do
        local unitID = "party" .. i
        local name = self:GetCanonicalUnitName(unitID)

        local classToken = select(2, UnitClass(unitID))

        if type(name) == "string" and classToken then
          self.Allies:AddGroupMember(name, UnitIsGroupLeader(unitID), UnitIsGroupAssistant(unitID), classToken, unitID)
          addedCount = addedCount + 1
        end
      end
    end
  end

  self.UserDetails.isGroupLeader = UnitIsGroupLeader("player")
  self.UserDetails.isGroupAssistant = UnitIsGroupAssistant("player")
  if buildAllies then
    self.Allies:AddGroupMember(
      self.UserDetails.PlayerName,
      self.UserDetails.isGroupLeader,
      self.UserDetails.isGroupAssistant,
      self.UserDetails.PlayerClass,
      "player",
      selfRaidRole
    )
  end
  self.Allies:AfterPlayerSourceUpdate()
  self.Allies:UpdateAllUnitIDs()

  -- The roster can build after the latest scoreboard event. Fill any newly
  -- created friendly buttons immediately from the current scoreboard rows.
  self:UpdateFriendlyScoreboardSpecs()

  -- unitIDs are now assigned — refresh raid target icons on ally buttons
  if self.Allies.Players then
    for _, allyButton in pairs(self.Allies.Players) do
      allyButton:UpdateRaidTargetIcon()
    end
  end

  -- unitIDs are now assigned — refresh trinket icons if we're in an arena.
  _, instanceType = IsInInstance()
  if instanceType == "arena" then
    self:ARENA_COOLDOWNS_UPDATE()
  end

  local actualAllies = 0
  for _ in pairs(self.Allies.Players or {}) do
    actualAllies = actualAllies + 1
  end
  if buildAllies and actualAllies < numGroupMembers and not self.betweenRounds then
    if not self.allyRosterRetryTimer then
      local retries = 0
      self.allyRosterRetryTimer = C_Timer.NewTicker(1, function()
        retries = retries + 1
        self:GROUP_ROSTER_UPDATE()
        -- The recursive call may have already cancelled the timer (all members found),
        -- so guard before accessing it again.
        if self.allyRosterRetryTimer and retries >= 30 then
          self.allyRosterRetryTimer:Cancel()
          self.allyRosterRetryTimer = nil
        end
      end)
    end
  else
    -- All members found, cancel any pending retry
    if self.allyRosterRetryTimer then
      self.allyRosterRetryTimer:Cancel()
      self.allyRosterRetryTimer = nil
    end
  end

  if self.HarvestRaidRoster then
    self:HarvestRaidRoster()
  end
end

BattleGroundEnemies.PARTY_LEADER_CHANGED = BattleGroundEnemies.GROUP_ROSTER_UPDATE

function BattleGroundEnemies:PLAYER_ENTERING_WORLD()

  if self.states.testmodeActive then
    self:DisableTestMode()
  end

  wipe(self.ArenaIDToPlayerButton)
  self.Enemies:RemoveAllPlayersFromAllSources()
  self._lastEnemyCount = nil

  local prevInstanceType = self.cachedInstanceType
  local _, zone = IsInInstance()
  self.cachedInstanceType = zone

  local enteringPvP = (zone == "pvp" or zone == "arena") and prevInstanceType ~= zone
  local leavingPvP = (prevInstanceType == "pvp" or prevInstanceType == "arena") and zone ~= prevInstanceType
  if enteringPvP or leavingPvP then
    self.AllyFaction = nil
    self.EnemyFaction = nil
    if self._pvpGraceTimer then
      self._pvpGraceTimer:Cancel()
      self._pvpGraceTimer = nil
    end
    self._pvpGracePeriodElapsed = false
    if enteringPvP then
      self._pvpGraceTimer = C_Timer.NewTimer(3, function()
        self._pvpGracePeriodElapsed = true
        self._pvpGraceTimer = nil
      end)
      self.Allies._warnedNoCustomProfile = nil
      self.Enemies._warnedNoCustomProfile = nil
    end
  end

  if zone == "pvp" or zone == "arena" then
    if zone == "arena" then
      BattleGroundEnemies.states.real.isInArena = true
      self:ARENA_COOLDOWNS_UPDATE()
    else
      BattleGroundEnemies.states.real.isInBattleground = true

      C_Timer.After(5, function() --Delay this check, since its happening sometimes that this data is not ready yet
        if C_PvP then
          self.states.real.isRatedBG = not not C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground()
          self.states.real.isSoloRBG = not not C_PvP.IsSoloRBG and C_PvP.IsSoloRBG()
        else
          self.states.real.isRatedBG = not not IsRatedBattleground and IsRatedBattleground()
          self.states.real.isSoloRBG = false
        end

        self:UPDATE_BATTLEFIELD_SCORE() --trigger the function again because since 10.0.0 UPDATE_BATTLEFIELD_SCORE doesnt fire reguralry anymore and RequestBattlefieldScore doesnt trigger the event
        self.Allies:SelectPlayerCountProfile(true)
        self:GROUP_ROSTER_UPDATE()
      end)
    end
  else
    self.states.real.isInArena = false
    self.states.real.isInBattleground = false
    self.states.real.isSoloRBG = false
    self.states.real.isRatedBG = false
    self.Enemies:SelectPlayerCountProfile(true)
    self.Allies:SelectPlayerCountProfile(true)
  end

  self:CheckEnableState()
  self:UpdateMapID()
  self:ToggleArenaFrames()
  self:ToggleRaidFrames()
end
