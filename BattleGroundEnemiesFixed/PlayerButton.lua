---@class Data
local Data = select(2, ...)

---@class BattleGroundEnemies
local BattleGroundEnemies = BattleGroundEnemies

-- Priority order for the active-unitID election in UpdateEnemyUnitID.
-- MUST match the tier order documented in TOKEN_TIERS.md: direct tokens
-- (evented) first, compound/through-unit tokens (poll-only) last.
local UNITID_PRIORITY_KEYS = {
  "Arena",
  "Target",
  "Focus",
  "Nameplate",
  "SoftEnemy",
  "Mouseover",
  "TargetTarget",
  "FocusTarget",
  "PetTarget",
  "GroupTarget",
  "GroupPetTarget",
  "NameplateTarget",
  "ArenaTarget",
}

local FAKE_TRINKET = true
local FAKE_TRINKET_DURATION = 120 -- DPS / Tank
local FAKE_TRINKET_HEALER_DURATION = 90 -- Healer (30s reduction)
local FAKE_TRINKET_SPELL = 208683 -- Gladiator's Medallion (for icon texture)

local C_PvP = C_PvP
local CreateFrame = CreateFrame
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local RequestCrowdControlSpell = C_PvP.RequestCrowdControlSpell
local UnitExists = UnitExists
local UnitInRange = UnitInRange
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsVisible = UnitIsVisible
local CheckInteractDistance = CheckInteractDistance
local C_Item = C_Item
local C_Spell = C_Spell

--lua
local math_floor = math.floor
local math_random = math.random
local pairs = pairs
local table_insert = table.insert
local type = type
local unpack = unpack

local InCombatLockdownRestriction = function(unit)
  return InCombatLockdown() and not UnitCanAttack("player", unit)
end

local dragController = CreateFrame("Frame")
dragController.target = nil

local function dragOnUpdate(self)
  local target = self.target
  if not target then
    self:SetScript("OnUpdate", nil)
    return
  end
  if InCombatLockdown() then
    -- SetPoint on a protected frame is blocked in combat. Freeze in place
    -- and let the next tick try again once combat ends.
    return
  end
  local cx, cy = GetCursorPosition()
  local scale = target:GetEffectiveScale()
  local dx = (cx - self.startCursorX) / scale
  local dy = (cy - self.startCursorY) / scale
  target:ClearAllPoints()
  target:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.startLeft + dx, self.startTop + dy)
end

local function beginDrag(target)
  if not target then
    return false
  end
  if InCombatLockdown() then
    -- SetPoint is blocked anyway, so don't even start.
    return false
  end
  local left, top = target:GetLeft(), target:GetTop()
  if not left or not top then
    return false
  end
  dragController.target = target
  dragController.startCursorX, dragController.startCursorY = GetCursorPosition()
  dragController.startLeft = left
  dragController.startTop = top
  dragController:SetScript("OnUpdate", dragOnUpdate)
  return true
end

local function endDrag()
  dragController:SetScript("OnUpdate", nil)
  local target = dragController.target
  dragController.target = nil
  return target
end

--Libs
local LRC = LibStub("LibRangeCheck-3.0")

-- One baseline harm spell per class for C_Spell.IsSpellInRange.
-- Format: { spellID, range_yards }
-- Ordered shortest range to longest range in comments.
local classHarmSpells = {
  ROGUE = { 2094, 15 }, -- Blind (15y)
  EVOKER = { 361469, 25 }, -- Living Flame (25y)
  WARRIOR = { 57755, 30 }, -- Heroic Throw (30y)
  PALADIN = { 20271, 30 }, -- Judgment (30y)
  DEATHKNIGHT = { 47541, 30 }, -- Death Coil (30y)
  DEMONHUNTER = { 185123, 30 }, -- Throw Glaive (30y)
  HUNTER = { 185358, 40 }, -- Arcane Shot (40y)
  MAGE = { 116, 40 }, -- Frostbolt (40y)
  WARLOCK = { 686, 40 }, -- Shadow Bolt (40y)
  PRIEST = { 585, 40 }, -- Smite (40y)
  SHAMAN = { 188196, 40 }, -- Lightning Bolt (40y)
  DRUID = { 8921, 40 }, -- Moonfire (40y)
  MONK = { 117952, 40 }, -- Crackling Jade Lightning (40y)
}

-- Helper 1: CheckInteractDistance (out of combat only, shortest to longest)
-- Index 2 = Trade (11y), Index 1 = Inspect (28y), Index 4 = Follow (28y)
local function checkInteractDist(unitID)
  if InCombatLockdownRestriction(unitID) then
    return false
  end
  if not CheckInteractDistance then
    return false
  end
  local s2, r2 = pcall(CheckInteractDistance, unitID, 2) -- Trade (11y)
  if s2 and r2 then
    return true
  end
  local s1, r1 = pcall(CheckInteractDistance, unitID, 1) -- Inspect (28y)
  if s1 and r1 then
    return true
  end
  local s4, r4 = pcall(CheckInteractDistance, unitID, 4) -- Follow (28y)
  if s4 and r4 then
    return true
  end
  return false
end

-- Helper 2: C_Item.IsItemInRange (works in/out of combat, shortest to longest)
-- Ley Spider Eggs (38y), Haunting Memento (50y)
local function isItemInRange(unitID)
  if InCombatLockdownRestriction(unitID) then
    return false
  end
  if not C_Spell or not C_Spell.IsItemInRange then
    return false
  end
  local r1 = C_Item.IsItemInRange(140786, unitID) -- Ley Spider Eggs (38y)
  if r1 then
    return true
  end
  local r2 = C_Item.IsItemInRange(116139, unitID) -- Haunting Memento (50y)
  if r2 then
    return true
  end
  return false
end

-- Helper 3: C_Spell.IsSpellInRange (class-specific harm spell)
-- Pass the player's class token (e.g. "MAGE") from PlayerDetails.PlayerClass.
local function isSpellInRange(unitID, myClass)
  if not C_Spell or not C_Spell.IsSpellInRange then
    return false
  end
  if not myClass then
    return false
  end
  local spellData = classHarmSpells[myClass]
  if not spellData then
    return false
  end
  local result = C_Spell.IsSpellInRange(spellData[1], unitID)
  if result then
    return true
  end
  return false
end

