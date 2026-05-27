--[[------------------------------------------------------------
UnitAura, UnitDebuff
---------------------------------------------------------------]]
function Aby_UnitAura_Proxy(UnitAuraFunc, unit, indexOrName, filterOrNil, filter, ...)

	for i = 1, 40 do
		local name, icon, count, dispelType, duration, expires, caster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, v1, nameplateShowAll, timeMod, value1, value2, value3, v3, v4, v5 = UnitAuraFunc(unit, i, filterOrNil, filter, ...)
		if not name then return end
		if name == indexOrName then return name, nil, icon, count, dispelType, duration, expires, caster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, v1, nameplateShowAll, timeMod, value1, value2, value3, v3, v4, v5 end
	end
	--end
end
function Aby_UnitAura(unit, indexOrName, filterOrNil, filter, ...) return Aby_UnitAura_Proxy(UnitAura, unit, indexOrName, filterOrNil, filter, ...) end
function Aby_UnitBuff(unit, indexOrName, filterOrNil, filter, ...) return Aby_UnitAura_Proxy(UnitBuff, unit, indexOrName, filterOrNil, filter, ...) end
function Aby_UnitDebuff(unit, indexOrName, filterOrNil, filter, ...) return Aby_UnitAura_Proxy(UnitDebuff, unit, indexOrName, filterOrNil, filter, ...) end

if U1_WOW10 then return end

MainMenuBarPerformanceBar:SetPoint("CENTER", MainMenuMicroButton, "CENTER", 0, 11) --SetSize(28,36) --因为8.0之前按钮大小是28,58，暴雪忘了改了

TEXT = TEXT or function(text)
    return text
end

local hbdp = LibStub("HereBeDragons-2.0")
GetPlayerMapPosition = GetPlayerMapPosition or function(unit)
    local x, y, instance = hbdp:GetPlayerZonePosition(false)
    return x, y
end

SetMapToCurrentZone = SetMapToCurrentZone or function()
    WorldMapFrame:SetMapID(C_Map.GetBestMapForUnit("player"))
end

GetCurrentMapAreaID = GetCurrentMapAreaID or function()
    if WorldMapFrame:IsVisible() then
        return WorldMapFrame:GetMapID()
    else
       return C_Map.GetBestMapForUnit("player")
    end
end

UnitPopupFrames = UnitPopupFrames or {}

CanComplainChat = CanComplainChat or function(lineID)
    local loc = PlayerLocation:CreateFromChatLineID(lineID);
    return C_ReportSystem.CanReportPlayer(loc)
end

RegisterAddonMessagePrefix = RegisterAddonMessagePrefix or C_ChatInfo.RegisterAddonMessagePrefix
SendAddonMessage = SendAddonMessage or C_ChatInfo.SendAddonMessage

CalendarGetDate = CalendarGetDate or function()
    local date = C_Calendar.GetDate()
    return date.weekday, date.month, date.monthDay, date.year
end
CalendarGetMonth = CalendarGetMonth or function(...)
    local m = C_Calendar.GetMonthInfo(...)
    return 	m.month, m.year, m.numDays, m.firstWeekday;
end
function CalendarGetDayEvent(monthOffset, monthDay, index)
	local event = C_Calendar.GetDayEvent(monthOffset, monthDay, index);
	if (event) then
		local hour, minute;
		if (event.sequenceType == "END") then
			hour = event.endTime.hour;
			minute = event.endTime.minute;
		else
			hour = event.startTime.hour;
			minute = event.startTime.minute;
		end
		return event.title, hour, minute, event.calendarType, event.sequenceType, event.eventType, event.iconTexture, event.modStatus, event.inviteStatus, event.invitedBy, event.difficulty, event.inviteType, event.sequenceIndex, event.numSequenceDays, event.difficultyName;
	else
		return nil, 0, 0, "", "", 0, "", "", 0, "", 0, 0, 0, 0, "";
	end
end


