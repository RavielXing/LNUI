local _, addon = ...
local frame = CreateFrame("Frame")
DFCN_MountDB = DFCN_MountDB or { autoMultiSeatInGroup = true, autoMountMode = 1 }
DFCN_MountDB.logEnabled = DFCN_MountDB.logEnabled or true
local MULTI_SEAT_MOUNTS = {2296, 2144, 1589, 1744, 1591, 1588, 1830, 1590, 1563, 2512, 2091, 1795, 1792, 1818, 382, 455, 407}
local AUCTION_MOUNTS = {1039, 2265}
local REPAIR_MOUNTS = {
	ALL = { 460, 2237 },
	Alliance = { 280 },
	Horde = { 284 }
}
local L = DFCN_MountL
local expectedMount = nil
local MOUNT_CAST_TIMEOUT = 1.2
local buffRemovalFrame = CreateFrame("Frame")
local waitingForBuffRemoval = false
local buffRemovalTimeoutTimer = nil

local function ShouldUseMultiSeat()
	return DFCN_MountDB.autoMultiSeatInGroup and (IsInGroup() or IsInRaid())
end

local function LogPrint(message)
	if DFCN_MountDB.logEnabled then
		print(message)
	end
end

local function HasMount(mountID)
	local name, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
	if not (name and isCollected) then return false end
	local _, _, _, _, _, mountFactionID = C_MountJournal.GetMountInfoExtraByID(mountID)
	local playerFaction = UnitFactionGroup("player")
	return not mountFactionID or 
		   (mountFactionID == 1 and playerFaction == "Alliance") or 
		   (mountFactionID == 0 and playerFaction == "Horde") or
		   mountFactionID > 1
end

local function GetAvailableMultiSeatMounts()
	local available = {}
	for _, mountID in ipairs(MULTI_SEAT_MOUNTS) do
		if HasMount(mountID) then
			table.insert(available, mountID)
		end
	end
	return available
end

local function GetRepairMounts()
	local faction = UnitFactionGroup("player")
	local mounts = {}
	for _, mountID in ipairs(REPAIR_MOUNTS.ALL) do
		if HasMount(mountID) then
			table.insert(mounts, mountID)
		end
	end
	if REPAIR_MOUNTS[faction] then
		for _, mountID in ipairs(REPAIR_MOUNTS[faction]) do
			if HasMount(mountID) then
				table.insert(mounts, mountID)
			end
		end
	end
	return mounts
end

local function SafeChangeActionBarPage(page)
	if not InCombatLockdown() then
		ChangeActionBarPage(page)
	end
end