function BattleGroundEnemies:CreatePlayerButton(mainframe, num)

  local isEnemyButton = mainframe.PlayerType == BattleGroundEnemies.consts.PlayerTypes.Enemies
  local playerButton = CreateFrame(
    "Button",
    "BattleGroundEnemies" .. mainframe.PlayerType .. "frame" .. num,
    mainframe,
    isEnemyButton and "SecureActionButtonTemplate" or "SecureUnitButtonTemplate"
  )
  playerButton:RegisterForClicks("AnyUp")
  if isEnemyButton then
    playerButton:SetAttribute("useOnKeyDown", false)
  end
  playerButton:SetPropagateMouseMotion(true) --to send the mouse wheel event to the other frame behind it (the mainframe)
  playerButton:Hide()

  -- Retain the existing click-intent stash for now. Exact UnitName resolution
  -- owns identity in 12.1; removal of this older bookkeeping is deferred.
  playerButton:SetScript("PostClick", function(self, mouseButton)
    if not self.PlayerIsEnemy or not self.config then
      return
    end
    local bindingType = self.config[(mouseButton or "") .. "Type"]
    if bindingType == "Target" then
      BattleGroundEnemies._lastClickedEnemyTarget = self
      BattleGroundEnemies._lastClickedEnemyTargetTime = GetTime()
    elseif bindingType == "Focus" then
      BattleGroundEnemies._lastClickedEnemyFocus = self
      BattleGroundEnemies._lastClickedEnemyFocusTime = GetTime()
    end
  end)

  -- setmetatable(playerButton, self)
  -- self.__index = self

  playerButton.ButtonEvents = playerButton.ButtonEvents or {}

  playerButton.PlayerType = mainframe.PlayerType
  playerButton.PlayerIsEnemy = playerButton.PlayerType == BattleGroundEnemies.consts.PlayerTypes.Enemies
  playerButton.MainFrame = mainframe
  playerButton.UnitIDs = { TargetedByEnemy = {} }

  playerButton:SetScript("OnSizeChanged", function(self, width, height)
    --self.DRContainer:SetWidthOfAuraFrames(height)
    self:DispatchEvent("PlayerButtonSizeChanged", width, height)
  end)

  function playerButton:GetOppositeMainFrame()
    if self.PlayerType == BattleGroundEnemies.consts.PlayerTypes.Enemies then
      return BattleGroundEnemies.Allies
    else
      return BattleGroundEnemies.Enemies
    end
  end

  function playerButton:OnDragStart()
    if BattleGroundEnemies.db.profile.Locked then
      return
    end
    beginDrag(self:GetParent())
  end

  function playerButton:OnDragStop()
    local parent = endDrag() or self:GetParent()
    if not parent then
      return
    end

    local scale = self:GetEffectiveScale()

    local growDownwards = (self.playerCountConfig.BarVerticalGrowdirection == "downwards")
    local growRightwards = (self.playerCountConfig.BarHorizontalGrowdirection == "rightwards")

    if growDownwards then
      self.playerCountConfig.Position_Y = parent:GetTop() * scale
    else
      self.playerCountConfig.Position_Y = parent:GetBottom() * scale
    end

    if growRightwards then
      self.playerCountConfig.Position_X = parent:GetLeft() * scale
    else
      self.playerCountConfig.Position_X = parent:GetRight() * scale
    end
  end

  function playerButton:UpdateAll(temporaryUnitID, skipSnapshot)
    local updateStuffWithEvents = false --only update health, power, etc for players that dont get events for that or that dont have a unitID assigned
    local unitID
    -- local updateAuras = false
    if temporaryUnitID then
      updateStuffWithEvents = true
      unitID = temporaryUnitID
      -- updateAuras = true
    else
      if self.unitID then
        unitID = self.unitID
        -- For ally buttons: always update health/power (unrestricted party/raid access)
        -- For enemy buttons with ally unitID: also update (tracked via ally target chain)
        if (not self.PlayerIsEnemy) or self.UnitIDs.HasAllyUnitID then
          updateStuffWithEvents = true
        end
      end
    end
    if not unitID then
      return
    end

    if not UnitExists(unitID) then
      return
    end

    if updateStuffWithEvents then
      if (temporaryUnitID or not self.PlayerIsEnemy) and not skipSnapshot then
        self:UNIT_POWER_FREQUENT(unitID)
        self:UNIT_HEALTH(unitID)
      end
    end

    self:UpdateRaidTargetIcon()
    self:UpdateRangeViaLibRangeCheck(unitID)
    self:UpdateTarget()
    self:DispatchEvent("PeriodicUpdate", unitID)
  end

  function playerButton:GetSpecData()
    if not self.PlayerDetails then
      return
    end
    local class = self.PlayerDetails.PlayerClass
    local spec = self.PlayerDetails.PlayerSpecName
    if class and spec and not (issecretvalue and (issecretvalue(class) or issecretvalue(spec))) then
      local t = Data.Classes[class]
      if t then
        t = t[spec]
        return t
      end
    end
  end

  function playerButton:PlayerDetailsChanged()
    self:SetBindings()
    self:ApplyModuleSettings()
  end

  function playerButton:UpdateRaidTargetIcon(forceIndex)
    if self.PlayerIsEnemy and BattleGroundEnemies.states.real.isInArena and not forceIndex then
      if self.RaidTargetIconIndex then
        self.RaidTargetIconIndex = nil
        self:DispatchEvent("UpdateRaidTargetIcon", nil)
      end
      return
    end

    local unit = self:GetUnitID()
    local newIndex = forceIndex --used for testmode, otherwise it will just be nil and overwritten when one actually exists
    if unit then
      newIndex = GetRaidTargetIndex(unit)
      if newIndex and not issecretvalue(newIndex) then
        if newIndex == 8 and (not self.RaidTargetIconIndex or self.RaidTargetIconIndex ~= 8) then
          -- Skull icon (8) is the target calling marker
          if
            BattleGroundEnemies:GetActiveStates().isRatedBG
            and BattleGroundEnemies.db.profile.RBG.TargetCalling_NotificationEnable
          then
            local LSM = LibStub("LibSharedMedia-3.0")
            local path = LSM:Fetch("sound", BattleGroundEnemies.db.profile.RBG.TargetCalling_NotificationSound, true)
            if path then
              PlaySoundFile(path, "Master")
            end
          end
        end
      end
    end
    self.RaidTargetIconIndex = newIndex
    self:DispatchEvent("UpdateRaidTargetIcon", self.RaidTargetIconIndex)
  end

  function playerButton:UpdateCrowdControlCooldown(unitID)
    -- Get spell ID from GetArenaCrowdControlInfo (only need the first return value)
    local spellId = C_PvP.GetArenaCrowdControlInfo(unitID)
    -- Get duration as a LuaDurationObject — no secret value arithmetic needed
    local durationObj = C_PvP.GetArenaCrowdControlDuration and C_PvP.GetArenaCrowdControlDuration(unitID)

    if not self.Trinket or not spellId then
      return false
    end

    self.Trinket:ResetFakeCooldown()
    self.Trinket:DisplayTrinket(spellId)

    if durationObj then
      self.Trinket:SetAlphaFromBoolean(durationObj:IsZero(), 0, 1)

      if self.Trinket.Cooldown.SetCooldownFromDurationObject then
        -- clearIfZero defaults to true — cooldown swipe clears when duration is zero
        self.Trinket.Cooldown:SetCooldownFromDurationObject(durationObj)
      end
      return true
    end
    return false
  end

  function playerButton:UpdateAllyCrowdControlCooldown(unitID)
    if not self.Trinket or not C_PvP.GetArenaCrowdControlDuration then
      return
    end
    local durationObj = C_PvP.GetArenaCrowdControlDuration(unitID)
    if durationObj then
      self.Trinket:ResetFakeCooldown()
      -- We don't know the ally's trinket spell ahead of time; DisplayTrinket(nil) shows
      -- the Gladiator's Medallion fallback icon (see Trinket.lua DisplayTrinket logic).
      self.Trinket:DisplayTrinket(nil)
      if self.Trinket.Cooldown.SetCooldownFromDurationObject then
        -- clearIfZero defaults to true, so zero-span objects are handled automatically
        self.Trinket.Cooldown:SetCooldownFromDurationObject(durationObj)
      end
    end
  end

  -- Called when the API is unavailable but we know a trinket was used
  -- (e.g. ARENA_CROWD_CONTROL_SPELL_UPDATE fired but GetArenaCrowdControlInfo
  -- returned no real cooldown data). Uses estimated durations.
  function playerButton:ApplyFakeTrinketCooldown()
    if not FAKE_TRINKET or not self.Trinket then
      return
    end
    local duration = FAKE_TRINKET_DURATION
    local specData = self:GetSpecData()
    if specData and specData.roleID == "HEALER" then
      duration = FAKE_TRINKET_HEALER_DURATION
    end
    self.Trinket:DisplayTrinket(FAKE_TRINKET_SPELL)
    self.Trinket:StartFakeCooldown(duration)
  end

  function playerButton:UpdateUnitID(unitID, targetUnitID, skipSnapshot, residualElection)
    -- For allies: always set unitID even if unit doesn't exist yet (party/raid units may be loading)
    -- For enemies: only proceed if unit exists (requires active target/nameplate/arena token)
    if self.PlayerIsEnemy and not UnitExists(unitID) then
      return
    end

    local previousUnitID = self.unitID
    self.unitID = unitID
    self.TargetUnitID = targetUnitID
    if self.SpecClassPriority then
      -- Bind only exact matcher-verified direct tokens here. Compound target
      -- chains are reconciled separately after their scan has settled.
      local isCompoundEnemyToken = self.SpecClassPriority:IsCompoundLiveCCUnit(unitID)
      if not isCompoundEnemyToken and (not skipSnapshot or previousUnitID ~= unitID) then
        -- A residual direct token (Arena -> Target, Target -> Focus, etc.) can
        -- be validated exactly now that UnitName is available; do not wait for
        -- another event that may never arrive. skipSnapshot still protects the
        -- health/power read below, independently of secure CC identity.
        self.SpecClassPriority:SyncLiveCCUnit(unitID, true)
      elseif isCompoundEnemyToken and (previousUnitID ~= unitID or residualElection) then
        self.SpecClassPriority:SetLiveCCUnit(nil)
      end
    end
    self:UpdateRaidTargetIcon()

    -- Only call UpdateAll if unit actually exists (UpdateAll checks UnitExists anyway).
    -- skipSnapshot suppresses the UNIT_HEALTH/UNIT_POWER_FREQUENT snapshot
    -- inside UpdateAll when the unitID is a residual chain pick (see the
    -- caller in UpdateEnemyUnitID).
    if UnitExists(unitID) then
      self:UpdateAll(unitID, skipSnapshot)
    end

    self:DispatchEvent("UnitIdUpdate", unitID)
  end

  function playerButton:SetModuleConfig(moduleName)
    local moduleFrameOnButton = self[moduleName]
    local moduleConfigOnButton = {}

    if not self.playerCountConfig then
      return
    end

    local playerSizeModuleConfig = self.playerCountConfig.ButtonModules[moduleName]

    local globalModuleConfig = BattleGroundEnemies.db.profile.ButtonModules[moduleName] or {}

    Mixin(moduleConfigOnButton, globalModuleConfig, playerSizeModuleConfig)

    if moduleConfigOnButton.Enabled and BattleGroundEnemies:IsModuleEnabledOnThisExpansion(moduleName) then
      moduleFrameOnButton.Enabled = true
    else
      moduleFrameOnButton.Enabled = false
    end
    moduleFrameOnButton.config = moduleConfigOnButton
  end

  function playerButton:SetAllModuleConfigs()
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      self:SetModuleConfig(moduleName)
    end
  end

  function playerButton:CallExistingFuncOnAllButtonModuleFrames(funcName, ...)
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]
      if moduleFrameOnButton then
        if moduleFrameOnButton and type(moduleFrameOnButton[funcName]) == "function" then
          moduleFrameOnButton[funcName](moduleFrameOnButton, ...)
        end
      end
    end
  end

  function playerButton:CallExistingFuncOnAllEnabledButtonModuleFrames(funcName, ...)
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]
      if moduleFrameOnButton then
        if moduleFrameOnButton.Enabled then
          if type(moduleFrameOnButton[funcName]) == "function" then
            moduleFrameOnButton[funcName](moduleFrameOnButton, ...)
          end
        end
      end
    end
  end

  function playerButton:CallFuncOnAllButtonModuleFrames(func)
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]
      if moduleFrameOnButton then
        func(self, moduleFrameOnButton)
      end
    end
  end

  function playerButton:CallFuncOnAllEnabledButtonModuleFrames(func)
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]
      if moduleFrameOnButton then
        if moduleFrameOnButton.Enabled then
          func(self, moduleFrameOnButton)
        end
      end
    end
  end

  function playerButton:DeleteActiveUnitID() --Delete from OnUpdate
    if not self.PlayerIsEnemy then
      return
    end
    self.unitID = nil
    if self.SpecClassPriority then
      self.SpecClassPriority:SetLiveCCUnit(nil)
    end
    -- Don't reset healthBar / healthBarText here. They each already do the
    -- right thing on nil/missing values: healthBar:UpdateHealth returns
    -- early without clobbering ([HealthBar.lua] "don't clobber the bar —
    -- keep prior values"), and container:UpdateHealthText returns early
    -- without hiding (per the v67 fix). Explicitly resetting to full/0
    -- here was the source of the bar-jumps-to-full visual on token loss.
    -- isDead transitions to 0 already happen via UNIT_HEALTH's dead path,
    -- so the bar is already at 0 before DeleteActiveUnitID runs in that case.
    self.TargetUnitID = nil
    self:UpdateRange(false)

    if self.Target then
      self:IsNoLongerTarging(self.Target)
    end

    self.UnitIDs.HasAllyUnitID = false

    self:DispatchEvent("UnitIdUpdate")
  end

  -- residualReassign: set by the Remove*Target re-pick paths (Mainframe.lua).
  -- Their `value` is recycled from an EARLIER tick's map entry, not verified
  -- against this button right now — treat it like a residual pick and skip
  -- the immediate health/power snapshot even though value == chain pick.
  function playerButton:UpdateEnemyUnitID(key, value, residualReassign)
    if not self.PlayerIsEnemy then
      return
    end
    if self.PlayerDetails.isFakePlayer then
      return
    end
    local unitIDs = self.UnitIDs
    if key then
      unitIDs[key] = value
    end

    if key == "Arena" and self.PlayerDetails then
      self.PlayerDetails.PlayerArenaUnitID = value or nil
      if self.SetBindings then
        self:SetBindings()
      end
    end

    local unitID
    for i = 1, #UNITID_PRIORITY_KEYS do
      local candidate = unitIDs[UNITID_PRIORITY_KEYS[i]]
      if candidate and UnitExists(candidate) then
        unitID = candidate
        break
      end
    end
    if unitID then
      unitIDs.HasAllyUnitID = false
      local skipSnapshot = value ~= unitID or residualReassign == true
      local residualElection = residualReassign == true and value == unitID
      self:UpdateUnitID(unitID, unitID .. "target", skipSnapshot, residualElection)
    elseif unitIDs.Ally then
      unitIDs.HasAllyUnitID = true
      -- Direct ally token map.
      local allyButton = BattleGroundEnemies.Allies:GetAllyButtonByUnitID(unitIDs.Ally)
      if allyButton and allyButton == self then
        self:UpdateUnitID(unitIDs.Ally, unitIDs.Ally .. "target")
        unitIDs.HasAllyUnitID = true
      end
    else
      self:DeleteActiveUnitID()
    end
  end

  function playerButton:SetModulePositions()
    if not self:GetRect() then
      return
    end --the position of the button is not set yet

    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]
      local config = moduleFrameOnButton.config
      if not config then
        return
      end
      if config.Points then
        moduleFrameOnButton:ClearAllPoints()
      end
    end

    -- Phase 2: Set points, sizes, and parents (retry loop for dependency ordering)
    local i = 1
    repeat -- we basically run this roop to get out of the anchring hell (making sure all the frames that a module is depending on is set)
      local allModulesSet = true
      for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
        local moduleFrameOnButton = self[moduleName]

        local config = moduleFrameOnButton.config
        if not config then
          return
        end

        if config.Points then
          for j = 1, config.ActivePoints do
            local pointConfig = config.Points[j]
            if pointConfig then
              if pointConfig.RelativeFrame then
                local relativeFrame = self:GetAnchor(pointConfig.RelativeFrame)

                if relativeFrame then
                  local scale = (moduleFrameOnButton.config.Scale or 1)
                  moduleFrameOnButton:SetScale(scale)
                  if relativeFrame:GetNumPoints() > 0 then
                    local effectiveScale = moduleFrameOnButton:GetEffectiveScale()
                    -- When Spec Name is enabled it tucks under Name; nudge Name
                    -- up so the Name + Spec Name pair stays centered on Name's
                    -- anchor target (e.g. the Role icon). 0 when Spec Name is off.
                    local offsetY = pointConfig.OffsetY or 0
                    if moduleName == "Name" and BattleGroundEnemies.GetNameSpecNameYAdjust then
                      offsetY = offsetY + BattleGroundEnemies:GetNameSpecNameYAdjust(self.playerCountConfig)
                    end
                    moduleFrameOnButton:SetPoint(
                      pointConfig.Point,
                      relativeFrame,
                      pointConfig.RelativePoint,
                      (pointConfig.OffsetX or 0) / effectiveScale,
                      offsetY / effectiveScale
                    )
                  else
                    -- the module we are depending on hasn't been set yet
                    allModulesSet = false
                  end
                -- luacheck: ignore 542
                else
                  -- return print("error", relativeFrame, "for module", moduleName, "doesnt exist")
                end
              -- luacheck: ignore 542
              else
                --do nothing, the point was probably deleted
              end
            end
          end
        end
        if config.Parent then
          moduleFrameOnButton:SetParent(self:GetAnchor(config.Parent))
        end

        if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroWidthWhenDisabled then
          moduleFrameOnButton:SetWidth(0.01)
        else
          if config.UseButtonHeightAsWidth then
            moduleFrameOnButton:SetWidth(self:GetHeight())
          elseif config.UseButtonWidthAsWidth then
            moduleFrameOnButton:SetWidth(self:GetWidth())
          else
            if config.Width and BattleGroundEnemies:ModuleFrameNeedsWidth(moduleFrame, config) then
              moduleFrameOnButton:SetWidth(config.Width)
            end
          end
        end

        if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroHeightWhenDisabled then
          moduleFrameOnButton:SetHeight(0.001)
        else
          if config.UseButtonHeightAsHeight then
            moduleFrameOnButton:SetHeight(self:GetHeight())
          else
            if config.Height and BattleGroundEnemies:ModuleFrameNeedsHeight(moduleFrame, config) then
              moduleFrameOnButton:SetHeight(config.Height)
            end
          end
        end
      end
      i = i + 1
    until allModulesSet or i > 10 --maxium of 10 tries

    -- HealthBar is auto-managed: pinned to the top of the button, fills its width,
    -- and takes whatever height the power bar leaves behind (full button height when power is off).
    local powerHeight = self.Power.Enabled and self.Power:GetHeight() or 0
    self.healthBar:ClearAllPoints()
    self.healthBar:SetPoint("TOPLEFT", self, "TOPLEFT")
    self.healthBar:SetPoint("TOPRIGHT", self, "TOPRIGHT")
    self.healthBar:SetHeight(math.max(0.01, self:GetHeight() - powerHeight))
    -- #4-S1: this is the sole place the healthBar width changes, so invalidate the
    -- heal-prediction sub-bars' cached width — the next UpdateHealth re-SetWidth's
    -- them to the new bar width.
    self.healthBar.cachedBarWidth = nil

    -- Disabled Power frame is collapsed/repositioned, so anchor highlight to healthBar instead.
    local bottomAnchor = self.Power.Enabled and self.Power or self.healthBar
    self.MyTarget:SetParent(self)
    self.MyTarget:ClearAllPoints()
    self.MyTarget:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
    self.MyTarget:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMRIGHT")
    self.MyTarget:SetFrameLevel(self.Power:GetFrameLevel() + 5)
    self.MyFocus:SetParent(self)
    self.MyFocus:ClearAllPoints()
    self.MyFocus:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
    self.MyFocus:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMRIGHT")
    self.MyFocus:SetFrameLevel(self.Power:GetFrameLevel() + 5)
  end

  function playerButton:ApplyModuleSettings()
    wipe(self.ButtonEvents)
    for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
      local moduleFrameOnButton = self[moduleName]

      if moduleFrameOnButton.Enabled then
        if moduleFrame.events then
          for i = 1, #moduleFrame.events do
            local event = moduleFrame.events[i]
            self.ButtonEvents[event] = self.ButtonEvents[event] or {}

            table_insert(self.ButtonEvents[event], moduleFrameOnButton)
          end
        end
        moduleFrameOnButton.Enabled = true
        moduleFrameOnButton:Show()
        if moduleFrameOnButton.Enable then
          moduleFrameOnButton:Enable()
        end
        if moduleFrameOnButton.ApplyAllSettings then
          moduleFrameOnButton:ApplyAllSettings()
        end
      else
        moduleFrameOnButton.Enabled = false
        moduleFrameOnButton:Hide()
        if moduleFrameOnButton.Disable then
          moduleFrameOnButton:Disable()
        end
        if moduleFrameOnButton.Reset then
          moduleFrameOnButton:Reset()
        end
      end
    end
  end

  function playerButton:SetConfigShortCuts()
    self.config = BattleGroundEnemies.db.profile[self.PlayerType]
    self.playerCountConfig = BattleGroundEnemies[self.PlayerType].playerCountConfig
    if self.playerCountConfig then
      self.basePath = {
        "BattleGroundEnemiesFixed",
        self.PlayerIsEnemy and "EnemySettings" or "AllySettings",
        BattleGroundEnemies:GetPlayerCountConfigName(self.playerCountConfig),
      }
    else
      self.basePath = {}
    end
    self:SetAllModuleConfigs()
  end

  function playerButton:GetOptionsPath()
    local t = CopyTable(self.basePath)
    table.insert(t, "ButtonSettings")
    return t
  end

  function playerButton:ApplyButtonSettings()
    self:SetConfigShortCuts()
    local conf = self.playerCountConfig
    if not conf then
      return
    end

    self:SetWidth(conf.BarWidth)
    -- Grow the button by the spec-name text height when that module is enabled
    -- (0 otherwise). The row spacing in mainframe:ButtonPositioning adds the same
    -- amount, so taller buttons don't overlap.
    local specNameExtra = BattleGroundEnemies.GetSpecNameReservedHeight
        and BattleGroundEnemies:GetSpecNameReservedHeight(conf)
      or 0
    self:SetHeight(conf.BarHeight + specNameExtra)

    self:ApplyRangeIndicatorSettings()

    -- auras on spec

    --MyTarget, indicating the current target of the player
    self.MyTarget:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
      edgeFile = "Interface/Buttons/WHITE8X8", --drawlayer "BORDER"
      edgeSize = BattleGroundEnemies.db.profile.MyTarget_BorderSize,
    })
    self.MyTarget:SetBackdropColor(0, 0, 0, 0)
    self.MyTarget:SetBackdropBorderColor(unpack(BattleGroundEnemies.db.profile.MyTarget_Color))

    --MyFocus, indicating the current focus of the player
    self.MyFocus:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
      edgeFile = "Interface/Buttons/WHITE8X8", --drawlayer "BORDER"
      edgeSize = BattleGroundEnemies.db.profile.MyFocus_BorderSize,
    })
    self.MyFocus:SetBackdropColor(0, 0, 0, 0)
    self.MyFocus:SetBackdropBorderColor(unpack(BattleGroundEnemies.db.profile.MyFocus_Color))

    self:SetModulePositions()
    self:ApplyModuleSettings()
    self:SetBindings()
  end

  do
    local mouseButtons = {
      [1] = "LeftButton",
      [2] = "RightButton",
      [3] = "MiddleButton",
    }

    function playerButton:SetBindings()
      if not self.config then
        return
      end
      local setupUsualAttributes = true

      local newAttributes = {
        unit = not self.PlayerIsEnemy and self.unit or false,
        type1 = false,
        type2 = false,
        type3 = false,
        macrotext1 = false,
        macrotext2 = false,
        macrotext3 = false,
      }

      if self.PlayerIsEnemy then
        newAttributes.useOnKeyDown = BattleGroundEnemies.db.profile[self.PlayerType].ActionButtonUseKeyDown and true
          or false
      end

      if ClickCastFrames[self] then
        ClickCastFrames[self] = nil
      end

      if self.PlayerIsEnemy then
        if self.PlayerDetails.PlayerArenaUnitID then --its a arena enemy / flag/orb carrier
          newAttributes.unit = self.PlayerDetails.PlayerArenaUnitID
          newAttributes.type1 = "target"
          newAttributes.type2 = "focus"
          setupUsualAttributes = false
        end
      else
        if BattleGroundEnemies.db.profile[self.PlayerType].UseClique then
          ClickCastFrames[self] = true
          setupUsualAttributes = false
        end
      end

      if setupUsualAttributes then
        newAttributes.type1 = "macro" -- type1 = LEFT-Click
        newAttributes.type2 = "macro" -- type2 = Right-Click
        newAttributes.type3 = "macro" -- type3 = Middle-Click

        for i = 1, 3 do
          local bindingType = self.config[mouseButtons[i] .. "Type"]
          local targetName = self.PlayerDetails.PlayerName
          if Ambiguate then
            local ok, ambig = pcall(Ambiguate, targetName, "none")
            if ok and type(ambig) == "string" then
              targetName = ambig
            end
          end
          if bindingType == "Target" then
            newAttributes["macrotext" .. i] = "/cleartarget\n" .. "/targetexact " .. targetName
          elseif bindingType == "Focus" then
            newAttributes["macrotext" .. i] = "/targetexact " .. targetName .. "\n" .. "/focus\n" .. "/targetlasttarget"
          else -- Custom
            local template = BattleGroundEnemies.db.profile[self.PlayerType][mouseButtons[i] .. "Value"]
            if type(template) == "string" then
              newAttributes["macrotext" .. i] = template:gsub("%%n", targetName)
            end
          end
        end
      end

      --check what have actually changed
      local updateNeeded = false
      for attribute, value in pairs(newAttributes) do
        local currentValue = self:GetAttribute(attribute)
        if currentValue ~= value then
          updateNeeded = true
          break
        end
      end
      local newRegisterForClicksValue = BattleGroundEnemies.db.profile[self.PlayerType].ActionButtonUseKeyDown
          and "AnyDown"
        or "AnyUp"
      if self.registerForClicksValue == nil or self.registerForClicksValue ~= newRegisterForClicksValue then
        updateNeeded = true
      end
      if updateNeeded then
        if InCombatLockdown() then
          return BattleGroundEnemies:QueueForUpdateAfterCombat(self, "SetBindings")
        end
        self:RegisterForClicks(newRegisterForClicksValue)
        self.registerForClicksValue = newRegisterForClicksValue
        for attribute, value in pairs(newAttributes) do
          self:SetAttribute(attribute, value)
        end
      end
    end
  end

  function playerButton:PlayerIsDead()
    if not self.isDead then
      if self.PlayerDetails.isFakePlayer then
        if BattleGroundEnemies.Testmode.FakePlayerAuras[self] then
          wipe(BattleGroundEnemies.Testmode.FakePlayerAuras[self])
        end
        if BattleGroundEnemies.Testmode.FakePlayerDRs[self] then
          wipe(BattleGroundEnemies.Testmode.FakePlayerDRs[self])
        end
      end
      self:DispatchEvent("UnitDied")
      self.isDead = true
      if self.config and self.config.RangeIndicator_Enabled then
        self:UpdateRange(nil, true)
      end
    end
  end

  function playerButton:PlayerIsAlive()
    if self.isDead then
      self:DispatchEvent("UnitRevived")
      self.isDead = false
      if self.config and self.config.RangeIndicator_Enabled then
        self:UpdateRange(nil, true)
      else
        self:SetAlpha(1)
      end
    end
  end

  local maxHealths = {} --key = playerbutton, value = {}

  function playerButton:FakeUnitHealth()
    -- Dead players stay at 0 until the respawn cooldown on the ObjectiveAndRespawn
    -- module fires PlayerIsAlive via its OnCooldownDone handler.
    if self.isDead then
      return 0
    end
    local maxHealth = self:FakeUnitHealthMax()

    local roll = math_random(0, 100)
    if roll == 0 then
      -- Trigger the real dead-state so the graveyard icon and respawn timer show.
      self:PlayerIsDead()
      return 0
    else
      return math_floor((roll / 100) * maxHealth)
    end
  end

  function playerButton:FakeUnitHealthMax()
    if not maxHealths[self] then
      local myMaxHealth = UnitHealthMax("player")
      local playerMaxHealthDifference = math_random(-15, 15) -- the player has the same health as me +/- 15%
      local playerMaxHealth = math.ceil(myMaxHealth * (1 + (playerMaxHealthDifference / 100)))
      maxHealths[self] = playerMaxHealth
    end
    return maxHealths[self]
  end

  function playerButton:UpdateHealth(unitID, health, healthMissing, healthPercent, maxHealth)
    if unitID and not BattleGroundEnemies.betweenRounds then
      local isDeadOrGhost = UnitIsDeadOrGhost(unitID)
      if isDeadOrGhost then
        self:PlayerIsDead()
      elseif isDeadOrGhost == false then
        self:PlayerIsAlive()
      end
    end
    if
      unitID ~= nil
      and self.PlayerIsEnemy
      and not self.isDead
      and not (self.PlayerDetails and self.PlayerDetails.isFakePlayer)
      and unitID ~= self.unitID
    then
      return
    end

    -- Dispatch to HealthBar module (it checks isDead and shows 0 if dead)
    self:DispatchEvent("UpdateHealth", unitID, health, healthMissing, healthPercent, maxHealth)
  end

  function playerButton:UNIT_HEALTH(unitID)
    -- Between solo shuffle rounds, ignore all health events — stale data
    -- (0 hp from the previous round) would overwrite our synthetic 100%.
    if BattleGroundEnemies.betweenRounds then
      return
    end

    local isAlly = not self.PlayerIsEnemy
    if not isAlly and not self.isShown then
      return
    end
    local queryID = unitID
    if not queryID or not UnitExists(queryID) then
      queryID = self.unitID
    end

    if not self.PlayerDetails.isFakePlayer and (not queryID or not UnitExists(queryID)) then
      return
    end

    local health, healthMissing, healthPercent, maxHealth
    if self.PlayerDetails.isFakePlayer then
      maxHealth = self:FakeUnitHealthMax()
      health = self:FakeUnitHealth()
      healthMissing = maxHealth - health
      healthPercent = maxHealth > 0 and (health / maxHealth) * 100 or 0
    elseif isAlly then
      health = UnitHealth(queryID)
      healthMissing = UnitHealthMissing(queryID)
      maxHealth = UnitHealthMax(queryID)
      healthPercent = UnitHealthPercent(queryID, true, CurveConstants.ScaleTo100)
    else
      health = UnitHealth(queryID, true)
      healthMissing = UnitHealthMissing(queryID, true)
      maxHealth = UnitHealthMax(queryID)
      healthPercent = UnitHealthPercent(queryID, true, CurveConstants.ScaleTo100)
    end

    self:UpdateHealth(queryID, health, healthMissing, healthPercent, maxHealth)
  end

  function playerButton:ApplyRangeIndicatorSettings()
    --set everything to default
    for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
      if self[frameName] then
        self[frameName]:SetAlpha(1)
      else
        --probably old saved variables version
        self.config.RangeIndicator_Frames[frameName] = nil
      end
    end
    self:SetAlpha(1)
    self:UpdateRange(self.wasInRange, true)
  end

  function playerButton:ArenaOpponentShown(unitID)
    if unitID then
      BattleGroundEnemies.ArenaIDToPlayerButton[unitID] = self

      self:UpdateEnemyUnitID("Arena", unitID)

      RequestCrowdControlSpell(unitID)
    end
    self:DispatchEvent("ArenaOpponentShown", unitID)
  end

  -- Shows/Hides targeting indicators for a button
  function playerButton:UpdateTargetIndicators()
    self:DispatchEvent("UpdateTargetIndicators")

    if not BattleGroundEnemies.db.profile.RBG then
      return
    end
  end

  function playerButton:UpdateRange(inRange, forceUpdate)
    if not self.config then
      return
    end

    if not self.config.RangeIndicator_Enabled then
      return
    end

    if self.isDead then
      self:SetAlpha(self.config.RangeIndicator_Alpha)
      return
    end

    if not BattleGroundEnemies.states.userIsAlive then
      inRange = false
      forceUpdate = true
    end

    if inRange == nil then
      inRange = false
    end

    local alphaMax = 1
    local alphaMin = self.config.RangeIndicator_Alpha

    local isSecret = issecretvalue and issecretvalue(inRange)

    if isSecret and self.SetAlphaFromBoolean then
      if self.config.RangeIndicator_Everything then
        self:SetAlphaFromBoolean(inRange, alphaMax, alphaMin)
      else
        for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
          if enableRange and self[frameName] then
            if self[frameName].SetAlphaFromBoolean then
              self[frameName]:SetAlphaFromBoolean(inRange, alphaMax, alphaMin)
            end
          end
        end
      end
      -- Invalidate wasInRange so the next non-secret update always applies.
      -- We can't track the secret's actual value, so force a refresh next time.
      self.wasInRange = nil
      return
    end

    if forceUpdate or inRange ~= self.wasInRange then
      local alpha = inRange and alphaMax or alphaMin
      if self.config.RangeIndicator_Everything then
        self:SetAlpha(alpha)
      else
        for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
          if enableRange then
            self[frameName]:SetAlpha(alpha)
          end
        end
      end
      self.wasInRange = inRange
    end
  end

  function playerButton:UpdateRangeViaLibRangeCheck(unitID)
    if not unitID then
      return
    end
    if not self.config then
      return
    end
    if not self.config.RangeIndicator_Enabled then
      return
    end
    -- Dead-user guard: don't try to compute real range (can't cast from
    -- a corpse anyway), but DO still push a "false" through UpdateRange
    -- so this button gets dimmed. Previously we early-returned here,
    -- which left any button created post-death at default full alpha.
    if not BattleGroundEnemies.states.userIsAlive then
      self:UpdateRange(false, true)
      return
    end

    local myInRange = false
    -- Range helpers: shortest distance to longest distance.
    -- checkInteractDist (11-28y) -> isItemInRange (38-50y) -> isSpellInRange (15-40y class)
    if UnitExists(unitID) then
      -- Early-out: if the server hasn't even sent us data about this unit, they're
      -- well beyond combat range (~100-200y broadcast radius). Skip all checks.
      if not UnitIsVisible(unitID) then
        myInRange = false
        self:UpdateRange(myInRange)
        return
      end

      local inCombatLockdown = InCombatLockdown()
      local checker, _ = LRC[self.PlayerIsEnemy and "GetHarmMaxChecker" or "GetFriendMaxChecker"](
        LRC,
        inCombatLockdown and self.config.RangeIndicator_Range_InCombat or self.config.RangeIndicator_Range_OutOfCombat,
        inCombatLockdown
      )
      if checker then
        myInRange = checker(unitID)
        self:UpdateRange(myInRange)
        return
      end

      -- Prefer the cached self-button class (identical to before when BGE tracks
      -- your team); fall back to the native player class so spell-based range
      -- checks still work with friendly frames off (no UserButton then). Both are
      -- the uppercase English class token (e.g. "MAGE"), so the fallback matches.
      local myClass = (
        BattleGroundEnemies.UserButton
        and BattleGroundEnemies.UserButton.PlayerDetails
        and BattleGroundEnemies.UserButton.PlayerDetails.PlayerClass
      ) or select(2, UnitClass("player"))
      local interactResult = checkInteractDist(unitID)
      local itemResult = isItemInRange(unitID)
      local spellResult = isSpellInRange(unitID, myClass)

      myInRange = interactResult or itemResult or spellResult or false

      if not self.PlayerIsEnemy and myInRange == false then
        local inRange = UnitInRange(unitID)
        if type(inRange) ~= "nil" then
          myInRange = inRange
        end
      end

      self:UpdateRange(myInRange)
      return
    end

    self:UpdateRange(myInRange)
  end

  function playerButton:GetUnitID()
    return self.unitID
  end

  playerButton.UNIT_HEALTH_FREQUENT = playerButton.UNIT_HEALTH --TBC compability, IsTBCC

  function playerButton:UNIT_MAXHEALTH(unitID)
    if self.healthBar then
      self.healthBar._rangeDirty = true
    end
    self:UNIT_HEALTH(unitID)
  end

  playerButton.UNIT_HEAL_PREDICTION = playerButton.UNIT_HEALTH
  playerButton.UNIT_ABSORB_AMOUNT_CHANGED = playerButton.UNIT_HEALTH
  playerButton.UNIT_HEAL_ABSORB_AMOUNT_CHANGED = playerButton.UNIT_HEALTH

  function playerButton:UNIT_POWER_FREQUENT(unitID, powerToken)
    if not self.isShown then
      return
    end
    local queryID = unitID
    if not queryID or not UnitExists(queryID) then
      queryID = self.unitID
    end

    if
      self.PlayerIsEnemy
      and not (self.PlayerDetails and self.PlayerDetails.isFakePlayer)
      and queryID ~= self.unitID
    then
      return
    end

    self:DispatchEvent("UpdatePower", queryID, powerToken)
  end

  function playerButton:UpdateTargetedByEnemy(otherButton, targeted)
    local unitIDs = self.UnitIDs
    unitIDs.TargetedByEnemy[otherButton] = targeted
    self:DispatchEvent("UpdateTargetIndicators")

    if otherButton == BattleGroundEnemies.UserButton then
      self:UpdateEnemyUnitID("Target", targeted and "target" or nil)
    end

  end

  -- returns true if the other button is a enemy from the point of view of the button. True if button is ally and other button is enemy, and vice versa
  function playerButton:IsEnemyToMe(otherButton)
    return self.PlayerIsEnemy ~= otherButton.PlayerIsEnemy
  end

  function playerButton:IsNowTargeting(otherButton)
    self.Target = otherButton

    if not self:IsEnemyToMe(otherButton) then
      return
    end --we only care of the other player is of opposite faction

    otherButton:UpdateTargetedByEnemy(self, true)
  end

  function playerButton:IsNoLongerTarging(otherButton)
    self.Target = nil

    if not self:IsEnemyToMe(otherButton) then
      return
    end --we only care of the other player is of opposite faction

    otherButton:UpdateTargetedByEnemy(self, nil)
  end

  function playerButton:UpdateTarget()
    local oldTargetPlayerButton = self.Target
    local newTargetPlayerButton

    if self.TargetUnitID and UnitExists(self.TargetUnitID) then
      -- Try enemies first, then allies. Target can be on either team.
      newTargetPlayerButton = BattleGroundEnemies:GetPlayerbuttonByUnitID(self.TargetUnitID, "Enemies")
      if not newTargetPlayerButton then
        newTargetPlayerButton = BattleGroundEnemies.Allies:GetAllyButtonByUnitID(self.TargetUnitID)
      end
    end

    if oldTargetPlayerButton then
      if newTargetPlayerButton and oldTargetPlayerButton == newTargetPlayerButton then
        return
      end
      self:IsNoLongerTarging(oldTargetPlayerButton)
    end

    --player didnt have a target before or the player targets a new player

    if newTargetPlayerButton then --player targets an existing player and not for example a pet or a NPC
      self:IsNowTargeting(newTargetPlayerButton)
    end
  end

  playerButton.UNIT_TARGET = playerButton.UpdateTarget

  function playerButton:DispatchEvent(event, ...)
    if BattleGroundEnemies.betweenRounds then
      return
    end
    if not self.ButtonEvents then
      return
    end

    local moduleFrames = self.ButtonEvents[event]

    if not moduleFrames then
      return
    end
    for i = 1, #moduleFrames do
      local moduleFrameOnButton = moduleFrames[i]
      if moduleFrameOnButton[event] then
        moduleFrameOnButton[event](moduleFrameOnButton, ...)
      else
        BattleGroundEnemies:OnetimeInformation(
          "Event:",
          event,
          "There is no key with the event name for this module",
          moduleFrameOnButton.moduleName
        )
      end
    end
  end

  -- DispatchUntilTrue removed (Aura logic deprecated)

  function playerButton:GetAnchor(relativeFrame)
    return relativeFrame == "Button" and self or self[relativeFrame]
  end

  playerButton.Counter = {}
  playerButton:SetScript("OnEvent", function(self, event, ...)
    --self.Counter[event] = (self.Counter[event] or 0) + 1
    if not BattleGroundEnemies:IsInPvPInstance() then
      return
    end
    self[event](self, ...)
  end)
  playerButton:SetScript("OnShow", function()
    playerButton.isShown = true
  end)
  playerButton:SetScript("OnHide", function()
    playerButton.isShown = false
  end)

  -- events/scripts
  playerButton:RegisterForDrag("LeftButton")
  playerButton:SetClampedToScreen(true)

  -- Edit Mode Magnetic Snapping Support
  function playerButton:GetScaledSelectionSides()
    local left, bottom, width, height = self:GetRect()
    left = left or 0
    bottom = bottom or 0
    width = width or 0
    height = height or 0
    local scale = self:GetScale() or 1
    return left * scale, (left + width) * scale, bottom * scale, (bottom + height) * scale
  end

  function playerButton:GetScaledSelectionCenter()
    local cX, cY = self:GetCenter()
    cX = cX or 0
    cY = cY or 0
    local scale = self:GetScale() or 1
    return cX * scale, cY * scale
  end

  function playerButton:IsToTheLeftOfFrame(systemFrame)
    local _, myRight, _, _ = self:GetScaledSelectionSides()
    local systemFrameLeft, _, _, _ = systemFrame:GetScaledSelectionSides()
    return myRight < systemFrameLeft
  end

  function playerButton:IsToTheRightOfFrame(systemFrame)
    local myLeft, _, _, _ = self:GetScaledSelectionSides()
    local _, systemFrameRight, _, _ = systemFrame:GetScaledSelectionSides()
    return myLeft > systemFrameRight
  end

  function playerButton:IsAboveFrame(systemFrame)
    local _, _, myBottom, _ = self:GetScaledSelectionSides()
    local _, _, _, systemFrameTop = systemFrame:GetScaledSelectionSides()
    return myBottom > systemFrameTop
  end

  function playerButton:IsBelowFrame(systemFrame)
    local _, _, _, myTop = self:GetScaledSelectionSides()
    local _, _, systemFrameBottom, _ = systemFrame:GetScaledSelectionSides()
    return myTop < systemFrameBottom
  end

  function playerButton:IsVerticallyAlignedWithFrame(systemFrame)
    local _, _, myBottom, myTop = self:GetScaledSelectionSides()
    local _, _, systemFrameBottom, systemFrameTop = systemFrame:GetScaledSelectionSides()
    return (myTop >= systemFrameBottom) and (myBottom <= systemFrameTop)
  end

  function playerButton:IsHorizontallyAlignedWithFrame(systemFrame)
    local myLeft, myRight, _, _ = self:GetScaledSelectionSides()
    local systemFrameLeft, systemFrameRight, _, _ = systemFrame:GetScaledSelectionSides()
    return (myRight >= systemFrameLeft) and (myLeft <= systemFrameRight)
  end

  playerButton:SetScript("OnDragStart", playerButton.OnDragStart)
  playerButton:SetScript("OnDragStop", playerButton.OnDragStop)

  --MyTarget, indicating the current target of the player
  playerButton.MyTarget = CreateFrame("Frame", nil, playerButton, BackdropTemplateMixin and "BackdropTemplate")

  playerButton.MyTarget:Hide()

  --MyFocus, indicating the current focus of the player
  playerButton.MyFocus = CreateFrame("Frame", nil, playerButton, BackdropTemplateMixin and "BackdropTemplate")
  playerButton.MyFocus:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
    edgeFile = "Interface/Buttons/WHITE8X8", --drawlayer "BORDER"
    edgeSize = 1,
  })
  playerButton.MyFocus:SetBackdropColor(0, 0, 0, 0)
  playerButton.MyFocus:Hide()

  playerButton.ButtonModules = {}
  for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
    if moduleFrame.AttachToPlayerButton then
      moduleFrame:AttachToPlayerButton(playerButton)

      playerButton[moduleName].GetConfig = function(self)
        self.config = playerButton.playerCountConfig.ButtonModules[moduleName]
        return self.config
      end

      playerButton[moduleName].GetOptionsPath = function(self)
        local optionsPath = CopyTable(playerButton.basePath)
        table.insert(optionsPath, "ModuleSettings")
        table.insert(optionsPath, moduleName)
        return optionsPath
      end
      playerButton[moduleName].moduleName = moduleName
    end
  end

  playerButton:SetScript("OnAttributeChanged", function(self, name, value)
    if name == "unit" then
      if value then
        self.TargetUnitID = value .. "target"
        self:RegisterUnitEvent("UNIT_TARGET", value)
        if self.UpdateTarget then
          self:UpdateTarget()
        end
      else
        self.TargetUnitID = nil
        self:UnregisterEvent("UNIT_TARGET")
      end
    end
  end)

  return playerButton
end