-- EquipmentSet from Deprecated_7_2_0
do
	-- Use C_EquipmentSet.SaveEquipmentSet(equipmentSetID[, newIcon]) instead
	function SaveEquipmentSet(equipmentSetName, newIcon)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		C_EquipmentSet.SaveEquipmentSet(equipmentSetID, newIcon);
	end

	-- Use C_EquipmentSet.DeleteEquipmentSet(equipmentSetID) instead
	function DeleteEquipmentSet(equipmentSetName)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		C_EquipmentSet.DeleteEquipmentSet(equipmentSetID);
	end

	-- Use C_EquipmentSet.ModifyEquipmentSet(equipmentSetID, newName, newIcon) instead
	function ModifyEquipmentSet(oldName, newName, newIcon)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(oldName);
		C_EquipmentSet.ModifyEquipmentSet(equipmentSetID, newName, newIcon);
	end

	-- Use C_EquipmentSet.IgnoreSlotForSave(slot) instead
	function EquipmentManagerIgnoreSlotForSave(slot)
		C_EquipmentSet.IgnoreSlotForSave(slot);
	end

	-- Use C_EquipmentSet.IsSlotIgnoredForSave(slot) instead
	function EquipmentManagerIsSlotIgnoredForSave(slot)
		return C_EquipmentSet.IsSlotIgnoredForSave(slot);
	end

	-- Use C_EquipmentSet.ClearIgnoredSlotsForSave() instead
	function EquipmentManagerClearIgnoredSlotsForSave()
		C_EquipmentSet.ClearIgnoredSlotsForSave();
	end

	-- Use C_EquipmentSet.UnignoreSlotForSave(slot) instead
	function EquipmentManagerUnignoreSlotForSave(slot)
		C_EquipmentSet.UnignoreSlotForSave(slot);
	end

	-- Use C_EquipmentSet.GetNumEquipmentSets() instead
	function GetNumEquipmentSets()
		return C_EquipmentSet.GetNumEquipmentSets();
	end

	-- Use C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID) instead
	function GetEquipmentSetInfo(equipmentSetIndex)
		local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
		return C_EquipmentSet.GetEquipmentSetInfo(equipmentSetIDs[equipmentSetIndex]);
	end

	-- Use C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID) instead
	function GetEquipmentSetInfoByName(equipmentSetName)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		return C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID);
	end

	-- Use C_EquipmentSet.EquipmentSetContainsLockedItems(equipmentSetID) instead
	function EquipmentSetContainsLockedItems(equipmentSetName)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		return C_EquipmentSet.EquipmentSetContainsLockedItems(equipmentSetID);
	end

	-- Use C_EquipmentSet.PickupEquipmentSet(equipmentSetID) instead
	function PickupEquipmentSetByName(equipmentSetName)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		C_EquipmentSet.PickupEquipmentSet(equipmentSetID);
	end

	-- Use C_EquipmentSet.PickupEquipmentSet(equipmentSetID) instead
	function PickupEquipmentSet(equipmentSetIndex)
		local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
		C_EquipmentSet.PickupEquipmentSet(equipmentSetIDs[equipmentSetIndex]);
	end

	-- Use C_EquipmentSet.UseEquipmentSet(equipmentSetID) instead
	function UseEquipmentSet(equipmentSetName)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		C_EquipmentSet.UseEquipmentSet(equipmentSetID);
	end

	-- Use C_EquipmentSet.CanUseEquipmentSets() instead
	function CanUseEquipmentSets()
		return C_EquipmentSet.CanUseEquipmentSets();
	end

	-- Use C_EquipmentSet.GetItemIDs(equipmentSetID) instead
	function GetEquipmentSetItemIDs(equipmentSetName, returnTable)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		returnTable = returnTable or {};
		return Mixin(returnTable, C_EquipmentSet.GetItemIDs(equipmentSetID));
	end

	-- Use C_EquipmentSet.GetItemLocations(equipmentSetID) instead
	function GetEquipmentSetLocations(equipmentSetName, returnTable)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		returnTable = returnTable or {};
		return Mixin(returnTable, C_EquipmentSet.GetItemLocations(equipmentSetID));
	end

	-- Use C_EquipmentSet.GetIgnoredSlots(equipmentSetID) instead
	function GetEquipmentSetIgnoreSlots(equipmentSetName, returnTable)
		local equipmentSetID = C_EquipmentSet.GetEquipmentSetID(equipmentSetName);
		returnTable = returnTable or {};
		return Mixin(returnTable, C_EquipmentSet.GetIgnoredSlots(equipmentSetID));
	end