local function GetRandomAvailableMount(mountList)
	local available = {}
	for _, mountID in ipairs(mountList) do
		if HasMount(mountID) then
			table.insert(available, mountID)
		end
	end
	if #available > 0 then
		return available[math.random(#available)]
	end
	return nil
end

local function HasPhaseStealth()
	if InCombatLockdown() or IsInInstance() then return end
	for i = 1, 40 do
		local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if auraData and not issecretvalue(auraData) and auraData.spellId == 1214374 then
			return true
		end
	end
	return false
end

local function SummonRandomMultiSeatMount()
	if not ShouldUseMultiSeat() then
		expectedMount = {type = "favorite", startTime = GetTime()}
		C_MountJournal.SummonByID(0)
		return
	end
	local availableMounts = GetAvailableMultiSeatMounts()
	if #availableMounts > 0 then
		local randomIndex = math.random(#availableMounts)
		C_MountJournal.SummonByID(availableMounts[randomIndex])
		return true
	end
	return false
end

local function SummonMountAfterBuffRemoved()
	if not waitingForBuffRemoval then return end
	waitingForBuffRemoval = false
	buffRemovalFrame:UnregisterEvent("UNIT_AURA")
	if buffRemovalTimeoutTimer then
		buffRemovalTimeoutTimer:Cancel()
		buffRemovalTimeoutTimer = nil
	end
	local _, class = UnitClass("player")
	local isDruid = (class == "DRUID")
	if isDruid then
		return
	end
	if IsInGroup() or IsInRaid() then
		expectedMount = {type = "multi_seat", startTime = GetTime()}
		SummonRandomMultiSeatMount()
	else
		expectedMount = {type = "favorite", startTime = GetTime()}
		C_MountJournal.SummonByID(0)
	end
	C_Timer.After(0, function()
		UIErrorsFrame:Clear()
	end)
end

buffRemovalFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "UNIT_AURA" and unit == "player" and waitingForBuffRemoval then
		if InCombatLockdown() then return end
		if not HasPhaseStealth() then
			SummonMountAfterBuffRemoved()
		end
	end
end)

local function HandleMountCastStart(spellID)
	if not expectedMount then return end
	local currentTime = GetTime()
	if currentTime - expectedMount.startTime > MOUNT_CAST_TIMEOUT then
		expectedMount = nil
		return
	end
	local mountID = C_MountJournal.GetMountFromSpell(spellID)
	if mountID then
		local spellInfo = C_Spell.GetSpellInfo(spellID)
		if spellInfo and spellInfo.name then
			local icon = spellInfo.iconID or 132261
			local mountTypeKey = expectedMount.type
			local mountTypeText = ""
			if mountTypeKey == "favorite" then
				mountTypeText = L.TYPE_FAVORITE
			elseif mountTypeKey == "multi_seat" then
				mountTypeText = L.TYPE_MULTI_SEAT
			elseif mountTypeKey == "auction" then
				mountTypeText = L.TYPE_AUCTION
			elseif mountTypeKey == "repair" then
				mountTypeText = L.TYPE_REPAIR
			else
				mountTypeText = mountTypeKey
			end
			local triggerPrefix = L.PREFIX_SOLO
			if expectedMount.mountAction == "ALT" then
				triggerPrefix = L.PREFIX_ALT
			elseif expectedMount.mountAction == "SHIFT" then
				triggerPrefix = L.PREFIX_SHIFT
			elseif expectedMount.mountAction == "CTRL" then
				triggerPrefix = L.PREFIX_CTRL
			elseif expectedMount.mountAction == "GROUP" then
				triggerPrefix = L.PREFIX_GROUP
			end
			LogPrint(format(L.SUMMON_MOUNT, icon, triggerPrefix, mountTypeText, spellInfo.name))
		end
		expectedMount = nil
	end
end

frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:SetScript("OnEvent", function(self, event, unitTarget, ...)
	if event == "UNIT_SPELLCAST_START" and unitTarget == "player" then
		local castID, spellID = ...
		if spellID == 460013 then
			local spellInfo = C_Spell.GetSpellInfo(spellID)
			if spellInfo and spellInfo.name then
				local icon = spellInfo.iconID or 132261
				LogPrint(format(L.SUMMON_G99, icon))
			end
			return
		end
		HandleMountCastStart(spellID)
	end
end)

function DFCN_Mount()
	local currentMapID = C_Map.GetBestMapForUnit("player")
	local function IsKreshArea()
		return currentMapID and (currentMapID == 2472 or currentMapID == 2371)
	end
	local function IsAndermart()
		return currentMapID and (currentMapID == 2346 or currentMapID == 2769)
	end
	local mountAction
	if IsAltKeyDown() then
		mountAction = "ALT"
	elseif IsShiftKeyDown() then
		mountAction = "SHIFT"
	elseif IsControlKeyDown() then
		mountAction = "CTRL"
	elseif IsInGroup() or IsInRaid() then
		mountAction = "GROUP"
	else
		mountAction = "SOLO"
	end
	if IsAndermart() and (mountAction == "SOLO" or mountAction == "GROUP") then
		SafeChangeActionBarPage(1)
		return
	end
	local _, class = UnitClass("player")
	local isDruid = (class == "DRUID")
	local factionGroup = UnitFactionGroup("player")
	local isMounted = IsMounted()
	if isDruid and (mountAction == "SOLO" or mountAction == "GROUP") then
		SafeChangeActionBarPage(1)
	end
	if not (isDruid and mountAction == "SOLO") and mountAction ~= "CTRL" then
		if IsIndoors() then
			SafeChangeActionBarPage(1)
			C_Timer.After(0, function()
				UIErrorsFrame:Clear()
			end)
		end
	end
	if mountAction == "GROUP" then
		if isMounted then
			Dismount()
		elseif not isDruid then
			expectedMount = {type = "multi_seat", startTime = GetTime(), mountAction = mountAction}
			SummonRandomMultiSeatMount()
		end
		SafeChangeActionBarPage(1)
	end
	if not isDruid then
		if isMounted then
			Dismount()
		else
			if mountAction == "SOLO" then
				expectedMount = {type = "favorite", startTime = GetTime(), mountAction = mountAction}
				C_MountJournal.SummonByID(0)
			end
		end
	end
	if mountAction == "ALT" then
		local auctionMountID = GetRandomAvailableMount(AUCTION_MOUNTS)
		if auctionMountID then
			expectedMount = {type = "auction", startTime = GetTime(), mountAction = mountAction}
			C_MountJournal.SummonByID(auctionMountID)
			C_Timer.After(0, function()
				UIErrorsFrame:Clear()
			end)
		else
			LogPrint(L.NO_AUCTION_MOUNT)
		end
	elseif mountAction == "SHIFT" then
		local repairMounts = GetRepairMounts()
		if #repairMounts > 0 then
			local repairMountID = repairMounts[math.random(#repairMounts)]
			expectedMount = {type = "repair", startTime = GetTime(), mountAction = mountAction}
			C_MountJournal.SummonByID(repairMountID)
			C_Timer.After(0, function()
				UIErrorsFrame:Clear()
			end)
		else
			LogPrint(L.NO_REPAIR_MOUNT)
		end
	elseif mountAction == "CTRL" then
		if UnitAffectingCombat("player") then
			LogPrint(L.CTRL_IN_COMBAT)
			return
		end
		if not IsKreshArea() then
			SafeChangeActionBarPage(1)
			LogPrint(L.CTRL_NOT_PHASE)
			if not isDruid then
				if IsInGroup() or IsInRaid() then
					expectedMount = {type = "multi_seat", startTime = GetTime(), mountAction = mountAction}
					SummonRandomMultiSeatMount()
				else
					expectedMount = {type = "favorite", startTime = GetTime(), mountAction = mountAction}
					C_MountJournal.SummonByID(0)
				end
				C_Timer.After(0, function()
					UIErrorsFrame:Clear()
				end)
			end
			SafeChangeActionBarPage(1)
			return
		end
		local buffFound = false
		if InCombatLockdown() or IsInInstance() then return end
		for i = 1, 40 do
			local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
			if auraData and not issecretvalue(auraData) and auraData.spellId == 1214374 then
				CancelUnitBuff("player", i)
				buffFound = true
				LogPrint(L.CTRL_CANCEL_PHASE)
				break
			end
		end
		if waitingForBuffRemoval then
			buffRemovalFrame:UnregisterEvent("UNIT_AURA")
			if buffRemovalTimeoutTimer then
				buffRemovalTimeoutTimer:Cancel()
				buffRemovalTimeoutTimer = nil
			end
			waitingForBuffRemoval = false
		end
		if buffFound then
			waitingForBuffRemoval = true
			buffRemovalFrame:RegisterEvent("UNIT_AURA")
			buffRemovalTimeoutTimer = C_Timer.NewTimer(0.5, function()
				if waitingForBuffRemoval then
					SummonMountAfterBuffRemoved()
				end
			end)
		else
			if not isDruid then
				if IsInGroup() or IsInRaid() then
					expectedMount = {type = "multi_seat", startTime = GetTime(), mountAction = mountAction}
					SummonRandomMultiSeatMount()
				else
					expectedMount = {type = "favorite", startTime = GetTime(), mountAction = mountAction}
					C_MountJournal.SummonByID(0)
				end
				C_Timer.After(0, function()
					UIErrorsFrame:Clear()
				end)
			end
		end
		SafeChangeActionBarPage(1)
	end
end

local g99Button = CreateFrame("Button", "g99", UIParent, "SecureActionButtonTemplate")
g99Button:SetSize(1, 1)
g99Button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, -10)
g99Button:Hide()
local DFCN_Mount_orig = DFCN_Mount
local DFMH = CreateFrame("Button", "DFMH", UIParent, "SecureActionButtonTemplate")
DFMH:SetSize(1, 1)
DFMH:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, -10)
DFMH:Hide()
DFMH:RegisterForClicks("AnyDown")
DFMH:SetScript("PreClick", function(self)
	DFCN_Mount_orig()
end)

local SecureAction = { }
SecureAction.__index = SecureAction
function SecureAction:New(attr)
	return setmetatable(attr, SecureAction)
end
function SecureAction:SetupActionButton(button, mouseButtonIndex)
	button:SetAttribute('type', self.type)
	for k, v in pairs(self) do
		if k ~= 'type' then
			if mouseButtonIndex then
				k = k .. tostring(mouseButtonIndex)
			end
			button:SetAttribute(k, v)
		end
	end
	button:SetAttribute("pressAndHoldAction", true)
	button:SetAttribute("typerelease", button:GetAttribute("type"))
end
function SecureAction:ClearActionButton(button)
	button:SetAttribute('type', nil)
	button:SetAttribute('typerelease', nil)
end
function SecureAction:Spell(spellName, unit)
	local attr = {
		type = "spell",
		unit = unit or "player",
		spell = spellName
	}
	return self:New(attr)
end

local function IsG99Available()
	if C_ZoneAbility then
		local zoneAbilities = C_ZoneAbility.GetActiveAbilities()
		for _, zoneAbility in ipairs(zoneAbilities) do
			if zoneAbility.spellID == 1215279 then
				return true
			end
		end
	end
	local currentMapID = C_Map.GetBestMapForUnit("player")
	if currentMapID and (currentMapID == 2346 or currentMapID == 2769) then
		return true
	end
	return false
end

local function UpdateButtonStatus()
	local available = IsG99Available()
	if available and not InCombatLockdown() then
		local action = SecureAction:Spell(1215279)
		action:SetupActionButton(g99Button)
		action:SetupActionButton(DFMH)
	elseif not InCombatLockdown() then
		SecureAction:ClearActionButton(g99Button)
		SecureAction:ClearActionButton(DFMH)
	end
end

g99Button:RegisterForClicks("AnyDown")
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", UpdateButtonStatus)
UpdateButtonStatus()

local flightModeFrame = CreateFrame("Frame")
local lastFlightMode = nil
local lastFlightModeCheckTime = 0
local FLIGHT_MODE_CHECK_COOLDOWN = 5
local function UpdateFlightMode(event, unit)
	if InCombatLockdown() or IsInInstance() then return end
	if event ~= "UNIT_AURA" or unit ~= "player" then return end
	local currentTime = GetTime()
	if currentTime - (lastFlightModeCheckTime or 0) < FLIGHT_MODE_CHECK_COOLDOWN then return end
	lastFlightModeCheckTime = currentTime
	local currentMode
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura or issecretvalue(aura) then break end
		if aura.spellId == 404464 then currentMode = 404464 break
		elseif aura.spellId == 404468 then currentMode = 404468 break end
	end
	if currentMode ~= lastFlightMode then
		if currentMode and lastFlightMode then
			local icon = (currentMode == 404464) and 5142725 or 5142726
			local modeName = (currentMode == 404464) and L.FLIGHT_MODE_SKYRIDING or L.FLIGHT_MODE_STEADY
			print(format(L.FLIGHT_MODE_SWITCH, icon, modeName))
		end
		lastFlightMode = currentMode
	end
end
local function OnCombatStatusChange(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		flightModeFrame:UnregisterEvent("UNIT_AURA")
	elseif event == "PLAYER_REGEN_ENABLED" then
		flightModeFrame:RegisterEvent("UNIT_AURA")
		C_Timer.After(1, function()
			UpdateFlightMode("UNIT_AURA", "player")
		end)
	end
end
flightModeFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		OnCombatStatusChange(self, event)
	else
		UpdateFlightMode(event, unit)
	end
end)
flightModeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
flightModeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
if not InCombatLockdown() then
	flightModeFrame:RegisterEvent("UNIT_AURA")
	C_Timer.After(2, function()
		UpdateFlightMode("UNIT_AURA", "player")
	end)
end

local autoMountFrame = CreateFrame("Frame")
local autoMountTimer = nil
local isPlayerMoving = false
local cachedMountIDs = nil
local function IsAnyMountUsable()
	if not cachedMountIDs then
		cachedMountIDs = {}
		for i = 1, 10 do
			local _, _, _, _, _, _, _, _, _, _, isCollected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
			if not mountID then break end
			if isCollected then
				table.insert(cachedMountIDs, {id = mountID, idx = i})
			end
		end
	end
	for _, entry in ipairs(cachedMountIDs) do
		local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(entry.id)
		if isUsable then
			return true
		end
	end
	return false
end


local function IsMountingAllowed()
	if InCombatLockdown() then return false end
	if UnitCastingInfo("player") then return false end
	if UnitChannelInfo("player") then return false end
	if UnitOnTaxi("player") then return false end
	if IsFalling() then return false end	
	if DFCN_MountDB.autoMountMode ~= 3 and IsInInstance() then return false end
	if DFCN_MountDB.autoMountMode == 1 and IsResting() then return false end
	local currentMapID = C_Map.GetBestMapForUnit("player")
	if currentMapID and (currentMapID == 2346 or currentMapID == 2769) then return false end
	if IsMounted() then return false end
	if not IsOutdoors() then return false end
	if not IsAnyMountUsable() then return false end
	return true
end

local function DoAutoMount()
	autoMountTimer = nil
	if not IsMountingAllowed() then return end
	if isPlayerMoving then return end
	local _, class = UnitClass("player")
	local isDruid = (class == "DRUID")
	if ShouldUseMultiSeat() then
		if isDruid then
			SafeChangeActionBarPage(1)
		else
			expectedMount = {type = "multi_seat", startTime = GetTime()}
			SummonRandomMultiSeatMount()
		end
	else
		if isDruid then
			SafeChangeActionBarPage(1)
		else
			expectedMount = {type = "favorite", startTime = GetTime()}
			C_MountJournal.SummonByID(0)
		end
	end
	SafeChangeActionBarPage(1)
end

local function StartAutoMountTimer()
	if DFCN_MountDB.autoMountMode == 0 then return end
	if autoMountTimer then
		autoMountTimer:Cancel()
	end
	autoMountTimer = C_Timer.NewTimer(0.5, DoAutoMount)
end

local function CancelAutoMountTimer()
	if autoMountTimer then
		autoMountTimer:Cancel()
		autoMountTimer = nil
	end
end

autoMountFrame:SetScript("OnEvent", function(self, event, ...)
	if DFCN_MountDB.autoMountMode == 0 then return end
	if event == "PLAYER_STOPPED_MOVING" then
		isPlayerMoving = false
		if not InCombatLockdown() then
			StartAutoMountTimer()
		end
	elseif event == "PLAYER_STARTED_MOVING" then
		isPlayerMoving = true
		CancelAutoMountTimer()
	elseif event == "PLAYER_REGEN_DISABLED" then
		CancelAutoMountTimer()
	elseif event == "PLAYER_REGEN_ENABLED" then
		StartAutoMountTimer()
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if not InCombatLockdown() and select(1, ...) == "player" then
			StartAutoMountTimer()
		end
	elseif event == "CRITERIA_UPDATE" then
		if not InCombatLockdown() then
			StartAutoMountTimer()
		end
	end
end)

autoMountFrame:RegisterEvent("PLAYER_STARTED_MOVING")
autoMountFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
autoMountFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
autoMountFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
autoMountFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
autoMountFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
autoMountFrame:RegisterEvent("CRITERIA_UPDATE")
local function UpdateEventRegistration()
	if DFCN_MountDB.autoMountMode == 0 then
		autoMountFrame:UnregisterAllEvents()
	else
		autoMountFrame:RegisterEvent("PLAYER_STARTED_MOVING")
		autoMountFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
		autoMountFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		autoMountFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		autoMountFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
		autoMountFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		autoMountFrame:RegisterEvent("CRITERIA_UPDATE")
	end
end
UpdateEventRegistration()
if not InCombatLockdown() then
	C_Timer.After(2, function()
		if DFCN_MountDB.autoMountMode ~= 0 then
			StartAutoMountTimer()
		end
	end)
end

SLASH_DFCNMH1 = "/dfmh"
SlashCmdList["DFCNMH"] = function(msg)
	if msg == "" then
		print(L.CMD_HELP_TITLE)
		print(L.CMD_HELP_69 .. (DFCN_MountDB.autoMultiSeatInGroup and L.CMD_ON or L.CMD_OFF))
		print(L.CMD_HELP_LOG .. (DFCN_MountDB.logEnabled and L.CMD_ON or L.CMD_OFF))
		local autoMode = DFCN_MountDB.autoMountMode
		if autoMode == 0 then print(L.CMD_HELP_AUTO .. L.CMD_AUTO_0)
		elseif autoMode == 1 then print(L.CMD_HELP_AUTO .. L.CMD_AUTO_1)
		elseif autoMode == 2 then print(L.CMD_HELP_AUTO .. L.CMD_AUTO_2)
		else print(L.CMD_HELP_AUTO .. L.CMD_AUTO_3) end
		print(L.CMD_HELP_USAGE)
	else
		local _, _, cmd, state = string.find(msg:lower(), "(%S+)%s+(%S+)")
		if cmd == "69" then
			if state == "on" or state == "off" then
				DFCN_MountDB.autoMultiSeatInGroup = (state == "on")
				print(state == "on" and L.CMD_69_ON or L.CMD_69_OFF)
				if state == "on" then
					local configID = C_Traits.GetConfigIDByTreeID(672)
					if configID then
						C_Traits.SetSelection(configID, 100167, 123785, true)
						C_Traits.CommitConfig(configID)
					end
				end
			else
				print(L.CMD_INVALID_STATE)
			end
		elseif cmd == "log" then
			if state == "on" or state == "off" then
				DFCN_MountDB.logEnabled = (state == "on")
				print(state == "on" and L.CMD_LOG_ON or L.CMD_LOG_OFF)
			else
				print(L.CMD_INVALID_STATE)
			end
		elseif cmd == "auto" then
			if state == "0" or state == "1" or state == "2" or state == "3" then
				DFCN_MountDB.autoMountMode = tonumber(state)
				UpdateEventRegistration()
				if state == "0" then print(L.CMD_AUTO_0)
				elseif state == "1" then print(L.CMD_AUTO_1)
				elseif state == "2" then print(L.CMD_AUTO_2)
				else print(L.CMD_AUTO_3) end
			else
				print(L.CMD_INVALID_STATE)
			end
		else
			print(L.CMD_INVALID_CMD)
			print(L.CMD_AVAILABLE)
		end
	end
end