end

do
	-- Power Types from deprecated_7.2.5
	SPELL_POWER_MANA = Enum.PowerType.Mana;
	SPELL_POWER_RAGE = Enum.PowerType.Rage;
	SPELL_POWER_FOCUS = Enum.PowerType.Focus;
	SPELL_POWER_ENERGY = Enum.PowerType.Energy;
	SPELL_POWER_COMBO_POINTS = Enum.PowerType.ComboPoints;
	SPELL_POWER_RUNES = Enum.PowerType.Runes;
	SPELL_POWER_RUNIC_POWER = Enum.PowerType.RunicPower;
	SPELL_POWER_SOUL_SHARDS = Enum.PowerType.SoulShards;
	SPELL_POWER_LUNAR_POWER = Enum.PowerType.LunarPower;
	SPELL_POWER_HOLY_POWER = Enum.PowerType.HolyPower;
	SPELL_POWER_ALTERNATE_POWER = Enum.PowerType.Alternate;
	SPELL_POWER_MAELSTROM = Enum.PowerType.Maelstrom;
	SPELL_POWER_CHI = Enum.PowerType.Chi;
	SPELL_POWER_INSANITY = Enum.PowerType.Insanity;
	SPELL_POWER_ARCANE_CHARGES = Enum.PowerType.ArcaneCharges;
	SPELL_POWER_FURY = Enum.PowerType.Fury;
	SPELL_POWER_PAIN = Enum.PowerType.Pain;

	-- Nothing should have been using these, but preserving since they actually existed
	SPELL_POWER_OBSOLETE = Enum.PowerType.Obsolete;
	SPELL_POWER_OBSOLETE2 = Enum.PowerType.Obsolete2;
end

--[[------------------------------------------------------------
8.1
---------------------------------------------------------------]]
function C_LFGListGetSearchResultInfo(resultID)
    --local id, activityId, title, comment, voiceChat, iLvl, honorLevel, age, numBNetFriends, numCharFriends, numGuildMates, isDelisted, leader, numMembers
    local info = C_LFGList.GetSearchResultInfo(resultID);
    if not info then return end
    return info.searchResultID, info.activityID, info.name, info.comment, info.voiceChat, info.requiredItemLevel, info.requiredHonorLevel,
    info.age, info.numBNetFriends, info.numCharFriends, info.numGuildMates, info.isDelisted, info.leaderName, info.numMembers
end

--[[------------------------------------------------------------
8.1.5
---------------------------------------------------------------]]
WorldMapTooltip = WorldMapTooltip or GameTooltip

if QuestInfoSealFrame then
    QuestInfoSealFrame._originSetPoint = QuestInfoSealFrame.SetPoint
    QuestInfoSealFrame.SetPoint = function(self, ...)
        QuestInfoSealFrame:ClearAllPoints()
        QuestInfoSealFrame._originSetPoint(self, ...)
    end
end

if QuestLogPopupDetailFrame and QuestLogPopupDetailFrame.ShowMapButton then
    QuestLogPopupDetailFrame.ShowMapButton:SetScript("PreClick", function(self)
        if InCombatLockdown() and not WorldMapFrame:IsShown() then WorldMapFrame:Show() end
    end)
    QuestLogPopupDetailFrame.ShowMapButton:SetScript("PostClick", function(self)
        self:GetParent():Hide()
    end)
end

--战斗中打开寻求组队
if LFGListUtil_GetQuestCategoryData then
    local origin = LFGListUtil_GetQuestCategoryData
    hooksecurefunc("LFGListUtil_GetQuestCategoryData", function(...)
        if InCombatLockdown() and not PVEFrame:IsVisible() then
            local activityID, categoryID, filters, questName = origin(...);
            if activityID then
                PVEFrame:Show()
            end
        end
    end)
end

--C_ChatInfo.ReportPlayer is no longer supported, addons must use C_ReportSystem.OpenReportPlayerDialog(complaintType, reportedPlayerName, reportedPlayerLocation) now
C_ChatInfo.ReportPlayer = function(complaintType, playerLocation, comment)
end

--[[------------------------------------------------------------
8.2.5
---------------------------------------------------------------]]
--- 注意参数含义和blz的不一样,是好友序号
AbyBNGetGameAccountInfo = function(friendIndex, accountIndex)
    local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex);
    local gameAccountInfo = C_BattleNet.GetGameAccountInfoByID(accountInfo.gameAccountInfo.gameAccountID, accountIndex);
    local accountInfo = C_BattleNet.GetAccountInfoByID(accountInfo.bnetAccountID);
    if gameAccountInfo and accountInfo then
        local wowProjectID = gameAccountInfo.wowProjectID or 0;
        local characterName = gameAccountInfo.characterName or "";
        local realmName = gameAccountInfo.realmName or "";
        local realmID = gameAccountInfo.realmID or 0;
        local factionName = gameAccountInfo.factionName or "";
        local raceName = gameAccountInfo.raceName or "";
        local className = gameAccountInfo.className or "";
        local areaName = gameAccountInfo.areaName or "";
        local characterLevel = gameAccountInfo.characterLevel or "";
        local richPresence = gameAccountInfo.richPresence or "";
        local gameAccountID = gameAccountInfo.gameAccountID or 0;
        local playerGuid = gameAccountInfo.playerGuid or 0;

        return	gameAccountInfo.hasFocus, characterName, gameAccountInfo.clientProgram,
        realmName, realmID, factionName, raceName, className, "", areaName, characterLevel,
        richPresence, accountInfo.customMessage, accountInfo.customMessageTime,
        gameAccountInfo.isOnline, gameAccountID, accountInfo.bnetAccountID, gameAccountInfo.isGameAFK, gameAccountInfo.isGameBusy,
        playerGuid, wowProjectID, gameAccountInfo.isWowMobile;
    end
end

--[[------------------------------------------------------------
8.3.0
---------------------------------------------------------------]]
if not UIDropDownMenu_StopCounting then UIDropDownMenu_StopCounting = noop end
if not UIDropDownMenu_StartCounting then UIDropDownMenu_StartCounting = noop end

if false then
    MAX_CONTAINER_ITEMS = 36;
    NUM_CONTAINER_COLUMNS = 4;
    ROWS_IN_BG_TEXTURE = 6;
    MAX_BG_TEXTURES = 2;
    BG_TEXTURE_HEIGHT = 512;
    CONTAINER_WIDTH = 192;
    CONTAINER_SPACING = 0;
    VISIBLE_CONTAINER_SPACING = 3;
    MINIMUM_CONTAINER_OFFSET_X = 10;
    CONTAINER_SCALE = 0.75;
    BACKPACK_MONEY_OFFSET_DEFAULT = -231;
    BACKPACK_MONEY_HEIGHT_OFFSET_PER_EXTRA_ROW = 41;
    BACKPACK_BASE_HEIGHT = 255;
    BACKPACK_HEIGHT_OFFSET_PER_EXTRA_ROW = 43;
    BACKPACK_DEFAULT_TOPHEIGHT = 255;
    BACKPACK_EXTENDED_TOPHEIGHT = 226;
    BACKPACK_BASE_SIZE = 16;
    FIRST_BACKPACK_BUTTON_OFFSET_BASE = -225;
    FIRST_BACKPACK_BUTTON_OFFSET_PER_EXTRA_ROW = 41;
    CONTAINER_BOTTOM_TEXTURE_DEFAULT_HEIGHT = 10;
    CONTAINER_BOTTOM_TEXTURE_DEFAULT_TOP_COORD = 0.330078125;
    CONTAINER_BOTTOM_TEXTURE_DEFAULT_BOTTOM_COORD = 0.349609375;
end