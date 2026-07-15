local ADDON_NAME, T = ...
local lastKnownOrderCount = 0
local EV, GameTooltip = T.Evie, T.NotGameTooltip
local function EnsureDatabaseDefaults()
	if not DFCN_PatronOffersDB then DFCN_PatronOffersDB = {} end
	local db = DFCN_PatronOffersDB
	if type(db.filters) ~= "table" then
		db.filters = {}
	end
	local f = db.filters
	if f.unlearned == nil then f.unlearned = false end
	if f.needFocus == nil then f.needFocus = false end
	if f.profitBelow == nil then f.profitBelow = false end
	if f.profitThreshold == nil then f.profitThreshold = 0 end
	if db.autoShowSummary == nil then db.autoShowSummary = false end--lnui
	if db.autoOpenRewardItems == nil then db.autoOpenRewardItems = true end
	if db.autoSwitchToCustomer == nil then db.autoSwitchToCustomer = true end
	if db.autoBuyVendorItems == nil then db.autoBuyVendorItems = false end
	if db.autoEquipProficiencyTool == nil then db.autoEquipProficiencyTool = false end
	if db.autoCompleteAllOrders == nil then db.autoCompleteAllOrders = false end
	if db.autoAdjustWithAH == nil then db.autoAdjustWithAH = false end
	if db.ignorePriceDiff == nil then db.ignorePriceDiff = false end
	if db.priceDiffThreshold == nil then db.priceDiffThreshold = 10000 end
	if db.autoSwitchActionBar == nil then db.autoSwitchActionBar = false end
	if db.switchActionBarPage == nil then db.switchActionBarPage = 2 end
	if db.autoShoppingSearch == nil then db.autoShoppingSearch = false end
	if f.showFilteredOrders == nil then f.showFilteredOrders = false end
	if db.autoUseFinishingItem == nil then db.autoUseFinishingItem = false end
	if db.autoMailManagement == nil then db.autoMailManagement = false end
	if db.silentMode == nil then db.silentMode = false end
	if db.enableRecipeToolSwitch == nil then db.enableRecipeToolSwitch = false end
	if db.finishingItemThreshold == nil then db.finishingItemThreshold = 1500 * 10000 end
	if not db.specFilters then db.specFilters = {} end
	if not db.specEnabled then db.specEnabled = {} end
	if db.summaryFrameLocked == nil then db.summaryFrameLocked = false end
end
EnsureDatabaseDefaults()
local L = newproxy(true)
local ui = {syncID = 0, manualSummaryOpen = false, autoShowSummary = DFCN_PatronOffersDB.autoShowSummary, lastShownProfId = nil}
local ORDER_COLUMN_WIDTH, COST_COLUMN_WIDTH, REWARD_COLUMN_WIDTH, PATRON_COLUMN_WIDTH = 356, 110, 130, 130
local COST_COLUMN_XOFS, REWARD_COLUMN_XOFS, PATRON_COLUMN_XOFS = ORDER_COLUMN_WIDTH, ORDER_COLUMN_WIDTH + COST_COLUMN_WIDTH, ORDER_COLUMN_WIDTH + COST_COLUMN_WIDTH + REWARD_COLUMN_WIDTH
local DUMMY_SORT = {sortType = 0, reversed = false}
local QUALITY_SLOT_ATLAS = {"Professions-Slot-Frame", "Professions-Slot-Frame-Green", "Professions-Slot-Frame-Blue", "Professions-Slot-Frame-Epic", "Professions-Slot-Frame-Legendary"}
local DIFFICULTY_ATLAS = {[0] = "Professions-Icon-Skill-High", "Professions-Icon-Skill-Medium", "Professions-Icon-Skill-Low"}
local DIFFICULTY_COLOR_CODE = {[0] = DIFFICULT_DIFFICULTY_COLOR_CODE, FAIR_DIFFICULTY_COLOR_CODE, EASY_DIFFICULTY_COLOR_CODE}
local ACUITY_ITEM_ID, KNOWLEDGE_ITEMS = 210814, {
	228729, 2, 228731, 2, 228727, 2, 228733, 2, 228739, 2, 228735, 2, 228725, 2, 228737, 2,
	228738, 1, 228730, 1, 228726, 1, 228732, 1, 228724, 1, 228734, 1, 228728, 1, 228736, 1,
}
local EXPIRE_THRESHOLDS = {"|cffa0a0a0", 6 * 3600, "|cffe8e800", 3600, "|cffd84000", -math.huge}
local TL = T.L
getmetatable(L).__call = function(_, k, a)
	return TL and TL[k] or (a or k)
end

local function SilentPrint(...)
	if DFCN_PatronOffersDB and DFCN_PatronOffersDB.silentMode then return end
	print(...)
end

local function SkinElvUI(frame)
	if not frame then return end
	local E = _G.ElvUI and unpack(_G.ElvUI)
	if not E or not E.Skins then return end
	local objType = frame:GetObjectType()
	if objType == "CheckButton" and E.Skins.HandleCheckBox then
		E.Skins:HandleCheckBox(frame)
	elseif objType == "Button" and E.Skins.HandleButton then
		E.Skins:HandleButton(frame)
	elseif objType == "EditBox" and E.Skins.HandleEditBox then
		E.Skins:HandleEditBox(frame)
	end
end

local function DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
		end
		setmetatable(copy, DeepCopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end
local orderListBackup = nil
local lastOrderSubmitTime = 0
local lastCastFinishTime = 0
local FINISHING_ITEM_ID = 247726
local HAS_AUCTIONATOR = Auctionator and Auctionator.API and Auctionator.API.v1
local checkedOrders = {}
local ITEM_IDS = {
	222546, 222547, 222548, 222549, 222550, 222551, 222552, 222553,
	222554, 222621, 222649, 224023, 224024, 224036, 224038, 224050,
	224052, 224053, 224054, 224055, 224056, 224264, 224583, 224584,
	224645, 224647, 224648, 224651, 224652, 224653, 224654, 224655,
	224656, 224657, 224658, 224780, 224781, 224782, 224807, 224817,
	224818, 224835, 224838, 225220, 225221, 225222, 225223, 225224,
	225225, 225226, 225227, 225228, 225229, 225230, 225231, 225232,
	225233, 225234, 225235, 226265, 226266, 226267, 226268, 226269,
	226270, 226271, 226272, 226276, 226277, 226278, 226279, 226280,
	226281, 226282, 226283, 226284, 226285, 226286, 226287, 226288,
	226289, 226290, 226291, 226292, 226293, 226294, 226295, 226296,
	226297, 226298, 226299, 226300, 226301, 226302, 226303, 226304,
	226305, 226306, 226307, 226308, 226309, 226310, 226311, 226312,
	226313, 226314, 226315, 226316, 226317, 226318, 226319, 226320,
	226321, 226322, 226323, 226324, 226325, 226326, 226327, 226328,
	226329, 226330, 226331, 226332, 226333, 226334, 226335, 226336,
	226337, 226338, 226339, 226340, 226341, 226342, 226343, 226344,
	226345, 226346, 226347, 226348, 226349, 226350, 226351, 226352,
	226353, 226354, 226355, 227407, 227408, 227409, 227410, 227411,
	227412, 227413, 227414, 227415, 227416, 227417, 227418, 227419,
	227420, 227421, 227422, 227423, 227424, 227425, 227426, 227427,
	227428, 227429, 227430, 227431, 227432, 227433, 227434, 227435,
	227436, 227437, 227438, 227439, 227659, 227662, 227667, 228724,
	228725, 228726, 228727, 228728, 228729, 228730, 228731, 228732,
	228733, 228734, 228735, 228736, 228737, 228738, 228739, 228773,
	228774, 228775, 228776, 228777, 228778, 228779, 232499, 232500,
	232501, 232502, 232503, 232504, 232505, 232506, 232507, 232508,
	232509, 235855, 235856, 235857, 235858, 235859, 235860, 235861,
	235862, 235863, 235864, 235865, 237496, 237506, 237507, 238465,
	238467, 238468, 238469, 238470, 238471, 238472, 238473, 238474,
	238475, 238532, 238533, 238534, 238535, 238536, 238537, 238538,
	238539, 238540, 238541, 238542, 238543, 238544, 238545, 238546,
	238547, 238548, 238549, 238550, 238551, 238552, 238553, 238554,
	238555, 238556, 238557, 238558, 238559, 238560, 238561, 238562,
	238563, 238572, 238573, 238574, 238575, 238576, 238577, 238578,
	238579, 238580, 238581, 238582, 238583, 238584, 238585, 238586,
	238587, 238588, 238589, 238590, 238591, 238592, 238593, 238594,
	238595, 238596, 238597, 238598, 238599, 238600, 238601, 238602,
	238603, 238612, 238613, 238614, 238615, 238616, 238617, 238618,
	238619, 238625, 238626, 238627, 238628, 238629, 238630, 238631,
	238632, 238633, 238634, 238635, 245755, 245756, 245757, 245758,
	245759, 245760, 245761, 245762, 245763, 245809, 245828, 246320,
	246321, 246322, 246323, 246324, 246325, 246326, 246327, 246328,
	246329, 246330, 246331, 246332, 246333, 246334, 246335, 250360,
	250443, 250444, 250445, 250922, 250923, 250924, 257599, 257600,
	257601, 258410, 258411, 259188, 259189, 259190, 259191, 259192,
	259193, 259194, 259195, 259196, 259197, 259198, 259199, 259200,
	259201, 259202, 259203, 262644, 262645, 262646, 263454, 263455,
	263456, 263458, 263459, 263460, 263461, 263462, 263463, 263464,
	267653, 267654, 267655, 224007, 227661, 238466, 263457, 224265,
	264314, 264315, 264316, 264317, 264318, 264319, 264320, 264321,
	264322, 264323, 247725, 247719, 260630, 245650, 245651, 245647,
	245648, 242650, 245644, 268297, 260534, 260536, 260537, 260538,
	260539, 260540, 260541, 260542, 260543, 260544, 260545, 264914,
	272125, 269702, 268490, 254677, 269701, 268545, 263465, 263466,
	269703, 262346, 257023, 257026, 262928, 268487, 263467, 268489,
	268488,	262938, 269234, 263433, 259334, 251970, 256055, 267299,
	260940, 260979, 260193, 250116, 250117, 263928, 263929, 263977,
	246751, 246752, 246753, 265995, 270247,	270987, 270244, 271221,
	271222, 270932, 270933, 270934, 268650,	278021, 278022, 278024,
	278025, 278026, 278027, 275690, 275691,	276387, 276388, 276389,
	276390, 263934,
}

local QUEST_RESTRICTED_ITEMS = {
	[222546] = 83725, [222547] = 83735, [222548] = 83730, [222549] = 83732,
	[222550] = 83727, [222551] = 83731,	[222552] = 83729, [222553] = 83733,
	[222554] = 83726, [222621] = 83728, [222649] = 83734, [245755] = 95127,
	[245756] = 95137, [245757] = 95131, [245758] = 95134, [245759] = 95129,
	[245760] = 95133, [245761] = 95130, [245762] = 95135, [245763] = 95128,
	[245809] = 95138, [245828] = 95136
}

local ITEM_TO_BASE_PROFESSION = {
	[222546] = 171, [222547] = 197, [222548] = 773, [222549] = 165,
	[222550] = 333, [222551] = 755, [222552] = 182, [222553] = 186,
	[222554] = 164, [222621] = 202, [222649] = 393,
	[245755] = 171, [245756] = 197, [245757] = 773, [245758] = 165,
	[245759] = 333, [245760] = 755, [245761] = 182, [245762] = 186,
	[245763] = 164, [245809] = 202, [245828] = 393
}

local STACK_RESTRICTED_ITEMS = {
	[247725] = 5, [247719] = 5, [260630] = 5, [268650] = 5, 
}

local lastFoundId = nil
local DFPO_AUTO = nil
local DFPO_AUTO_EventFrame = nil
local cachedHousingItemId = nil
local cachedTransmogItemId = nil
local lastMaterialNeedsSnapshot = nil
local reselectTimer = nil
local foundItemIsCosmetic = false
local tooltipCache = {}
local pendingPurchases = {}
local lastBagCount = {}
local function UpdateHousingCache()
	if InCombatLockdown() then return end
	cachedHousingItemId = nil
	for bag = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		if numSlots then
			for slot = 1, numSlots do
				local itemID = C_Container.GetContainerItemID(bag, slot)
				if itemID then
					local classID, subclassID = select(12, GetItemInfo(itemID))
					if classID == 20 and subclassID == 0 then
						if GetItemCount(itemID) > 0 then
							cachedHousingItemId = itemID
							return
						end
					end
				end
			end
		end
	end
end

local function UpdateTransmogCache()
	if InCombatLockdown() then return end
	cachedTransmogItemId = nil
	for bag = 0, 4 do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		if numSlots then
			for slot = 1, numSlots do
				local itemID = C_Container.GetContainerItemID(bag, slot)
				if itemID then
					local cache = tooltipCache[itemID]
					if cache == nil then
						local itemLink = C_Container.GetContainerItemLink(bag, slot)
						if itemLink then
							local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
							local isCosmetic = false
							if tooltipData and tooltipData.lines then
								for _, line in ipairs(tooltipData.lines) do
									if line.leftText == ITEM_COSMETIC then
										isCosmetic = true
										break
									end
								end
							end
							if isCosmetic then
								local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
								tooltipCache[itemID] = { isCosmetic = true, sourceID = sourceID }
							else
								tooltipCache[itemID] = { isCosmetic = false }
							end
						else
							tooltipCache[itemID] = { isCosmetic = false }
						end
						cache = tooltipCache[itemID]
					end
					if cache and cache.isCosmetic and cache.sourceID
						and not C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(cache.sourceID)
						and GetItemCount(itemID) > 0 then
						cachedTransmogItemId = itemID
						return
					end
				end
			end
		end
	end
end

local function UpdateMacroButton()
	if InCombatLockdown() then return end
	local playerProfessions = {}
	local prof1, prof2 = GetProfessions()
	for _, idx in ipairs({prof1, prof2}) do
		if idx then
			local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine = GetProfessionInfo(idx)
			if skillLine and skillLine > 0 then
				playerProfessions[skillLine] = skillLevel
			end
		end
	end
	local foundItemId = nil
	local function IsItemUsableForProfession(itemID)
		local baseID = ITEM_TO_BASE_PROFESSION[itemID]
		if not baseID then
			return true
		end
		local level = playerProfessions[baseID]
		return level and level >= 25
	end
	if lastFoundId then
		local count = GetItemCount(lastFoundId)
		if count and count > 0 then
			if IsItemUsableForProfession(lastFoundId) then
				local questId = QUEST_RESTRICTED_ITEMS[lastFoundId]
				if not questId or not C_QuestLog.IsQuestFlaggedCompleted(questId) then
					local minStack = STACK_RESTRICTED_ITEMS[lastFoundId]
					if not (minStack and count < minStack) then
						foundItemId = lastFoundId
					end
				end
			end
		end
	end
	if not foundItemId then
		for i = 1, #ITEM_IDS do
			local id = ITEM_IDS[i]
			if GetItemCount(id) > 0 then
				if IsItemUsableForProfession(id) then
					local questId = QUEST_RESTRICTED_ITEMS[id]
					if not questId or not C_QuestLog.IsQuestFlaggedCompleted(questId) then
						local minStack = STACK_RESTRICTED_ITEMS[id]
						if not (minStack and GetItemCount(id) < minStack) then
							foundItemId = id
							break
						end
					end
				end
			end
		end
	end
	if not foundItemId and cachedHousingItemId then
		if GetItemCount(cachedHousingItemId) > 0 then
			foundItemId = cachedHousingItemId
		else
			UpdateHousingCache()
			if cachedHousingItemId and GetItemCount(cachedHousingItemId) > 0 then
				foundItemId = cachedHousingItemId
			end
		end
	end
	if not foundItemId and cachedTransmogItemId then
		local cache = tooltipCache[cachedTransmogItemId]
		if cache and cache.isCosmetic and cache.sourceID
			and not C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(cache.sourceID)
			and GetItemCount(cachedTransmogItemId) > 0 then
			foundItemId = cachedTransmogItemId
		else
			tooltipCache[cachedTransmogItemId] = nil
			cachedTransmogItemId = nil
		end
	end
	lastFoundId = foundItemId
	if foundItemId then
		local cache = tooltipCache[foundItemId]
		if cache == nil then
			local itemLink = "item:" .. foundItemId
			local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
			local isCosmetic = false
			if tooltipData and tooltipData.lines then
				for _, line in ipairs(tooltipData.lines) do
					if line.leftText == ITEM_COSMETIC then
						isCosmetic = true
						break
					end
				end
			end
			if isCosmetic then
				local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
				tooltipCache[foundItemId] = { isCosmetic = true, sourceID = sourceID }
			else
				tooltipCache[foundItemId] = { isCosmetic = false }
			end
			cache = tooltipCache[foundItemId]
		end
		foundItemIsCosmetic = cache.isCosmetic or false
	else
		foundItemIsCosmetic = false
	end
	if not DFPO_AUTO then
		local btn = CreateFrame("Button", "DFPO_AUTO", UIParent, "SecureActionButtonTemplate")
		btn:SetSize(1, 1)
		btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, -10)
		btn:RegisterForClicks("AnyDown")
		btn:SetAttribute("pressAndHoldAction", true)
		btn:SetAttribute("type", "item")
		btn:SetAttribute("typerelease", "item")
		btn:Hide()
		DFPO_AUTO = btn
	end
	if foundItemId and not foundItemIsCosmetic then
		DFPO_AUTO:SetAttribute("item", "item:" .. foundItemId)
	else
		DFPO_AUTO:SetAttribute("item", nil)
	end
end

function DFPO_UseTransmog()
	if InCombatLockdown() then return end
	if not foundItemIsCosmetic then return end
	local id = lastFoundId
	if not id then return end
	C_Item.UseItemByName(id)
end

if not DFPO_AUTO_EventFrame then
	local f = CreateFrame("Frame")
	f:RegisterEvent("BAG_UPDATE_DELAYED")
	local pending = false
	f:SetScript("OnEvent", function()
		if pending then return end
		pending = true
		C_Timer.After(0.1, function()
			pending = false
			UpdateHousingCache()
			UpdateTransmogCache()
			UpdateMacroButton()
		end)
	end)
	DFPO_AUTO_EventFrame = f
end

UpdateHousingCache()
UpdateTransmogCache()
UpdateMacroButton()

local PROFESSION_TOOLS_BY_ID = {
	[2906] = {245777, 245778, 259205},
	[2907] = {238013, 238018, 246537},
	[2909] = {244175, 244176, 244177},
	[2910] = {244717, 244718, 259183},
	[2913] = {245775, 245776, 259209},
	[2914] = {244713, 244714, 259181},
	[2915] = {238012, 238017, 246536},
	[2918] = {244707, 244708, 259177},

	[2871] = {222575, 222576},
	[2872] = {222486, 222494},
	[2874] = {224114, 224115, 224116},
	[2875] = {221797, 221798},
	[2878] = {222573, 222574},
	[2879] = {221792, 221793},
	[2880] = {222484, 222492},
	[2883] = {221786, 221787},
}

local PROFESSION_ACCESSORY1_BY_ID = {
	[2906] = {239641, 239635, 267052},
	[2907] = {244627, 244628, 244813},
	[2909] = {240956, 240960, 246527},
	[2910] = {244618, 244624, 244810},
	[2913] = {240953, 240957, 246524},
	[2914] = {244629, 244630, 244814},
	[2915] = {244619, 244625, 244811},
	[2918] = {239646, 239640, 267062},

	[2871] = {222845, 222850},
	[2872] = {219873, 219874},
	[2874] = {215121, 215125},
	[2875] = {219864, 219870},
	[2878] = {215117, 215122},
	[2879] = {219875, 219876},
	[2880] = {219865, 219871},
	[2883] = {222483, 222491},
}

local PROFESSION_ACCESSORY2_BY_ID = {
	[2906] = {244620, 244626, 244812},
	[2907] = {237948, 237952, 259230},
	[2909] = {239643, 239637, 267056},
	[2910] = {244709, 244710, 259171},
	[2913] = {240954, 240958, 246525},
	[2914] = {240955, 240959, 246526},
	[2915] = {237947, 237951, 259232},
	[2918] = {237946, 237950, 259234},

	[2871] = {219866, 219872},
	[2872] = {222487, 222495},
	[2874] = {222843, 222849},
	[2875] = {221788, 221789},
	[2878] = {215119, 215123},
	[2879] = {215120, 215124},
	[2880] = {222485, 222493},
	[2883] = {222844, 222852},
}

local UPGRADE_PROF_MAP = {
	[2823] = 2906, [2822] = 2907, [2825] = 2909, [2827] = 2910,
	[2828] = 2913, [2829] = 2914, [2830] = 2915, [2831] = 2918,
	[2871] = 2906, [2872] = 2907, [2874] = 2909, [2875] = 2910,
	[2878] = 2913, [2879] = 2914, [2880] = 2915, [2883] = 2918,
}

local BASE_TO_MIDNIGHT = {
	[171] = 2906, [164] = 2907, [333] = 2909, [202] = 2910,
	[773] = 2913, [755] = 2914, [165] = 2915, [197] = 2918,
}

local CHILD_TO_CURRENCY_ID = {
	[2906] = 3256,
	[2907] = 3257,
	[2909] = 3258,
	[2910] = 3259,
	[2913] = 3261,
	[2914] = 3262,
	[2915] = 3263,
	[2918] = 3266,
}

local ITEM_TO_PROFESSION = {}

local function GetRealItemLevelFromLink(itemLink)
	if not itemLink or type(itemLink) ~= "string" then return 0 end
	local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
	if not tooltipData or not tooltipData.lines then return 0 end
	for _, line in ipairs(tooltipData.lines) do
		if line.itemLevel and type(line.itemLevel) == "number" then
			return line.itemLevel
		end
	end
	return 0
end

local function GetProficiencyBonusValue(itemLink, statType)
	if not itemLink then return 0 end
	local stats = C_Item.GetItemStats(itemLink)
	if not stats then return 0 end
	return stats[statType == "P" and "ITEM_MOD_MULTICRAFT_SHORT" or statType == "I" and "ITEM_MOD_INGENUITY_SHORT" or "ITEM_MOD_RESOURCEFULNESS_SHORT"] or 0
end

local function GetCurrentEquippedAccessoryID(slotID)
	local link = GetInventoryItemLink("player", slotID)
	if not link then return nil end
	return tonumber(link:match("item:(%d+)"))
end

local function GetBestAccessoryItemLinkAndLevel(accessoryTable)
	local acc = accessoryTable or {}
	if #acc == 0 then return nil, 0 end
	local bestLink, bestILvl = nil, 0
	for bag = 0, NUM_BAG_SLOTS do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID then
				for _, targetID in ipairs(acc) do
					if itemID == targetID then
						local link = C_Container.GetContainerItemLink(bag, slot)
						if link then
							local ilvl = GetRealItemLevelFromLink(link)
							if ilvl > bestILvl then
								bestILvl = ilvl
								bestLink = link
							end
						end
						break
					end
				end
			end
		end
	end
	return bestLink, bestILvl
end

local function GetCurrentProfessionSlot(childSkillLineID)
	local prof1, prof2 = GetProfessions()
	prof1 = prof1 or 0
	prof2 = prof2 or 0
	if prof1 == childSkillLineID then
		return 1
	elseif prof2 == childSkillLineID then
		return 2
	else
		return 1
	end
end


local function EquipBestAccessory(force)
	if not force and not (DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoEquipProficiencyTool) then
		return
	end
	if InCombatLockdown() then return end
	local childSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
	if not childSkillLineID or childSkillLineID == 0 then
		return
	end
	local slotIdx = GetCurrentProfessionSlot(childSkillLineID)
	local accessorySlots = (slotIdx == 1) and {21, 22} or {24, 25}
	local accessoryTables = {
		PROFESSION_ACCESSORY1_BY_ID[childSkillLineID] or {},
		PROFESSION_ACCESSORY2_BY_ID[childSkillLineID] or {}
	}
	for i, slotID in ipairs(accessorySlots) do
		local accTable = accessoryTables[i] or {}
		if accTable and #accTable > 0 then
			local currentID = GetCurrentEquippedAccessoryID(slotID)
			local isCurrentMatching = false
			if currentID then
				for _, tid in ipairs(accTable) do
					if tid == currentID then
						isCurrentMatching = true
						break
					end
				end
			end
			local bestLink, bestILvl = GetBestAccessoryItemLinkAndLevel(accTable)
			if bestLink then
				local currentILvl = 0
				if currentID then
					local currentLink = GetInventoryItemLink("player", slotID)
					if currentLink then
						currentILvl = GetRealItemLevelFromLink(currentLink)
					end
				end
				if not isCurrentMatching or (bestILvl > currentILvl) then
					C_Item.EquipItemByName(bestLink)
					local name = select(2, GetItemInfo(bestLink)) or L"Item"
					SilentPrint(L"Msg_EquippedTrinket" .. name)
				end
			end
		end
	end
end

local function GetBestProficiencyToolItemID(professionID, statType)
	local toolIDs = PROFESSION_TOOLS_BY_ID[professionID] or {}
	if #toolIDs == 0 then
		return nil, 0, 0
	end
	local bestLink = nil
	local bestBonus = 0
	local bestItemLevel = 0
	for bag = 0, NUM_BAG_SLOTS do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID then
				for _, targetID in ipairs(toolIDs) do
					if itemID == targetID then
						local realLink = C_Container.GetContainerItemLink(bag, slot)
						if realLink then
							local bonus = GetProficiencyBonusValue(realLink, statType)
							local itemLevel = GetRealItemLevelFromLink(realLink)
							if bonus > bestBonus then
								bestBonus = bonus
								bestItemLevel = itemLevel
								bestLink = realLink
							elseif bonus > 0 and bonus == bestBonus and itemLevel > bestItemLevel then
								bestItemLevel = itemLevel
								bestLink = realLink
							end
						end
						break
					end
				end
			end
		end
	end
	if bestBonus == 0 then
		for _, slot in ipairs({20, 23}) do
			local link = GetInventoryItemLink("player", slot)
			if link then
				local id = tonumber(link:match("item:(%d+)"))
				if id then
					for _, tid in ipairs(toolIDs) do
						if id == tid then
							local bonus = GetProficiencyBonusValue(link, statType)
							if bonus > bestBonus then
								bestBonus = bonus
								bestItemLevel = GetRealItemLevelFromLink(link)
								bestLink = link
							end
						end
					end
				end
			end
		end
	end
	return bestLink, bestBonus, bestItemLevel
end

local function GetCurrentEquippedToolForProfession(professionChildID, statType)
	for _, slot in ipairs({20, 23}) do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local id = tonumber(link:match("item:(%d+)"))
			if id and ITEM_TO_PROFESSION[id] == professionChildID then
				local bonus = GetProficiencyBonusValue(link, statType)
				local ilvl = GetRealItemLevelFromLink(link)
				return id, bonus, ilvl, slot
			end
		end
	end
	return nil, 0, 0, nil
end

local function EquipBestProficiencyTool(statType, force)
	if not force and not (DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoEquipProficiencyTool) then
		return
	end
	if InCombatLockdown() then return end
	local childSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
	if not childSkillLineID or childSkillLineID == 0 then
		return
	end
	local currentID, currentBonus, currentILvl = GetCurrentEquippedToolForProfession(childSkillLineID, statType)
	local bestLink, bestBonus, bestILvl = GetBestProficiencyToolItemID(childSkillLineID, statType)
	if not bestLink and childSkillLineID < 2900 then
		local otherID = UPGRADE_PROF_MAP[childSkillLineID]
		if otherID then
			bestLink, bestBonus, bestILvl = GetBestProficiencyToolItemID(otherID, statType)
			if bestLink then
				currentID, currentBonus, currentILvl = GetCurrentEquippedToolForProfession(otherID, statType)
			end
		end
	end
	local shouldEquip = false
	if bestLink and bestBonus > 0 then
		if not currentID then
			shouldEquip = true
		elseif bestBonus > currentBonus then
			shouldEquip = true
		elseif bestBonus == currentBonus and bestILvl > currentILvl then
			shouldEquip = true
		end
	end
	if shouldEquip then
		C_Item.EquipItemByName(bestLink)
		local name = select(2, GetItemInfo(bestLink)) or L"Item"
		SilentPrint(L"Msg_EquippedTool" .. name .. " (+" .. bestBonus .. (statType == "P" and ITEM_MOD_MULTICRAFT_SHORT or statType == "I" and ITEM_MOD_INGENUITY_SHORT or ITEM_MOD_RESOURCEFULNESS_SHORT) .. ")")
	end
	EquipBestAccessory(force)
end

do
	for profID, toolIDs in pairs(PROFESSION_TOOLS_BY_ID) do
		for _, toolID in ipairs(toolIDs) do ITEM_TO_PROFESSION[toolID] = profID end
	end
	for profID, accIDs in pairs(PROFESSION_ACCESSORY1_BY_ID) do
		for _, accID in ipairs(accIDs) do ITEM_TO_PROFESSION[accID] = profID end
	end
	for profID, accIDs in pairs(PROFESSION_ACCESSORY2_BY_ID) do
		for _, accID in ipairs(accIDs) do ITEM_TO_PROFESSION[accID] = profID end
	end
end

local function GetBestToolForProfession(professionID)
	local toolIDs = PROFESSION_TOOLS_BY_ID[professionID] or {}
	if #toolIDs == 0 then return nil end
	local bestLink = nil
	local bestItemLevel = 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID then
				for _, targetID in ipairs(toolIDs) do
					if itemID == targetID then
						local link = C_Container.GetContainerItemLink(bag, slot)
						if link then
							local itemLevel = GetRealItemLevelFromLink(link)
							if itemLevel > bestItemLevel then
								bestItemLevel = itemLevel
								bestLink = link
							end
						end
						break
					end
				end
			end
		end
	end
	return bestLink
end

local function GetBestAccessoryForProfession(professionID, accessoryIndex, currentSlotID)
	local accTable = (accessoryIndex == 1)
		and PROFESSION_ACCESSORY1_BY_ID[professionID]
		or PROFESSION_ACCESSORY2_BY_ID[professionID]
	local acc = accTable or {}
	if #acc == 0 then return nil end
	local bestLink, bestILvl = nil, 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID then
				for _, targetID in ipairs(acc) do
					if itemID == targetID then
						local link = C_Container.GetContainerItemLink(bag, slot)
						if link then
							local ilvl = GetRealItemLevelFromLink(link)
							if ilvl > bestILvl then bestILvl, bestLink = ilvl, link end
						end
						break
					end
				end
			end
		end
	end
	if not bestLink then
		for _, slotID in ipairs({21, 22, 24, 25}) do
			if slotID ~= currentSlotID then
				local link = GetInventoryItemLink("player", slotID)
				if link then
					local itemID = tonumber(link:match("item:(%d+)"))
					if itemID then
						for _, targetID in ipairs(acc) do
							if itemID == targetID then
								local ilvl = GetRealItemLevelFromLink(link)
								if ilvl > bestILvl then bestILvl, bestLink = ilvl, link end
								break
							end
						end
					end
				end
			end
		end
	end
	return bestLink
end

local lastRestoreTime = 0
local function RestoreHighVersionGear()
	if not (DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoEquipProficiencyTool) then return end
	local now = GetTime()
	if now - lastRestoreTime < 1 then return end
	lastRestoreTime = now
	if InCombatLockdown() then return end
	local anyChanged = false
	for _, slotID in ipairs({20, 23}) do
		local link = GetInventoryItemLink("player", slotID)
		if link then
			local itemID = tonumber(link:match("item:(%d+)"))
			if itemID and ITEM_TO_PROFESSION[itemID] then
				local prof = ITEM_TO_PROFESSION[itemID]
				local targetProf = prof
				if prof and prof <= 2900 and UPGRADE_PROF_MAP[prof] then
					targetProf = UPGRADE_PROF_MAP[prof]
				end
				if targetProf then
					local currentLink = GetInventoryItemLink("player", slotID)
					local currentILvl = currentLink and GetRealItemLevelFromLink(currentLink) or 0
					local bestLink = GetBestToolForProfession(targetProf)
					if bestLink then
						local bestILvl = GetRealItemLevelFromLink(bestLink)
						if bestILvl > currentILvl then
							C_Item.EquipItemByName(bestLink)
							anyChanged = true
						end
					end
				end
			end
		end
	end
	local SLOT_TO_ACC_TYPE = {
		[21] = 1,
		[22] = 2,
		[24] = 1,
		[25] = 2,
	}
	for _, slotID in ipairs({21, 22, 24, 25}) do
		local link = GetInventoryItemLink("player", slotID)
		if link then
			local itemID = tonumber(link:match("item:(%d+)"))
			if itemID and ITEM_TO_PROFESSION[itemID] then
				local prof = ITEM_TO_PROFESSION[itemID]
				if prof and prof <= 2900 and UPGRADE_PROF_MAP[prof] then
					local highProf = UPGRADE_PROF_MAP[prof]
					local accType = SLOT_TO_ACC_TYPE[slotID]
					local bestLink = GetBestAccessoryForProfession(highProf, accType, slotID)
					if bestLink then
						local alreadyEquipped = false
						for _, checkSlot in ipairs({21, 22, 24, 25}) do
							if checkSlot ~= slotID then
								local checkLink = GetInventoryItemLink("player", checkSlot)
								if checkLink then
									local checkID = tonumber(checkLink:match("item:(%d+)"))
									if checkID == tonumber(bestLink:match("item:(%d+)")) then
										alreadyEquipped = true
										break
									end
								end
							end
						end
						if not alreadyEquipped and GetInventoryItemLink("player", slotID) ~= bestLink then
							C_Item.EquipItemByName(bestLink)
							anyChanged = true
						end
					end
				end
			end
		end
	end
	if anyChanged then
		SilentPrint(L"Msg_RestoredGear")
	end
end

if ProfessionsFrame then
	hooksecurefunc(ProfessionsFrame, "Hide", RestoreHighVersionGear)
else
	C_Timer.After(0.5, function()
		if ProfessionsFrame then
			hooksecurefunc(ProfessionsFrame, "Hide", RestoreHighVersionGear)
		end
	end)
end

local function UpdateProfessionCurrencyDisplay()
	if not ui or not ui.currencyDisplay then return end
	local childID = C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID()
	if not childID or childID == 0 then
		ui.currencyDisplay:Hide()
		return
	end
	local highProf = UPGRADE_PROF_MAP and UPGRADE_PROF_MAP[childID] or childID
	local currencyID = CHILD_TO_CURRENCY_ID[highProf]
	if not currencyID then
		ui.currencyDisplay:Hide()
		return
	end
	local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not info or not info.quantity then
		ui.currencyDisplay:Hide()
		return
	end
	local quantity = info.quantity
	local iconFileID = info.iconFileID or 4643975
	if ui.currencyDisplay.currencyIcon then
		ui.currencyDisplay.currencyIcon:SetTexture(iconFileID)
	end
	if ui.currencyDisplay.currencyText then
		ui.currencyDisplay.currencyText:SetText(quantity)
		if quantity >= 600 then
			ui.currencyDisplay.currencyText:SetTextColor(0, 1, 0)
		else
			ui.currencyDisplay.currencyText:SetTextColor(1, 1, 1)
		end
	end
	ui.currencyDisplay:Show()
end

local currencyEventFrame = CreateFrame("Frame")
currencyEventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
currencyEventFrame:SetScript("OnEvent", function()
	if ui and ui.currencyDisplay and ui.currencyDisplay:IsShown() then
		UpdateProfessionCurrencyDisplay()
	end
end)

local function SwitchActionBarIfNeeded()
	if not DFCN_PatronOffersDB.autoSwitchActionBar then return end
	if InCombatLockdown() then return end
	local page = DFCN_PatronOffersDB.switchActionBarPage
	if page and page >= 2 and page <= 6 then
		ChangeActionBarPage(page)
	end
end

local function SafeGetMoneyString(amount, includePlus)
	if not amount or type(amount) ~= "number" then
		return "0g"
	end
	local ok, result = pcall(GetMoneyString, amount, includePlus)
	if ok then
		return result
	else
		local copper = amount % 100
		local silver = math.floor((amount % 10000) / 100)
		local gold = math.floor(amount / 10000)
		local parts = {}
		if gold > 0 then table.insert(parts, gold .. "g") end
		if silver > 0 then table.insert(parts, silver .. "s") end
		if copper > 0 then table.insert(parts, copper .. "c") end
		if #parts == 0 then parts = {"0g"} end
		return table.concat(parts)
	end
end

local function CalculateItemValue(itemID)
	if HAS_AUCTIONATOR then
		local vendorPrice = Auctionator.API.v1.GetVendorPriceByItemID and Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
		local ahPrice = Auctionator.API.v1.GetAuctionPriceByItemID(AUCTIONATOR_L_REAGENT_SEARCH, itemID)
		if vendorPrice and vendorPrice > 0 and ahPrice then
			return math.min(vendorPrice, ahPrice)
		elseif vendorPrice and vendorPrice > 0 then
			return vendorPrice
		elseif ahPrice then
			return ahPrice
		end
	end
	return 0
end

local function GetLowestCostReagentInfo(reagents)
	local cheapestItemID, cheapestPrice, cheapestQuality = nil, math.huge, 1
	for _, reagent in ipairs(reagents) do
		local itemID = reagent.itemID
		if itemID then
			local price = CalculateItemValue(itemID)
			if price and price > 0 then
				if price < cheapestPrice then
					cheapestPrice = price
					cheapestItemID = itemID
					cheapestQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 1
				elseif price == cheapestPrice then
					local q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 1
					if q > cheapestQuality then
						cheapestItemID = itemID
						cheapestQuality = q
					end
				end
			end
		end
	end
	if cheapestPrice == math.huge then
		local first = reagents[1]
		if first and first.itemID then
			cheapestItemID = first.itemID
			cheapestQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(first.itemID) or 1
			cheapestPrice = 0
		end
	end
	return cheapestItemID, cheapestPrice, cheapestQuality
end

local function GetQualityVersionsFromReagents(reagents)
	local byQuality = {}
	for _, reagent in ipairs(reagents) do
		local itemID = reagent.itemID
		if itemID then
			local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 1
			byQuality[quality] = { itemID = itemID, quality = quality }
		end
	end
	local result = {}
	for q = 1, 5 do
		if byQuality[q] then
			table.insert(result, byQuality[q])
		end
	end
	return result
end

local function GetReagentCount(itemID, specificQuality)
	local baseQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
	if specificQuality and baseQuality and baseQuality >= 1 and baseQuality <= 3 then
		local baseID = itemID - (baseQuality - 1)
		local targetID = baseID + (specificQuality - 1)
		return C_Item.GetItemCount(targetID, true, false, true, true)
	end
	if baseQuality and baseQuality >= 1 and baseQuality <= 3 then
		local baseID = itemID - (baseQuality - 1)
		local total = 0
		for ql = 1, 3 do
			total = total + C_Item.GetItemCount(baseID + (ql - 1), true, false, true, true)
		end
		return total
	else
		return C_Item.GetItemCount(itemID, true, false, true, true)
	end
end

local function CheckMaterialsWithoutAuctionator(orderInfo)
	if not orderInfo.recipeSchematic then return true end
	for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
		if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
			local required = slot.quantityRequired
			local satisfied = false
			for _, reagent in ipairs(slot.reagents) do
				local itemID = reagent.itemID
				if itemID then
					local playerHas = GetReagentCount(itemID, nil)
					if playerHas >= required then
						satisfied = true
						break
					end
				end
			end
			if not satisfied then
				return true
			end
		end
	end
	return false
end

local function IsOrderMissingReagents(orderInfo)
	if not orderInfo.recipeSchematic then return true end
	if HAS_AUCTIONATOR then
		local ignorePriceDiff = DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff or false
		local threshold = (DFCN_PatronOffersDB and DFCN_PatronOffersDB.priceDiffThreshold) or 10000
		for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
			if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
				local requiredQuantity = slot.quantityRequired
				local reagents = slot.reagents
				if not ignorePriceDiff then
					local cheapestItemID, _, cheapestQuality = GetLowestCostReagentInfo(reagents)
					if cheapestItemID then
						local playerHasQuantity = GetReagentCount(cheapestItemID, cheapestQuality)
						if playerHasQuantity < requiredQuantity then
							return true
						end
					else
						return true
					end
				else
					local priceList = {}
					for _, reagent in ipairs(reagents) do
						local itemID = reagent.itemID
						if itemID then
							local price = CalculateItemValue(itemID) or 0
							local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 1
							table.insert(priceList, { itemID = itemID, price = price, quality = quality })
						end
					end
					table.sort(priceList, function(a, b) return a.price < b.price end)
					local cheapest = priceList[1]
					if not cheapest then
						return true
					end
					local playerHasCheapest = GetReagentCount(cheapest.itemID, cheapest.quality)
					if playerHasCheapest >= requiredQuantity then
					else
						local foundAlternative = false
						for _, candidate in ipairs(priceList) do
							if candidate.itemID ~= cheapest.itemID then
								local priceDiff = candidate.price - cheapest.price
								if priceDiff <= threshold then
									local playerHas = GetReagentCount(candidate.itemID, candidate.quality)
									if playerHas >= requiredQuantity then
										foundAlternative = true
										break
									end
								end
							end
						end
						if not foundAlternative then
							return true
						end
					end
				end
			end
		end
		return false
	else
		return CheckMaterialsWithoutAuctionator(orderInfo)
	end
end

local function GetOrderGuestMaterialsValue(orderInfo)
	if not orderInfo or not orderInfo.reagents then
		return 0
	end
	local isGuestSlot = {}
	if orderInfo.recipeSchematic and orderInfo.recipeSchematic.reagentSlotSchematics then
		for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
			if slot.required and slot.cover == true then
				isGuestSlot[slot.slotIndex] = true
			end
		end
	end
	local total = 0
	for _, reagent in ipairs(orderInfo.reagents) do
		local slotIndex = reagent.slotIndex
		if isGuestSlot[slotIndex] and reagent.reagentInfo then
			local ri = reagent.reagentInfo
			local itemID = ri.reagent and ri.reagent.itemID
			if itemID then
				local quantity = ri.quantity or 1
				local price = CalculateItemValue(itemID)
				if price and price > 0 then
					total = total + price * quantity
				end
			end
		end
	end
	return total
end

local function ShouldUseFinishingItem(orderInfo)
	if not DFCN_PatronOffersDB.autoUseFinishingItem then return false end
	local guestValue = GetOrderGuestMaterialsValue(orderInfo)
	local threshold = DFCN_PatronOffersDB.finishingItemThreshold or (1500 * 10000)
	if guestValue < threshold then return false end
	local count = C_Item.GetItemCount(FINISHING_ITEM_ID, true, false, true, true)
	if not count or count == 0 then return false end
	return true
end

local function EnsureOrderSchematic(order)
	if not order then return order end
	if order.recipeSchematic then return order end
	local spellID = order.spellID or (order.recipeInfo and order.recipeInfo.spellID)
	if not spellID then return order end
	local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, order and order.isRecraft)
	if schematic then
		order.recipeSchematic = schematic
		if order.reagents then
			for _, reagentInfo in ipairs(order.reagents) do
				local slotIndex = reagentInfo.slotIndex
				for _, slot in ipairs(schematic.reagentSlotSchematics) do
					if slot.slotIndex == slotIndex then
						slot.cover = true
						break
					end
				end
			end
		end
	end
	return order
end

local function ApplyFinishingItemToCurrentOrder()
	local orderView = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
	if not orderView or not orderView:IsShown() then return false end
	local order = orderView.order
	if not order then return false end
	order = EnsureOrderSchematic(order)
	local schematic = order.recipeSchematic
	if schematic and schematic.reagentSlotSchematics then
		local supported = false
		for _, slot in ipairs(schematic.reagentSlotSchematics) do
			if slot.reagents then
				for _, reagent in ipairs(slot.reagents) do
					if reagent.itemID == FINISHING_ITEM_ID then
						supported = true
						break
					end
				end
			end
			if supported then break end
		end
		if not supported then return false end
	else
		return false
	end
	local guestValue = GetOrderGuestMaterialsValue(order)
	local threshold = DFCN_PatronOffersDB.finishingItemThreshold or (1500 * 10000)	
	if not ShouldUseFinishingItem(order) then return false end	
	local schematicForm = orderView.OrderDetails and orderView.OrderDetails.SchematicForm
	if not schematicForm or not schematicForm.transaction then return false end
	local transaction = schematicForm.transaction
	local recipeID = order.recipeInfo and order.recipeInfo.recipeID or order.spellID
	local skillLineAbilityID = order.skillLineAbilityID or (order.recipeInfo and order.recipeInfo.skillLineAbilityID)
	local function isSlotLocked(slotFrame)
		if not recipeID or not skillLineAbilityID then return true end
		local slotIndex = slotFrame:GetSlotIndex()
		if not slotIndex then return true end
		local schematic = order.recipeSchematic
		if not schematic then return true end
		local schemSlot = nil
		for _, ss in ipairs(schematic.reagentSlotSchematics) do
			if ss.slotIndex == slotIndex then
				schemSlot = ss
				break
			end
		end
		if not schemSlot or not schemSlot.slotInfo or not schemSlot.slotInfo.mcrSlotID then
			return true
		end
		local locked = C_TradeSkillUI.GetReagentSlotStatus(
			schemSlot.slotInfo.mcrSlotID,
			recipeID,
			skillLineAbilityID
		)
		return locked
	end
	local finishingSlots = schematicForm:GetSlotsByReagentType(Enum.CraftingReagentType.Finishing)
	if not finishingSlots or #finishingSlots == 0 then return false end
	local targetSlot = nil
	for _, slot in ipairs(finishingSlots) do
		if not isSlotLocked(slot) then
			targetSlot = slot
			break
		end
	end
	if not targetSlot then return false end
	local slotIndex = targetSlot:GetSlotIndex()
	if not slotIndex then return false end
	local requiredQty = 1
	if order.recipeSchematic and order.recipeSchematic.reagentSlotSchematics then
		for _, ss in ipairs(order.recipeSchematic.reagentSlotSchematics) do
			if ss.slotIndex == slotIndex then
				requiredQty = ss.quantityRequired or 1
				break
			end
		end
	end
	local reagentInfo = { itemID = FINISHING_ITEM_ID }
	targetSlot:SetReagent(reagentInfo)
	targetSlot:Update()
	if transaction.OverwriteAllocation then
		transaction:OverwriteAllocation(slotIndex, reagentInfo, requiredQty)
		if transaction.SetManuallyAllocated then
			transaction:SetManuallyAllocated(true)
		end
	end
	if schematicForm.TriggerEvent then
		schematicForm:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
	end
	local finishingItemLink = select(2, GetItemInfo(FINISHING_ITEM_ID)) or ("|T133004:14:14|t" .. FINISHING_ITEM_ID)
	local guestValueStr = SafeGetMoneyString(guestValue, true)
	local thresholdStr = SafeGetMoneyString(threshold, true)
	SilentPrint(string.format(L"Msg_AutoFinishing", guestValueStr, thresholdStr, finishingItemLink))
	return true
end

local function RefreshHeaderFilterTexts(activeFilters)
	if not ui then return end
	if not activeFilters then
		local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
		local professionID = professionInfo and professionInfo.professionID or 0
		local enablePerSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[professionID] or false
		if enablePerSpec then
			activeFilters = DFCN_PatronOffersDB.specFilters[professionID] or {}
		else
			activeFilters = DFCN_PatronOffersDB.filters
		end
	end
	local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
	local professionID = professionInfo and professionInfo.professionID or 0
	local enablePerSpec = (DFCN_PatronOffersDB.specEnabled or {})[professionID] or false
	local baseText = L"You craft/provide:"
	if enablePerSpec and professionInfo.professionName and professionInfo.professionName ~= "" then
		baseText = baseText .. "|cff00ff00" .. professionInfo.professionName .. "|r"
	end
	local parts = {}
	if activeFilters.unlearned then
		table.insert(parts, L"Unlearned")
	end
	if activeFilters.needFocus then
		table.insert(parts, L"FocusCost")
	end
	if activeFilters.profitBelow then
		local thresholdGold = math.floor((activeFilters.profitThreshold or 0) / 10000)
		table.insert(parts, "<" .. thresholdGold .. "G")
	end
	local suffix = ""
	if #parts > 0 then
		suffix = " |Tinterface\\common\\voicechat-muted:12:12:|t|cffff0000" .. table.concat(parts, "/") .. "|r"
	end
	if ui.headers and ui.headers[1] then
		ui.headers[1]:SetText(baseText .. suffix)
	end
	if ui.summaryCraftHeader and ui.summaryCraftHeader.textLabel then
		ui.summaryCraftHeader.textLabel:SetText(baseText .. suffix)
		ui.summaryCraftHeader.baseText = baseText
	end
end

local lastRawOrderCount = 0
local function CalculateReagentsTotal(recipeSchematic)
	local totalCost = 0
	local hasUnknownPrice = false
	for _, slot in ipairs(recipeSchematic.reagentSlotSchematics) do
		if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
			local cheapestPrice = math.huge
			for _, reagent in ipairs(slot.reagents) do
				local itemID = reagent.itemID
				if itemID then
					local price = CalculateItemValue(itemID)
					if price and price > 0 then
						cheapestPrice = math.min(cheapestPrice, price)
					else
						hasUnknownPrice = true
					end
				end
			end
			if cheapestPrice == math.huge then
				hasUnknownPrice = true
			else
				totalCost = totalCost + (cheapestPrice * slot.quantityRequired)
			end
		end
	end
	return totalCost, hasUnknownPrice
end

local function nextReagentOption(a, i)
	i = (i or 0) + 1
	local ri = a and a[i]
	if not ri then return end
	local iid, cid = ri.itemID, ri.currencyID
	local cn, cq = 0, nil
	if iid then
		local baseQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(iid)
		local itemID = iid
		if baseQuality and baseQuality >= 1 and baseQuality <= 3 then
			itemID = iid - (baseQuality - 1) + (baseQuality - 1)
		end
		cn = C_Item.GetItemCount(itemID, true, false, true, true)
	elseif cid then
		cn = C_CurrencyInfo.GetCurrencyInfo(cid)
		cn = cn and cn.quantity or 0
	end
	return i, cn, cq, iid, cid
end

local Acquire, Release
do
	local P, C, S, umeta = {}, {}, {}, {__metatable = false}
	local function newArray()
		local r = setmetatable({}, umeta)
		return r, r
	end
	local function GetShadow(o)
		return S[o]
	end
	local function SetShadow(o, s)
		S[o], S[s] = s, o
	end
	local function ReleaseOwnedTooltip(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end
	local function Order_OnClick(self)
		ProfessionsFrame.OrdersPage:ViewOrder(GetShadow(self).orderInfo)
	end
	function C.OrderRow()
		local f, s, t = CreateFrame("Button"), {}
		f:Hide()
		f:SetSize(770, 6 + 16 + 32)
		local ib = Acquire("IconButton", f)
		ib.root:SetSize(48, 48)
		ib.root:SetPoint("TOPLEFT", 2, -2)
		s.mainIcon = ib
		f.ProductIcon = ib.root
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", ib.root, "TOPRIGHT", 4, -3)
		t:SetJustifyV("TOP")
		t:SetFont(GameFontNormal:GetFont(), 14)
		t, s.request, f.Request = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOPLEFT", COST_COLUMN_XOFS + 4, -18)
		t:SetTextColor(1, 1, 1)
		s.craftingCost, f.CraftingCost = t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", REWARD_COLUMN_XOFS + 4, -3)
		t:SetJustifyV("TOP")
		t, s.reward, f.Reward = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", PATRON_COLUMN_XOFS + 4, -3)
		t:SetFont(t:GetFont(), 12)
		t:SetJustifyV("TOP")
		t, s.patron, f.Patron = t, t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", PATRON_COLUMN_XOFS + 4, -3 - 16)
		t:SetFont(t:GetFont(), 13)
		t, s.timeLeft, f.TimeLeft = t, t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("TOPLEFT", PATRON_COLUMN_XOFS + 4, -3 - 16 - 18)
		t:SetFont(t:GetFont(), 14)
		t:SetTextColor(1, 1, 1)
		t, s.totalReward, f.TotalReward = t, t, t
		t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		t:SetPoint("LEFT", ib.root, "RIGHT", 4, -18 - 16)
		t:SetText("|A:Professions-Icon-Customer:19:21:|a |cff00ff00" .. PROFESSIONS_CUSTOMER_ORDER_REAGENTS_ALL .. "|r")
		t:SetJustifyV("MIDDLE")
		t:SetHeight(16)
		s.artText = t
		local readyCheck = f:CreateTexture(nil, "OVERLAY")
		readyCheck:SetSize(22, 22)
		readyCheck:SetAtlas("transmog-icon-tick-small")
		readyCheck:SetVertexColor(0, 1, 0)
		readyCheck:Hide()
		s.materialReady = readyCheck
		f.materialReady = readyCheck
		local readyText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		readyText:SetText(L"Ready")
		readyText:SetFont(GameFontNormal:GetFont(), 14)
		readyText:SetTextColor(0, 1, 0)
		readyText:Hide()
		s.materialReadyText = readyText
		f.materialReadyText = readyText
		f.AllReagentsProvidedText = t
		t = f:CreateTexture(nil, "BACKGROUND", nil, -4)
		t:SetAllPoints()
		t:SetColorTexture(1, 1, 1, 0.025)
		s.root, s.evenBG, s.reagents, s.rewards = f, t, {}, {}
		s.reagentsW, f.Reagents = newArray()
		s.rewardsW, f.Rewards = newArray()
		f:SetHighlightAtlas("talents-pvpflyout-rowhighlight")
		f:GetHighlightTexture():SetTextureSliceMargins(100, 10, 50, 10)
		f:GetHighlightTexture():SetVertexColor(0.1, 0.6, 1)
		f:SetScript("OnClick", Order_OnClick)
		SetShadow(f, s)
		local redOverlay = f:CreateTexture(nil, "OVERLAY")
		redOverlay:SetAllPoints()
		redOverlay:SetColorTexture(0.85, 0.15, 0.15, 0.22)
		redOverlay:Hide()
		s.redOverlay = redOverlay
		f.redOverlay = redOverlay
		local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		cb:SetSize(30, 30)
		cb:SetPoint("RIGHT", f, "RIGHT", -10, 0)
		cb:SetScript("OnClick", function(self)
			local orderID = s.orderInfo and s.orderInfo.orderID
			if orderID then
				checkedOrders[orderID] = self:GetChecked()
				local parentRow = self:GetParent()
				local shadow = GetShadow(parentRow)
				if shadow and shadow.redOverlay then
					shadow.redOverlay:SetShown(not self:GetChecked())
				end
				if ui.manualSummaryOpen then
					if ui.updateFilterAndResync then
						ui.updateFilterAndResync()
					end
				end
			end
		end)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_DeselectCheckbox", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		s.checkbox = cb
		f.checkbox = cb
		return f
	end

	local function Icon_OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", -self:GetWidth(), -14)
		local s, o = GetShadow(self), ""
		if s.item then
			GameTooltip:SetHyperlink(type(s.item) == "number" and "item:" .. s.item or s.item)
		elseif s.currency then
			GameTooltip:SetCurrencyByID(s.currency)
		end
		for _, cn, cq in nextReagentOption, s.altReagents do
			if cn > 0 then
				o = (o ~= "" and o .. " / " or "") .. cn .. (cq or "")
			end
		end
		if o ~= "" or s.extraText then
			GameTooltip:AddLine(" ")
		end
		if o ~= "" then
			GameTooltip:AddLine(NORMAL_FONT_COLOR_CODE .. L"Available:" .. "|r " .. HIGHLIGHT_FONT_COLOR_CODE .. o, 1, 1, 1)
		end
		if s.extraText then
			local nc = NORMAL_FONT_COLOR
			GameTooltip:AddLine(s.extraText, nc.r, nc.g, nc.b, 1)
		end
		GameTooltip:Show()
	end

	function C.IconButton()
		local f, s, t = CreateFrame("Frame"), {}
		f:SetSize(32, 32)
		f:Hide()
		t = f:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints()
		t:SetTexture("Interface/Icons/Temp")
		s.icon = t
		f.icon = t
		t = f:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
		t:SetJustifyH("RIGHT")
		t:SetPoint("BOTTOMRIGHT", -2, 2)
		s.count = t
		f.count = t
		t = f:CreateTexture(nil, "ARTWORK", nil, 2)
		t:SetAllPoints()
		t:SetAtlas("Professions-Slot-Frame")
		s.border = t
		f.border = t
		t = f:CreateMaskTexture()
		t:SetTexture("Interface/FrameGeneral/UIFrameIconMask")
		t:SetAllPoints(s.icon)
		s.icon:AddMaskTexture(t)
		f.mask = t
		s.root = f
		f:SetPropagateMouseMotion(true)
		f:SetPropagateMouseClicks(true)
		f:SetScript("OnEnter", Icon_OnEnter)
		f:SetScript("OnLeave", ReleaseOwnedTooltip)
		SetShadow(f, s)
		return f
	end

	local function ColumnHeader_OnClick(self, b)
		ui.cycleSortOrder(self:GetID(), b == "RightButton")
	end

	function C.RootUI()
		local root, h, t = CreateFrame("Frame", "PatronOffersRoot", ProfessionsFrame.OrdersPage.BrowseFrame), {}
		root:SetSize(800, 543)
		root:Hide()
		t = root:CreateTexture(nil, "BACKGROUND")
		t:SetPoint("TOPLEFT", 3, -0.5)
		t:SetPoint("BOTTOMRIGHT", -4, 0)
		t:SetAtlas("auctionhouse-background-index", false)
		local btn = CreateFrame("Button", nil, root)
		btn:SetPoint("TOPRIGHT", root:GetParent(), "TOPRIGHT", -40, -50)
		btn:SetSize(225, 36)
		btn:SetHitRectInsets(4, 4, 4, 4)
		local bgTex = btn:CreateTexture(nil, "BACKGROUND")
		bgTex:SetAtlas("CraftingOrder-RemainingOrders-Frame", true)
		bgTex:SetTextureSliceMargins(8, 8, 8, 8)
		bgTex:SetAllPoints()
		ui.version = btn
		local fontPath, _, fontFlags = GameFontNormal:GetFont()
		local fsTitle = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fsTitle:SetFont(fontPath, 14, fontFlags)
		fsTitle:SetPoint("TOP", btn, "TOP", 0, -5)
		fsTitle:SetTextColor(0.6, 0.6, 0.6)
		local fsSub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fsSub:SetFont(fontPath, 12, fontFlags)
		fsSub:SetPoint("TOP", fsTitle, "BOTTOM", 0, -2)
		fsSub:SetTextColor(1, 1, 1)
		btn.fsTitle = fsTitle
		btn.fsSub = fsSub
		local function UpdateVersionButtonColor(btn)
			local currentChild = C_TradeSkillUI.GetProfessionChildSkillLineID()
			local normalTex = btn:GetNormalTexture()
			if not normalTex then return end
			if currentChild and currentChild >= 2900 then
				normalTex:SetVertexColor(0.9, 0.9, 0.1)
			else
				normalTex:SetVertexColor(0.9, 0.1, 0.1)
			end
		end
		ui.UpdateVersionButtonColor = UpdateVersionButtonColor
		local versionToggleBtn = CreateFrame("Button", nil, root)
		versionToggleBtn:SetSize(30, 30)
		versionToggleBtn:SetPoint("RIGHT", btn, "LEFT", -2, 0)
		versionToggleBtn:SetNormalAtlas("decor-placement-list-active")
		versionToggleBtn:SetHighlightAtlas("decor-placement-list-active")
		local highlightTex = versionToggleBtn:GetHighlightTexture()
		if highlightTex then
			highlightTex:SetVertexColor(0.9, 0.9, 0.1)
		end
		UpdateVersionButtonColor(versionToggleBtn)
		versionToggleBtn:SetScript("OnClick", function()
			if InCombatLockdown() then return end
			local currentChild = C_TradeSkillUI.GetProfessionChildSkillLineID()
			if not currentChild or currentChild == 0 then return end

			local targetChild = nil
			if currentChild < 2900 then
				targetChild = UPGRADE_PROF_MAP[currentChild]
				if not targetChild then
					local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(currentChild)
					local baseID = info and info.parentProfessionID
					if baseID and BASE_TO_MIDNIGHT[baseID] then
						targetChild = BASE_TO_MIDNIGHT[baseID]
					end
				end
			else
				for low, high in pairs(UPGRADE_PROF_MAP) do
					if high == currentChild and low >= 2871 and low <= 2883 then
						targetChild = low
						break
					end
				end
				if not targetChild then
					for low, high in pairs(UPGRADE_PROF_MAP) do
						if high == currentChild then
							targetChild = low
							break
						end
					end
				end
			end
			if not targetChild then return end
			C_TradeSkillUI.SetProfessionChildSkillLineID(targetChild)
			local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
			if profInfo and ProfessionsFrame and ProfessionsFrame.SetProfessionInfo then
				ProfessionsFrame:SetProfessionInfo(profInfo, false)
			end
			if ProfessionsFrame and ProfessionsFrame.OrdersPage then
				ProfessionsFrame.OrdersPage:SetCraftingOrderType(3)
				if ui.root and ui.root:IsShown() and syncOrderList then
					syncOrderList("profession-changed")
				end
			end
			UpdateVersionButtonColor(versionToggleBtn)
			if GameTooltip:IsOwned(versionToggleBtn) and GameTooltip:IsShown() then
				versionToggleBtn:GetScript("OnEnter")(versionToggleBtn)
			end
		end)
		versionToggleBtn:SetScript("OnEnter", function(self)
			UpdateVersionButtonColor(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local currentChild = C_TradeSkillUI.GetProfessionChildSkillLineID()
			if currentChild and currentChild < 2900 then
				GameTooltip:SetText(L"Switch TWW")
			else
				GameTooltip:SetText(L"Switch Mightlight")
			end
			GameTooltip:Show()
		end)
		versionToggleBtn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.versionToggleBtn = versionToggleBtn
		local function GetDataFreshness()
			local cbUnlearned, cbNeedFocus, cbProfitBelow, editBox
			if not HAS_AUCTIONATOR then return nil end
			local itemID = 2770
			local age = Auctionator.API.v1.GetAuctionAgeByItemID("DFCN_PatronOffers", itemID)
			if age then
				local days = math.floor(age + 0.5)
				if days == 0 then return L"Today"
				elseif days == 1 then return L"1DayAgo"
				else return string.format(L"DaysAgo", days) end
			else
				return L"NoData"
			end
		end
		local function GetColoredFreshness(freshness)
			if freshness == L"Today" then
				return "|cFF00FF00" .. freshness .. "|r"
			elseif freshness:find(L"NoData") then
				return "|cFFFF0000" .. freshness .. "|r"
			else
				local days = tonumber(freshness:match(L"DaysAgoPattern"))
				if days then
					if days == 1 then
						return "|cFF00FF00" .. freshness .. "|r"
					elseif days > 1 then
						return "|cFFFF7F00" .. freshness .. "|r"
					end
				end
			end
			return freshness
		end
		if HAS_AUCTIONATOR then
			fsTitle:SetText(L"Price Source: Auctionator")
			local freshness = GetDataFreshness()
			local coloredFreshness = GetColoredFreshness(freshness)
			fsSub:SetText(L"AH Scan Time: " .. coloredFreshness)
		else
			fsSub:SetText("")
			fsTitle:ClearAllPoints()
			fsTitle:SetPoint("CENTER", btn, "CENTER", 0, 0)
			fsTitle:SetText(L"Price Source: Missing Auctionator")
		end
		if HAS_AUCTIONATOR then
			root:SetScript("OnShow", function()
				local freshness = GetDataFreshness()
				local coloredFreshness = GetColoredFreshness(freshness)
				btn.fsSub:SetText(L"AH Scan Time: " .. coloredFreshness)
			end)
		end
		local filterDropdownButton = CreateFrame("Button", nil, ui.version:GetParent(), "BackdropTemplate")
		filterDropdownButton:SetSize(180, 25)
		filterDropdownButton:SetPoint("TOPLEFT", ui.version, "TOPLEFT", 0, 25)
		filterDropdownButton:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		filterDropdownButton:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
		filterDropdownButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		local buttonText = filterDropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		buttonText:SetFont(GameFontNormal:GetFont(), 12)
		buttonText:SetPoint("LEFT", 8, 0)
		buttonText:SetText(L"Patron Filters | Settings")
		filterDropdownButton.text = buttonText
		local arrow = filterDropdownButton:CreateTexture(nil, "OVERLAY")
		arrow:SetPoint("RIGHT", -6, 2)
		arrow:SetSize(16, 16)
		arrow:SetAtlas("UI-Journeys-Delve-Arrow-down-pressed")
		filterDropdownButton:SetScript("OnEnter", function()
			filterDropdownButton:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
			filterDropdownButton:SetBackdropBorderColor(1, 1, 1, 1)
		end)
		filterDropdownButton:SetScript("OnLeave", function()
			filterDropdownButton:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
			filterDropdownButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		end)
		filterDropdownButton:SetScript("OnClick", function()
			updateFilterAndResync()
			if filterDropdownPanel:IsShown() then
				filterDropdownPanel:Hide()
			else
				filterDropdownPanel:Show()
			end
		end)
		local currencyDisplay = CreateFrame("Frame", nil, root, "BackdropTemplate")
		if currencyDisplay then
			currencyDisplay:SetPoint("LEFT", filterDropdownButton, "RIGHT", 2, 0)
			currencyDisplay:SetSize(75, 25)
			currencyDisplay:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 3, right = 3, top = 3, bottom = 3 }
			})
			currencyDisplay:SetBackdropColor(0, 0, 0, 0.7)
			currencyDisplay:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
			local currencyIcon = currencyDisplay:CreateTexture(nil, "OVERLAY")
			if currencyIcon then
				currencyIcon:SetSize(20, 20)
				currencyIcon:SetPoint("LEFT", 3, 0)
			end
			local currencyText = currencyDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			if currencyText then
				currencyText:SetPoint("LEFT", currencyIcon, "RIGHT", 3, 0)
				currencyText:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
				currencyText:SetTextColor(1, 1, 0.8)
			end
			currencyDisplay.currencyIcon = currencyIcon
			currencyDisplay.currencyText = currencyText
			currencyDisplay:Hide()
			ui.currencyDisplay = currencyDisplay
		end
		local filterDropdownPanel = CreateFrame("Frame", nil, ui.version:GetParent(), "BackdropTemplate")
		filterDropdownPanel:SetSize(265, 575)
		filterDropdownPanel:SetPoint("TOPLEFT", filterDropdownButton, "BOTTOMLEFT", 0, -2)
		filterDropdownPanel:SetBackdrop({
			bgFile = nil,
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		filterDropdownPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		local bgTex = filterDropdownPanel:CreateTexture(nil, "BACKGROUND")
		bgTex:SetAllPoints()
		bgTex:SetColorTexture(0, 0, 0, 0.8)
		filterDropdownPanel.bgTex = bgTex
		filterDropdownPanel:EnableMouse(true)
		filterDropdownPanel:SetFrameStrata("DIALOG")
		filterDropdownPanel:Hide()
		filterDropdownPanel:HookScript("OnShow", function(self)
			self:RegisterEvent("GLOBAL_MOUSE_DOWN")
		end)
		filterDropdownPanel:HookScript("OnHide", function(self)
			self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		end)
		filterDropdownPanel:SetScript("OnEvent", function(self, event, button)
			if event == "GLOBAL_MOUSE_DOWN" and self:IsShown() then
				if not self:IsMouseOver(0,0,0,0) and not filterDropdownButton:IsMouseOver(0,0,0,0) then
					self:Hide()
				end
			end
		end)
		filterDropdownPanel:HookScript("OnShow", function(self)
			for _, child in ipairs({self:GetChildren()}) do
				SkinElvUI(child)
			end
		end)
		local function updateFilterAndResync()
			if not DFCN_PatronOffersDB.filters then DFCN_PatronOffersDB.filters = {} end
			if DFCN_PatronOffersDB.filters.profitThreshold == nil then DFCN_PatronOffersDB.filters.profitThreshold = 0 end
			local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
			local professionID = professionInfo and professionInfo.professionID or 0 
			local enablePerSpec = (DFCN_PatronOffersDB.specEnabled or {})[professionID] or false
			if ui.cbPerSpec then
				local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
				local profID = profInfo and profInfo.professionID or 0
				local profName = profInfo and profInfo.professionName or ""
				if profID == 0 or profName == "" then
					ui.cbPerSpec.text:SetText(L"(No Profession) Enable Indep. Filter")
					ui.cbPerSpec:SetEnabled(false)
					ui.cbPerSpec:SetChecked(false)
				else
					ui.cbPerSpec.text:SetText(" |cff00ff00" .. profName .. L" Enable Indep. Filter")
					ui.cbPerSpec:SetEnabled(true)
					ui.cbPerSpec:SetChecked(enablePerSpec)
				end
			end
			local activeFilters
			if enablePerSpec then
				if not DFCN_PatronOffersDB.specFilters then
					DFCN_PatronOffersDB.specFilters = {}
				end
				if not DFCN_PatronOffersDB.specFilters[professionID] then
					DFCN_PatronOffersDB.specFilters[professionID] = {}
				end
				activeFilters = DFCN_PatronOffersDB.specFilters[professionID]
				if activeFilters.unlearned == nil then activeFilters.unlearned = false end
				if activeFilters.needFocus == nil then activeFilters.needFocus = false end
				if activeFilters.profitBelow == nil then activeFilters.profitBelow = false end
				if activeFilters.profitThreshold == nil then activeFilters.profitThreshold = 0 end
				if activeFilters.showFilteredOrders == nil then activeFilters.showFilteredOrders = false end
			else
				activeFilters = DFCN_PatronOffersDB.filters
			end
			if cbUnlearned then cbUnlearned:SetChecked(activeFilters.unlearned) end
			if cbNeedFocus then cbNeedFocus:SetChecked(activeFilters.needFocus) end
			if cbProfitBelow then cbProfitBelow:SetChecked(activeFilters.profitBelow) end
			if ui.editBox then ui.editBox:SetText(tostring((activeFilters.profitThreshold or 0) / 10000)) end
			if ui.cbAutoOpenReward then
				ui.cbAutoOpenReward:SetChecked(DFCN_PatronOffersDB.autoOpenRewardItems)
				ui.cbAutoOpenReward:SetScript("OnClick", function(self)
					DFCN_PatronOffersDB.autoOpenRewardItems = self:GetChecked()
				end)
			end
			if ui.cbAutoSwitchToCustomer then
				ui.cbAutoSwitchToCustomer:SetChecked(DFCN_PatronOffersDB.autoSwitchToCustomer)
			end
			if ui.autoShowCheckbox then
				ui.autoShowCheckbox:SetChecked(DFCN_PatronOffersDB.autoShowSummary)
				ui.autoShowSummary = DFCN_PatronOffersDB.autoShowSummary
			end
			if filterDropdownButton and filterDropdownButton.text then
				local hasFilter = activeFilters.unlearned or activeFilters.needFocus or activeFilters.profitBelow
				filterDropdownButton.text:SetTextColor(hasFilter and 1 or 1, hasFilter and 0 or 1, hasFilter and 0 or 1)
			end
			if ui.cbAutoAdjustWithAH then
				ui.cbAutoAdjustWithAH:SetChecked(DFCN_PatronOffersDB.autoAdjustWithAH)
			end
			if ui.cbAutoEquipTool then
				ui.cbAutoEquipTool:SetChecked(DFCN_PatronOffersDB.autoEquipProficiencyTool)
			end
			if ui.cbAutoBuyVendor then
				ui.cbAutoBuyVendor:SetChecked(DFCN_PatronOffersDB.autoBuyVendorItems)
			end
			if ui.cbAutoCompleteAll then
				ui.cbAutoCompleteAll:SetChecked(DFCN_PatronOffersDB.autoCompleteAllOrders)
			end
			if ui.cbShowFilteredOrders then
				ui.cbShowFilteredOrders:SetChecked(activeFilters.showFilteredOrders)
			end
			if ui.cbIgnorePriceDiff then
				ui.cbIgnorePriceDiff:SetChecked(DFCN_PatronOffersDB.ignorePriceDiff)
			end
			if ui.thresholdEditBox then
				ui.thresholdEditBox:SetText(tostring(DFCN_PatronOffersDB.priceDiffThreshold / 10000))
			end
			if ui.cbAutoShoppingSearch then
				ui.cbAutoShoppingSearch:SetChecked(DFCN_PatronOffersDB.autoShoppingSearch)
			end
			if ui.cbAutoMailManagement then
				ui.cbAutoMailManagement:SetChecked(DFCN_PatronOffersDB.autoMailManagement)
			end
			if ui.cbAutoUseFinishing then
				ui.cbAutoUseFinishing:SetChecked(DFCN_PatronOffersDB.autoUseFinishingItem)
			end
			if ui.finishingThresholdEdit then
				ui.finishingThresholdEdit:SetText(tostring(DFCN_PatronOffersDB.finishingItemThreshold / 10000))
			end
			if ui.cbSilentMode then
				ui.cbSilentMode:SetChecked(DFCN_PatronOffersDB.silentMode)
			end
			if ui.cbEnableRecipeToolSwitch then
				ui.cbEnableRecipeToolSwitch:SetChecked(DFCN_PatronOffersDB.enableRecipeToolSwitch)
			end
			if ui.cbAutoSwitchActionBar then
				ui.cbAutoSwitchActionBar:SetChecked(DFCN_PatronOffersDB.autoSwitchActionBar)
				ui.actionBarPageEdit:SetText(tostring(DFCN_PatronOffersDB.switchActionBarPage))
				ui.cbAutoSwitchActionBar:SetScript("OnClick", function(self)
					local checked = self:GetChecked()
					DFCN_PatronOffersDB.autoSwitchActionBar = checked
					if InCombatLockdown() then return end
					if checked then
						if ui and ui.root and ui.root:IsShown() then
							local page = DFCN_PatronOffersDB.switchActionBarPage
							if page and page >= 2 and page <= 6 then
								ChangeActionBarPage(page)
							end
						end
					else
						ChangeActionBarPage(1)
					end
				end)
				ui.actionBarPageEdit:SetScript("OnEnterPressed", function(self)
					local val = tonumber(self:GetText()) or 2
					if val < 2 then val = 2 elseif val > 6 then val = 6 end
					DFCN_PatronOffersDB.switchActionBarPage = val
					self:SetText(tostring(val))
					self:ClearFocus()
					if DFCN_PatronOffersDB.autoSwitchActionBar and ui and ui.root and ui.root:IsShown() then
						local page = DFCN_PatronOffersDB.switchActionBarPage
						if page >= 2 and page <= 6 and not InCombatLockdown() then
							ChangeActionBarPage(page)
						end
					end
				end)
				ui.actionBarPageEdit:SetScript("OnEscapePressed", function(self)
					self:SetText(tostring(DFCN_PatronOffersDB.switchActionBarPage))
					self:ClearFocus()
				end)
				ui.actionBarPageEdit:SetScript("OnEditFocusLost", function(self)
					local val = tonumber(self:GetText()) or 2
					if val < 2 then val = 2 elseif val > 6 then val = 6 end
					DFCN_PatronOffersDB.switchActionBarPage = val
					self:SetText(tostring(val))
				end)
			end
			local function saveFilterValue(checkbox, key)
				local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
				local pid = profInfo and profInfo.professionID or 0
				local perSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[pid] or false
				local target = perSpec and (DFCN_PatronOffersDB.specFilters[pid] or {}) or DFCN_PatronOffersDB.filters
				if target.showFilteredOrders then
					wipe(checkedOrders)
				end
				target[key] = checkbox:GetChecked()
				updateFilterAndResync()
			end
			if cbUnlearned then
				cbUnlearned:SetScript("OnClick", function(self) saveFilterValue(self, "unlearned") end)
			end
			if ui.cbShowFilteredOrders then
				ui.cbShowFilteredOrders:SetScript("OnClick", function(self)
					local newValue = self:GetChecked()
					local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
					local pid = profInfo and profInfo.professionID or 0
					local perSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[pid] or false
					local target = perSpec and (DFCN_PatronOffersDB.specFilters[pid] or {}) or DFCN_PatronOffersDB.filters
					if newValue ~= target.showFilteredOrders then
						wipe(checkedOrders)
					end
					saveFilterValue(self, "showFilteredOrders")
				end)
			end
			if cbNeedFocus then
				cbNeedFocus:SetScript("OnClick", function(self) saveFilterValue(self, "needFocus") end)
			end
			if cbProfitBelow then
				cbProfitBelow:SetScript("OnClick", function(self) saveFilterValue(self, "profitBelow") end)
			end
			if ui.editBox then
				ui.editBox:SetScript("OnEnterPressed", function(self)
					local val = tonumber(self:GetText()) or 0
					local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
					local pid = profInfo and profInfo.professionID or 0
					local perSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[pid] or false
					local target
					if perSpec then
						if not DFCN_PatronOffersDB.specFilters[pid] then DFCN_PatronOffersDB.specFilters[pid] = {} end
						target = DFCN_PatronOffersDB.specFilters[pid]
					else
						target = DFCN_PatronOffersDB.filters
					end
					target.profitThreshold = val * 10000
					self:ClearFocus()
					updateFilterAndResync()
					if target.showFilteredOrders then
						wipe(checkedOrders)
					end
				end)
				ui.editBox:SetScript("OnEscapePressed", function(self)
					local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
					local pid = profInfo and profInfo.professionID or 0
					local perSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[pid] or false
					local active
					if perSpec then
						active = DFCN_PatronOffersDB.specFilters[pid] or {}
					else
						active = DFCN_PatronOffersDB.filters
					end
					self:SetText(tostring((active.profitThreshold or 0) / 10000))
					self:ClearFocus()
				end)
				ui.editBox:SetScript("OnEditFocusLost", function(self)
					local val = tonumber(self:GetText()) or 0
					local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
					local pid = profInfo and profInfo.professionID or 0
					local perSpec = DFCN_PatronOffersDB.specEnabled and DFCN_PatronOffersDB.specEnabled[pid] or false
					local target
					if perSpec then
						if not DFCN_PatronOffersDB.specFilters[pid] then DFCN_PatronOffersDB.specFilters[pid] = {} end
						target = DFCN_PatronOffersDB.specFilters[pid]
					else
						target = DFCN_PatronOffersDB.filters
					end
					target.profitThreshold = val * 10000
					updateFilterAndResync()
					if target.showFilteredOrders then
						wipe(checkedOrders)
					end
				end)
			end
			if cbShowFilteredOrders then
				cbShowFilteredOrders:SetChecked(activeFilters.showFilteredOrders)
			end
			RefreshHeaderFilterTexts(activeFilters)
			if ui.root and ui.root:IsVisible() then
				ui.forceResync = "filter-changed"
			else
				syncOrderList("filter-changed")
			end
		end
		cbUnlearned = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbUnlearned:SetPoint("TOPLEFT", 8, -8)
		cbUnlearned:SetSize(22, 22)
		cbUnlearned.text = cbUnlearned:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbUnlearned.text:SetPoint("LEFT", cbUnlearned, "RIGHT", 0, 0)
		cbUnlearned.text:SetText(L"Hide Unlearned Orders")
		cbUnlearned:SetChecked(DFCN_PatronOffersDB.filters.unlearned)
		cbUnlearned:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_HideUnlearned", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbUnlearned:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbUnlearned:SetScript("OnClick", function(self)
			if not DFCN_PatronOffersDB.filters then DFCN_PatronOffersDB.filters = {} end
			DFCN_PatronOffersDB.filters.unlearned = self:GetChecked()
			updateFilterAndResync()
		end)
		cbNeedFocus = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbNeedFocus:SetPoint("TOPLEFT", cbUnlearned, "BOTTOMLEFT", 0, -4)
		cbNeedFocus:SetSize(22, 22)
		cbNeedFocus.text = cbNeedFocus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbNeedFocus.text:SetPoint("LEFT", cbNeedFocus, "RIGHT", 0, 0)
		cbNeedFocus.text:SetText(L"Hide Conc Orders")
		cbNeedFocus:SetChecked(DFCN_PatronOffersDB.filters.needFocus)
		cbNeedFocus:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_HideFocus", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbNeedFocus:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbNeedFocus:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.filters.needFocus = self:GetChecked()
			updateFilterAndResync()
		end)
		cbProfitBelow = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbProfitBelow:SetPoint("TOPLEFT", cbNeedFocus, "BOTTOMLEFT", 0, -4)
		cbProfitBelow:SetSize(22, 22)
		cbProfitBelow.text = cbProfitBelow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbProfitBelow.text:SetPoint("LEFT", cbProfitBelow, "RIGHT", 0, 0)
		cbProfitBelow.text:SetText(L"Hide Profit Below")
		cbProfitBelow:SetChecked(DFCN_PatronOffersDB.filters.profitBelow)
		cbProfitBelow:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_HideProfitBelow", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbProfitBelow:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbProfitBelow:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.filters.profitBelow = self:GetChecked()
			updateFilterAndResync()
		end)
		local cbPerSpec = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbPerSpec:SetPoint("TOPLEFT", cbProfitBelow, "BOTTOMLEFT", 0, -4)
		cbPerSpec:SetSize(22, 22)
		cbPerSpec.text = cbPerSpec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbPerSpec.text:SetPoint("LEFT", cbPerSpec, "RIGHT", 0, 0)
		cbPerSpec.text:SetText(L"Enable Per-Profession Filter")
		cbPerSpec:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_PerProfessionFilter", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbPerSpec:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbPerSpec:SetScript("OnClick", function(self)
			local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
			local professionID = professionInfo and professionInfo.professionID or 0
			if not DFCN_PatronOffersDB.specEnabled then
				DFCN_PatronOffersDB.specEnabled = {}
			end
			DFCN_PatronOffersDB.specEnabled[professionID] = self:GetChecked()
			local activeTarget = (DFCN_PatronOffersDB.specEnabled[professionID])
				and (DFCN_PatronOffersDB.specFilters[professionID] or {})
				or DFCN_PatronOffersDB.filters
			if activeTarget.showFilteredOrders then
				wipe(checkedOrders)
			end
			updateFilterAndResync()
		end)
		ui.cbPerSpec = cbPerSpec
		local cbShowFilteredOrders = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbShowFilteredOrders:SetPoint("TOPLEFT", cbPerSpec, "BOTTOMLEFT", 0, -4)
		cbShowFilteredOrders:SetSize(22, 22)
		cbShowFilteredOrders.text = cbShowFilteredOrders:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbShowFilteredOrders.text:SetPoint("LEFT", cbShowFilteredOrders, "RIGHT", 0, 0)
		cbShowFilteredOrders.text:SetText(L"Show Filtered Orders")
		cbShowFilteredOrders:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_ShowFiltered", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbShowFilteredOrders:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbShowFilteredOrders = cbShowFilteredOrders
		local dividerLine = filterDropdownPanel:CreateTexture(nil, "OVERLAY")
		dividerLine:SetPoint("TOPLEFT", cbShowFilteredOrders, "BOTTOMLEFT", 0, -8)
		dividerLine:SetPoint("TOPRIGHT", filterDropdownPanel, "TOPRIGHT", -15, -6)
		dividerLine:SetHeight(1)
		dividerLine:SetColorTexture(0.2, 0.2, 0.2, 1)
		local highlight = filterDropdownPanel:CreateTexture(nil, "OVERLAY")
		highlight:SetPoint("TOPLEFT", dividerLine, "TOPLEFT", 0, 1)
		highlight:SetPoint("TOPRIGHT", dividerLine, "TOPRIGHT", 0, 1)
		highlight:SetHeight(1)
		highlight:SetColorTexture(1, 1, 1, 0.3)
		local autoShowCheckbox = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		autoShowCheckbox:SetPoint("TOPLEFT", dividerLine, "BOTTOMLEFT", 0, -8)
		autoShowCheckbox:SetSize(22, 22)
		autoShowCheckbox.text = autoShowCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		autoShowCheckbox.text:SetPoint("LEFT", autoShowCheckbox, "RIGHT", 0, 0)
		autoShowCheckbox.text:SetText(L"Auto-Open Shopping Helper")
		autoShowCheckbox:SetChecked(DFCN_PatronOffersDB.autoShowSummary)
		autoShowCheckbox:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoOpenShopping", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		autoShowCheckbox:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		autoShowCheckbox:SetScript("OnClick", function(self)
			local isChecked = self:GetChecked()
			ui.autoShowSummary = isChecked
			DFCN_PatronOffersDB.autoShowSummary = isChecked
			if not isChecked and SummaryFrame then
				SummaryFrame:Hide()
			end
		end)
		ui.autoShowSummary = DFCN_PatronOffersDB.autoShowSummary
		if not DFCN_PatronOffersDB.autoShowSummary and SummaryFrame and SummaryFrame:IsShown() then
			SummaryFrame:Hide()
		end
		ui.autoShowCheckbox = autoShowCheckbox
		local cbAutoSwitchToCustomer = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoSwitchToCustomer:SetPoint("TOPLEFT", autoShowCheckbox, "BOTTOMLEFT", 0, -4)
		cbAutoSwitchToCustomer:SetSize(22, 22)
		cbAutoSwitchToCustomer.text = cbAutoSwitchToCustomer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoSwitchToCustomer.text:SetPoint("LEFT", cbAutoSwitchToCustomer, "RIGHT", 0, 0)
		cbAutoSwitchToCustomer.text:SetText(L"Auto-Navigate to Patron Tab")
		cbAutoSwitchToCustomer:SetChecked(DFCN_PatronOffersDB.autoSwitchToCustomer)
		cbAutoSwitchToCustomer:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoNavigatePatron", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoSwitchToCustomer:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoSwitchToCustomer:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoSwitchToCustomer = self:GetChecked()
		end)
		ui.cbAutoSwitchToCustomer = cbAutoSwitchToCustomer
		local cbAutoOpenReward = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoOpenReward:SetPoint("TOPLEFT", cbAutoSwitchToCustomer, "BOTTOMLEFT", 0, -4)
		cbAutoOpenReward:SetSize(22, 22)
		cbAutoOpenReward.text = cbAutoOpenReward:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoOpenReward.text:SetPoint("LEFT", cbAutoOpenReward, "RIGHT", 0, 0)
		cbAutoOpenReward.text:SetText(L"Auto-Open Reward Chest")
		cbAutoOpenReward:SetChecked(DFCN_PatronOffersDB.autoOpenRewardItems)
		cbAutoOpenReward:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoOpenReward", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoOpenReward:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoOpenReward:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoOpenRewardItems = self:GetChecked()
		end)
		ui.cbAutoOpenReward = cbAutoOpenReward
		local cbAutoAdjustWithAH = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoAdjustWithAH:SetPoint("TOPLEFT", cbAutoOpenReward, "BOTTOMLEFT", 0, -4)
		cbAutoAdjustWithAH:SetSize(22, 22)
		cbAutoAdjustWithAH.text = cbAutoAdjustWithAH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoAdjustWithAH.text:SetPoint("LEFT", cbAutoAdjustWithAH, "RIGHT", 0, 0)
		cbAutoAdjustWithAH.text:SetText(L"Force AH+Profession Side-by-Side")
		cbAutoAdjustWithAH:SetChecked(DFCN_PatronOffersDB.autoAdjustWithAH)
		cbAutoAdjustWithAH:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_ForceAHSideBySide", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoAdjustWithAH:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoAdjustWithAH:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoAdjustWithAH = self:GetChecked()
		end)
		ui.cbAutoAdjustWithAH = cbAutoAdjustWithAH
		local cbAutoEquipTool = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoEquipTool:SetPoint("TOPLEFT", cbAutoAdjustWithAH, "BOTTOMLEFT", 0, -4)
		cbAutoEquipTool:SetSize(22, 22)
		cbAutoEquipTool.text = cbAutoEquipTool:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoEquipTool.text:SetPoint("LEFT", cbAutoEquipTool, "RIGHT", 0, 0)
		cbAutoEquipTool.text:SetText(L"Auto-Equip Tool")
		cbAutoEquipTool:SetChecked(DFCN_PatronOffersDB.autoEquipProficiencyTool)
		cbAutoEquipTool:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoEquipTool", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoEquipTool:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoEquipTool:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoEquipProficiencyTool = self:GetChecked()
		end)
		ui.cbAutoEquipTool = cbAutoEquipTool
		local cbAutoBuyVendor = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoBuyVendor:SetPoint("TOPLEFT", cbAutoEquipTool, "BOTTOMLEFT", 0, -4)
		cbAutoBuyVendor:SetSize(22, 22)
		cbAutoBuyVendor.text = cbAutoBuyVendor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoBuyVendor.text:SetPoint("LEFT", cbAutoBuyVendor, "RIGHT", 0, 0)
		cbAutoBuyVendor.text:SetText(L"Auto-Buy Missing Vendor Mats")
		cbAutoBuyVendor:SetChecked(DFCN_PatronOffersDB.autoBuyVendorItems)
		cbAutoBuyVendor:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoBuyVendor", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoBuyVendor:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoBuyVendor:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoBuyVendorItems = self:GetChecked()
		end)
		ui.cbAutoBuyVendor = cbAutoBuyVendor
		local cbAutoCompleteAll = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoCompleteAll:SetPoint("TOPLEFT", cbAutoBuyVendor, "BOTTOMLEFT", 0, -4)
		cbAutoCompleteAll:SetSize(22, 22)
		cbAutoCompleteAll.text = cbAutoCompleteAll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoCompleteAll.text:SetPoint("LEFT", cbAutoCompleteAll, "RIGHT", 0, 0)
		cbAutoCompleteAll.text:SetText(L"Auto-Complete")
		cbAutoCompleteAll:SetChecked(DFCN_PatronOffersDB.autoCompleteAllOrders)
		cbAutoCompleteAll:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoCompleteAll", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoCompleteAll:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		cbAutoCompleteAll:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoCompleteAllOrders = self:GetChecked()
		end)
		ui.cbAutoCompleteAll = cbAutoCompleteAll
		local cbAutoSwitchActionBar = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoSwitchActionBar:SetPoint("TOPLEFT", cbAutoCompleteAll, "BOTTOMLEFT", 0, -4)
		cbAutoSwitchActionBar:SetSize(22, 22)
		cbAutoSwitchActionBar.text = cbAutoSwitchActionBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoSwitchActionBar.text:SetPoint("LEFT", cbAutoSwitchActionBar, "RIGHT", 0, 0)
		cbAutoSwitchActionBar.text:SetText(L"Auto-Switch Action Bar")
		cbAutoSwitchActionBar:SetChecked(DFCN_PatronOffersDB.autoSwitchActionBar)
		local function ShowActionBarTooltip(self)
			local pageNum = DFCN_PatronOffersDB.switchActionBarPage or 2
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format(L"Tip_AutoSwitchActionBar", pageNum), nil, nil, nil, nil, true)
			GameTooltip:Show()
		end
		cbAutoSwitchActionBar:SetScript("OnEnter", ShowActionBarTooltip)
		cbAutoSwitchActionBar:SetScript("OnLeave", function() GameTooltip:Hide() end)
		local actionBarPageEdit = CreateFrame("EditBox", nil, filterDropdownPanel, "InputBoxTemplate")
		actionBarPageEdit:SetSize(20, 20)
		actionBarPageEdit:SetPoint("LEFT", cbAutoSwitchActionBar.text, "RIGHT", 4, 0)
		actionBarPageEdit:SetAutoFocus(false)
		actionBarPageEdit:SetNumeric(true)
		actionBarPageEdit:SetText(tostring(DFCN_PatronOffersDB.switchActionBarPage))
		local pageLabel = actionBarPageEdit:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		pageLabel:SetPoint("LEFT", actionBarPageEdit, "RIGHT", 2, 0)
		pageLabel:SetText(L"Tip_ActionBarPage")
		local function SaveActionBarPage(val)
			local num = tonumber(val) or 2
			if num < 2 then num = 2 elseif num > 6 then num = 6 end
			DFCN_PatronOffersDB.switchActionBarPage = num
			actionBarPageEdit:SetText(tostring(num))
		end
		ui.cbAutoSwitchActionBar = cbAutoSwitchActionBar
		ui.actionBarPageEdit = actionBarPageEdit
		local cbIgnorePriceDiff = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbIgnorePriceDiff:SetPoint("TOPLEFT", cbAutoSwitchActionBar, "BOTTOMLEFT", 0, -4)
		cbIgnorePriceDiff:SetSize(22, 22)
		cbIgnorePriceDiff.text = cbIgnorePriceDiff:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbIgnorePriceDiff.text:SetPoint("LEFT", cbIgnorePriceDiff, "RIGHT", 0, 0)
		cbIgnorePriceDiff.text:SetText(L"Auto-Macro Ignore Rank Price ≤")
		cbIgnorePriceDiff:SetChecked(DFCN_PatronOffersDB.ignorePriceDiff)
		cbIgnorePriceDiff:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.ignorePriceDiff = self:GetChecked()
			updateFilterAndResync()
			if DFCN_PatronOffersDB.ignorePriceDiff then
				if ui and ui.orderList then
					for _, order in ipairs(ui.orderList) do
						if order.ignorePriceDiffConcentrationCost ~= nil
							and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
							order.concentrationCost = order.ignorePriceDiffConcentrationCost
						end
					end
				end
				if ui and ui.fullOrderBackup then
					for _, order in ipairs(ui.fullOrderBackup) do
						if order.ignorePriceDiffConcentrationCost ~= nil
							and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
							order.concentrationCost = order.ignorePriceDiffConcentrationCost
						end
					end
				end
			else
				if ui and ui.orderList then
					for _, order in ipairs(ui.orderList) do
						order.concentrationCost = order.lameConcentrationCost or 0
					end
				end
				if ui and ui.fullOrderBackup then
					for _, order in ipairs(ui.fullOrderBackup) do
						order.concentrationCost = order.lameConcentrationCost or 0
					end
				end
			end
		end)
		cbIgnorePriceDiff:SetScript("OnEnter", function(self)
			local thresholdGold = (DFCN_PatronOffersDB.priceDiffThreshold or 10000) / 10000
			local tipText = string.format(
				L"Tip_IgnorePriceDiff",
				thresholdGold
			)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("|cff88ff88" .. tipText .. "|r", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbIgnorePriceDiff:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbIgnorePriceDiff = cbIgnorePriceDiff
		local thresholdEditBox = CreateFrame("EditBox", nil, filterDropdownPanel, "InputBoxTemplate")
		thresholdEditBox:SetSize(32, 20)
		thresholdEditBox:SetPoint("LEFT", cbIgnorePriceDiff.text, "RIGHT", 4, 0)
		thresholdEditBox:SetAutoFocus(false)
		thresholdEditBox:SetNumeric(false)
		thresholdEditBox:SetText(tostring(DFCN_PatronOffersDB.priceDiffThreshold / 10000))
		thresholdEditBox:SetScript("OnEnterPressed", function(self)
		local val = math.min(tonumber(self:GetText()) or 0, 999)
		if val < 0 then val = 0 end
			DFCN_PatronOffersDB.priceDiffThreshold = math.floor(val * 10000)
			self:ClearFocus()
			updateFilterAndResync()
		end)
		thresholdEditBox:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(DFCN_PatronOffersDB.priceDiffThreshold / 10000))
			self:ClearFocus()
		end)
		thresholdEditBox:SetScript("OnEditFocusLost", function(self)
		local val = math.min(tonumber(self:GetText()) or 0, 999)
		if val < 0 then val = 0 end
		DFCN_PatronOffersDB.priceDiffThreshold = math.floor(val * 10000)
			updateFilterAndResync()
		end)
		ui.thresholdEditBox = thresholdEditBox
		local cbAutoShoppingSearch = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoShoppingSearch:SetPoint("TOPLEFT", cbIgnorePriceDiff, "BOTTOMLEFT", 0, -4)
		cbAutoShoppingSearch:SetSize(22, 22)
		cbAutoShoppingSearch.text = cbAutoShoppingSearch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoShoppingSearch.text:SetPoint("LEFT", cbAutoShoppingSearch, "RIGHT", 0, 0)
		cbAutoShoppingSearch.text:SetText(L"Auto-Search AH/Collect Mail")
		cbAutoShoppingSearch:SetChecked(DFCN_PatronOffersDB.autoShoppingSearch)
		cbAutoShoppingSearch:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoShoppingSearch = self:GetChecked()
		end)
		cbAutoShoppingSearch:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L'Tip_AutoSearchAH', nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoShoppingSearch:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbAutoShoppingSearch = cbAutoShoppingSearch
		local cbAutoMailManagement = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoMailManagement:SetPoint("TOPLEFT", cbAutoShoppingSearch, "BOTTOMLEFT", 0, -4)
		cbAutoMailManagement:SetSize(22, 22)
		cbAutoMailManagement.text = cbAutoMailManagement:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoMailManagement.text:SetPoint("LEFT", cbAutoMailManagement, "RIGHT", 0, 0)
		cbAutoMailManagement.text:SetText(L"Auto-Mail Management")
		cbAutoMailManagement:SetChecked(DFCN_PatronOffersDB.autoMailManagement)
		cbAutoMailManagement:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoMailManagement = self:GetChecked()
		end)
		cbAutoMailManagement:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_AutoMailManagement", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoMailManagement:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbAutoMailManagement = cbAutoMailManagement
		local cbAutoUseFinishing = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbAutoUseFinishing:SetPoint("TOPLEFT", cbAutoMailManagement, "BOTTOMLEFT", 0, -4)
		cbAutoUseFinishing:SetSize(22, 22)
		cbAutoUseFinishing.text = cbAutoUseFinishing:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbAutoUseFinishing.text:SetPoint("LEFT", cbAutoUseFinishing, "RIGHT", 0, 0)
		cbAutoUseFinishing.text:SetText(L"Guest Materials ≥ ")
		cbAutoUseFinishing:SetChecked(DFCN_PatronOffersDB.autoUseFinishingItem)
		cbAutoUseFinishing:SetScript("OnEnter", function(self)
			local thresholdGold = (DFCN_PatronOffersDB.finishingItemThreshold or 20000000) / 10000
			local thresholdText = string.format("%dG", thresholdGold)
			local itemName = select(2, GetItemInfo(FINISHING_ITEM_ID)) or L"Finishing Reagent"
			local itemIcon = select(10, GetItemInfo(FINISHING_ITEM_ID)) or 133004
			local itemIconTag = string.format("|T%d:14:14|t", itemIcon)			
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(string.format(L"Tip_AutoUseFinishing", thresholdText, itemIconTag, itemName), nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbAutoUseFinishing:SetScript("OnLeave", function() GameTooltip:Hide() end)
		cbAutoUseFinishing:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.autoUseFinishingItem = self:GetChecked()
			updateFilterAndResync()
		end)
		local finishingThresholdEdit = CreateFrame("EditBox", nil, filterDropdownPanel, "InputBoxTemplate")
		finishingThresholdEdit:SetSize(45, 20)
		finishingThresholdEdit:SetPoint("LEFT", cbAutoUseFinishing.text, "RIGHT", -2, 0)
		finishingThresholdEdit:SetAutoFocus(false)
		finishingThresholdEdit:SetNumeric(true)
		local initThresholdGold = DFCN_PatronOffersDB.finishingItemThreshold / 10000
		finishingThresholdEdit:SetText(tostring(initThresholdGold))
		finishingThresholdEdit:SetScript("OnEnterPressed", function(self)
			local val = tonumber(self:GetText()) or 0
			DFCN_PatronOffersDB.finishingItemThreshold = math.max(0, val * 10000)
			self:ClearFocus()
			updateFilterAndResync()
		end)
		finishingThresholdEdit:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(DFCN_PatronOffersDB.finishingItemThreshold / 10000))
			self:ClearFocus()
		end)
		finishingThresholdEdit:SetScript("OnEditFocusLost", function(self)
			local val = tonumber(self:GetText()) or 0
			DFCN_PatronOffersDB.finishingItemThreshold = math.max(0, val * 10000)
		end)
		local goldLabel2 = finishingThresholdEdit:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		goldLabel2:SetPoint("LEFT", finishingThresholdEdit, "RIGHT", 2, 0)
		goldLabel2:SetText(L"G use Finishing Item")
		ui.cbAutoUseFinishing = cbAutoUseFinishing
		ui.finishingThresholdEdit = finishingThresholdEdit
		local cbEnableRecipeToolSwitch = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbEnableRecipeToolSwitch:SetPoint("TOPLEFT", cbAutoUseFinishing, "BOTTOMLEFT", 0, -4)
		cbEnableRecipeToolSwitch:SetSize(22, 22)
		cbEnableRecipeToolSwitch.text = cbEnableRecipeToolSwitch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbEnableRecipeToolSwitch.text:SetPoint("LEFT", cbEnableRecipeToolSwitch, "RIGHT", 0, 0)
		cbEnableRecipeToolSwitch.text:SetText(L"Enable Recipe Tool Switch")
		cbEnableRecipeToolSwitch:SetChecked(DFCN_PatronOffersDB.enableRecipeToolSwitch)
		cbEnableRecipeToolSwitch:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.enableRecipeToolSwitch = self:GetChecked()
		end)
		cbEnableRecipeToolSwitch:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_EnableRecipeToolSwitch", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbEnableRecipeToolSwitch:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbEnableRecipeToolSwitch = cbEnableRecipeToolSwitch
		local cbSilentMode = CreateFrame("CheckButton", nil, filterDropdownPanel, "UICheckButtonTemplate")
		cbSilentMode:SetPoint("TOPLEFT", cbEnableRecipeToolSwitch, "BOTTOMLEFT", 0, -4)
		cbSilentMode:SetSize(22, 22)
		cbSilentMode.text = cbSilentMode:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		cbSilentMode.text:SetPoint("LEFT", cbSilentMode, "RIGHT", 0, 0)
		cbSilentMode.text:SetText(L"Silent Mode")
		cbSilentMode:SetChecked(DFCN_PatronOffersDB.silentMode)
		cbSilentMode:SetScript("OnClick", function(self)
			DFCN_PatronOffersDB.silentMode = self:GetChecked()
		end)
		cbSilentMode:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L'Tip_SilentMode', nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cbSilentMode:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		ui.cbSilentMode = cbSilentMode
		local separatorLine = filterDropdownPanel:CreateTexture(nil, "OVERLAY")
		separatorLine:SetPoint("TOPLEFT", cbSilentMode, "BOTTOMLEFT", 0, -8)
		separatorLine:SetPoint("TOPRIGHT", filterDropdownPanel, "TOPRIGHT", -15, -6)
		separatorLine:SetHeight(1)
		separatorLine:SetColorTexture(0.3, 0.3, 0.3, 1)
		local highlightLine = filterDropdownPanel:CreateTexture(nil, "OVERLAY")
		highlightLine:SetPoint("TOPLEFT", separatorLine, "TOPLEFT", 0, 1)
		highlightLine:SetPoint("TOPRIGHT", separatorLine, "TOPRIGHT", 0, 1)
		highlightLine:SetHeight(1)
		highlightLine:SetColorTexture(0.2, 0.2, 0.2, 1)
		local createMacroButton = CreateFrame("Button", nil, filterDropdownPanel, "GameMenuButtonTemplate")
		createMacroButton:SetSize(225, 28)
		createMacroButton:SetPoint("TOPLEFT", separatorLine, "BOTTOMLEFT", 10, -10)
		createMacroButton:SetText(L"Create DFPO Macro")
		createMacroButton:SetNormalFontObject(GameFontNormal)
		createMacroButton:SetHighlightFontObject(GameFontHighlight)
		local function TrySkin()
			local E = _G.ElvUI and unpack(_G.ElvUI)
			if E and E.Skins and E.Skins.HandleButton then
				E.Skins:HandleButton(createMacroButton)
				return true
			end
		end
		local f = CreateFrame("Frame")
		f.elapsed = 0
		f:SetScript("OnUpdate", function(self, e)
			self.elapsed = self.elapsed + e
			if self.elapsed > 0.2 then
				if TrySkin() then
					self:SetScript("OnUpdate", nil)
				end
				self.elapsed = 0
			end
		end)
		local function CreateOrUpdateMacro()
			local macroName = "DFPO"
			local macroBody = L'#Craft order macro' .. '\n/dfpo auto\n' .. L'#Use item macro' .. '\n/click DFPO_AUTO\n' .. L'#Use transmog macro' .. '\n/run DFPO_UseTransmog()'
			local macroIcon = "UI_concentration"
			local existingIdx = nil
			for i = 1, 120 do
				local name = GetMacroInfo(i)
				if name == macroName then
					existingIdx = i
					break
				end
			end
			local success
			if existingIdx then
				success = EditMacro(existingIdx, macroName, macroIcon, macroBody)
			else
				success = CreateMacro(macroName, macroIcon, macroBody, nil)
			end
			if success then
				SilentPrint(L"Msg_MacroCreated")
			else
				SilentPrint(L"Msg_MacroError")
			end
		end
		createMacroButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Tip_CreateDFPOMacro", nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		createMacroButton:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		createMacroButton:SetScript("OnClick", function()
			CreateOrUpdateMacro()
			ShowMacroFrame()
			filterDropdownPanel:Hide()
		end)
		local editBox = CreateFrame("EditBox", nil, filterDropdownPanel, "InputBoxTemplate")
		editBox:SetSize(55, 20)
		editBox:SetPoint("LEFT", cbProfitBelow.text, "RIGHT", 4, 0)
		editBox:SetAutoFocus(false)
		editBox:SetNumeric(false)
		local initThreshold = (DFCN_PatronOffersDB.filters and DFCN_PatronOffersDB.filters.profitThreshold) or 0
		editBox:SetText(tostring(initThreshold / 10000))
		ui.editBox = editBox
		editBox:SetScript("OnEnterPressed", function(self)
			if not DFCN_PatronOffersDB.filters then DFCN_PatronOffersDB.filters = {} end
			local val = tonumber(self:GetText()) or 0
			DFCN_PatronOffersDB.filters.profitThreshold = val * 10000
			self:ClearFocus()
			updateFilterAndResync()
		end)
		editBox:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring((DFCN_PatronOffersDB.filters and DFCN_PatronOffersDB.filters.profitThreshold or 0) / 10000))
			self:ClearFocus()
		end)
		editBox:SetScript("OnEditFocusLost", function(self)
			if not DFCN_PatronOffersDB.filters then DFCN_PatronOffersDB.filters = {} end
			local val = tonumber(self:GetText()) or 0
			DFCN_PatronOffersDB.filters.profitThreshold = val * 10000
			updateFilterAndResync()
		end)
		local goldLabel = editBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		goldLabel:SetPoint("LEFT", editBox, "RIGHT", 2, 0)
		goldLabel:SetText("G")
		ui.filterDropdownPanel = filterDropdownPanel
		ui.filterDropdownButton = filterDropdownButton
		filterDropdownButton:SetScript("OnClick", function()
			updateFilterAndResync()
			if filterDropdownPanel:IsShown() then
				filterDropdownPanel:Hide()
			else
				filterDropdownPanel:Show()
			end
		end)
		updateFilterAndResync()
		local manualOpenButton = CreateFrame("Button", nil, root)
		manualOpenButton:SetSize(32, 32)
		manualOpenButton:SetPoint("LEFT", ui.version, "RIGHT", 2, 0)
		manualOpenButton:SetNormalAtlas("Perks-ShoppingCart")
		manualOpenButton:SetHighlightAtlas("Perks-ShoppingCart")
		local hlTex = manualOpenButton:GetHighlightTexture()
		local normalTex = manualOpenButton:GetNormalTexture()
		if hlTex then
			hlTex:SetVertexColor(1, 0.85, 0)
		end
		manualOpenButton:SetFrameLevel(manualOpenButton:GetFrameLevel() + 10)
		manualOpenButton:SetScript("OnClick", function()
			local sf = _G.PatronOffersSummary
			if sf and sf:IsShown() then
				sf:Hide()
				ui.manualSummaryOpen = false
			else
				local success = ShowSummaryWindow()
				if success then
					ui.manualSummaryOpen = true
				else
					ui.manualSummaryOpen = true
				end
			end
		end)
		manualOpenButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L"Toggle Shopping Helper")
			GameTooltip:Show()
		end)
		manualOpenButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide()
		end)
		t = CreateFrame("Button", nil, root, "ColumnDisplayButtonShortTemplate", 1)
		t:GetHighlightTexture():SetTextureSliceMargins(15, 0, 15, 0)
		t:SetPoint("TOPLEFT", 2, 19)
		t:SetSize(ORDER_COLUMN_WIDTH, 19)
		t:SetText(L"You craft/provide:")
		ui.headerBaseTexts = ui.headerBaseTexts or {}
		ui.headerBaseTexts[1] = L"You craft/provide:"
		local fs = t:GetFontString()
		fs:SetFont(fs:GetFont(), 13)
		t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		t:SetScript("OnClick", ColumnHeader_OnClick)
		t, h[1] = t, t
		t = CreateFrame("Button", nil, root, "ColumnDisplayButtonShortTemplate", 2)
		t:GetHighlightTexture():SetTextureSliceMargins(15, 0, 15, 0)
		t:SetPoint("TOPLEFT", COST_COLUMN_XOFS + 1, 19)
		t:SetSize(COST_COLUMN_WIDTH, 19)
		t:SetText(L"Profit:")
		fs = t:GetFontString()
		fs:SetFont(fs:GetFont(), 13)
		t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		t:SetScript("OnClick", ColumnHeader_OnClick)
		t, h[2] = t, t
		t = CreateFrame("Button", nil, root, "ColumnDisplayButtonShortTemplate", 3)
		t:GetHighlightTexture():SetTextureSliceMargins(15, 0, 15, 0)
		t:SetPoint("TOPLEFT", REWARD_COLUMN_XOFS + 1, 19)
		t:SetSize(REWARD_COLUMN_WIDTH, 19)
		t:SetText(L"You receive:")
		fs = t:GetFontString()
		fs:SetFont(fs:GetFont(), 13)
		t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		t:SetScript("OnClick", ColumnHeader_OnClick)
		t, h[3] = t, t
		t = CreateFrame("Button", nil, root, "ColumnDisplayButtonShortTemplate", 4)
		t:GetHighlightTexture():SetTextureSliceMargins(15, 0, 15, 0)
		t:SetPoint("TOPLEFT", PATRON_COLUMN_XOFS + 1, 19)
		t:SetSize(200, 19)
		t:SetText(L"Patron/Time/Total Reward:")
		fs = t:GetFontString()
		fs:SetFont(fs:GetFont(), 13)
		t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		t:SetScript("OnClick", ColumnHeader_OnClick)
		t, h[4] = t, t
		t = root:CreateTexture(nil, "ARTWORK", nil, 5)
		t:SetAtlas("auctionhouse-ui-sortarrow", true)
		t:Hide()
		t, ui.sortArrow = CreateFrame("Frame", nil, root), t
		t:SetPoint("TOPLEFT", 4, -2)
		t:SetPoint("BOTTOMRIGHT", -20, 0)
		t:SetClipsChildren(true)
		t, ui.clip, root.View = CreateFrame("Frame", nil, t), t, t
		t:SetSize(1, 1)
		t:SetPoint("TOPLEFT")
		t:Hide()
		t, ui.origin, root.Origin = T.exUI:Create("ScrollBar", nil, root), t, t
		t:SetPoint("TOPRIGHT", -6, 0)
		t:SetPoint("BOTTOMRIGHT", -6, 0)
		t:SetWheelScrollTarget(ui.clip)
		t:SetCoverTarget(ui.clip)
		t:SetValueStep(1)
		t:SetStepsPerPage(10, 3)
		t:SetWindowRange(10)
		t:SetScript("OnValueChanged", function(_, nv)
			ui.origin:SetPoint("TOPLEFT", 0, nv * 54)
		end)
		root.ORDER_COLUMN_WIDTH, root.COST_COLUMN_WIDTH, root.REWARD_COLUMN_WIDTH, root.PATRON_COLUMN_WIDTH = ORDER_COLUMN_WIDTH, COST_COLUMN_WIDTH, REWARD_COLUMN_WIDTH, PATRON_COLUMN_WIDTH
		ui.root, ui.bar, ui.headers, ui.rows, C.RootUI = root, t, h, {}, nil
		ui.rowsW, root.Orders = newArray()
		SetShadow(root, ui)
		local headerTooltips = {
			[1] = L"Order Name Tooltip",
			[2] = L"Est Profit Tooltip",
			[3] = L"Order Reward Tooltip",
			[4] = L"Patron Time Total Tooltip"
		}
		for i, header in ipairs(ui.headers) do
			header:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(headerTooltips[i], nil, nil, nil, nil, true)
				GameTooltip:Show()
			end)
			header:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
		ui.updateFilterAndResync = updateFilterAndResync
		updateFilterAndResync()
		ui.ready = true
		return root
	end
	function Acquire(kind, parent)
		local pl = P[kind]
		local w = pl and next(pl) or C[kind]()
		if pl then
			pl[w] = nil
		end
		if parent then
			w:SetParent(parent)
			w:Show()
		end
		return GetShadow(w)
	end
	function Release(kind, w)
		local pl = P[kind] or {}
		P[kind], pl[w] = pl, 1
		w:Hide()
		w:ClearAllPoints()
		w:SetParent(nil)
		if kind == "IconButton" then
			w:SetSize(32, 32)
		end
	end
end

local MUTABLE_DATASLOT_TYPE = Enum.TradeskillSlotDataType.ModifiedReagent
local function GetCraftingReagentCount(iid)
	return C_Item.GetItemCount(iid, true, false, true, true)
end

local function GetItemQualityAtlas(itemID)
	local link = select(2, C_Item.GetItemInfo(itemID))
	if link then
		local fullAtlas = link:match("|A:([^|]+)|a")
		if fullAtlas then
			return fullAtlas:match("^[^:]+")
		end
	end
	return nil
end

local function cmpReagentPref(a, b)
	return (a.concPref or 0) > (b.concPref or 0)
end

local function augSchematicInfo(oi, mutReagents, tempReagent, tempPrefCache)
	local recipeInfo, orderReagents = oi.recipeInfo, oi.reagents
	local recipeID, minQuality = recipeInfo.recipeID, oi.minQuality or 0
	local schematicReagentSlots = oi.recipeSchematic.reagentSlotSchematics
	local coveredReagentSlots = {}
	local function P(itemID)
		if not itemID then return nil end
		if HAS_AUCTIONATOR then
			local vendorPrice = Auctionator.API.v1.GetVendorPriceByItemID and Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
			local ahPrice = Auctionator.API.v1.GetAuctionPriceByItemID(AUCTIONATOR_L_REAGENT_SEARCH, itemID)
			if vendorPrice and vendorPrice > 0 and ahPrice then
				return math.min(vendorPrice, ahPrice)
			elseif vendorPrice and vendorPrice > 0 then
				return vendorPrice
			elseif ahPrice then
				return ahPrice
			end
		end
		return nil
	end
	for i = 1, #orderReagents do
		local r = orderReagents[i]
		r.reagent = r.reagentInfo
		coveredReagentSlots[r.slotIndex] = r.reagent
	end
	local slotSchematicByIndex = {}
	for _, rs in ipairs(schematicReagentSlots) do
		slotSchematicByIndex[rs.slotIndex] = rs
	end
	local coverMap = {}
	for i = 1, #schematicReagentSlots do
		local rs = schematicReagentSlots[i]
		local cover = coveredReagentSlots[rs.slotIndex]
		if cover then
			coverMap[rs] = cover
		end
		if rs.slotInfo then
			rs.locked, rs.lockedReason = C_TradeSkillUI.GetReagentSlotStatus(
				rs.slotInfo.mcrSlotID, recipeInfo.recipeID, recipeInfo.skillLineAbilityID
			)
		else
			rs.locked, rs.lockedReason = nil, nil
		end
	end
	if minQuality == 0 then return end
	table.wipe(mutReagents)
	for i = 1, #orderReagents do
		local r = orderReagents[i]
		local rs = slotSchematicByIndex[r.slotIndex]
		if rs and rs.dataSlotType == MUTABLE_DATASLOT_TYPE then
			mutReagents[#mutReagents + 1] = r.reagent
		end
	end
	local GetCraftingOperationInfo = C_TradeSkillUI.GetCraftingOperationInfo
	local baseCraft = minQuality > 0 and securecall(GetCraftingOperationInfo, recipeID, mutReagents, nil, false)
	oi.concentrationCurrencyID = baseCraft and baseCraft.concentrationCurrencyID or oi.concentrationCurrencyID or nil
	if not baseCraft then return end
	mutReagents[#mutReagents + 1] = tempReagent
	local bcQuality, bcConc = baseCraft.craftingQuality or 0, baseCraft.concentrationCost
	local bcSkill, bcDifficulty = baseCraft.bonusSkill, baseCraft.bonusDifficulty
	local function checkConcentrationCost(onlyAvailableReagents, useBestReagents, minQuality, recipeID, schematicReagentSlots, mutReagents, lowerCost, useCheapest, priceDiffThreshold)
		if lowerCost == 0 then return 0 end
		local oldMutReagentCount = #mutReagents
		local nextMutReagent = oldMutReagentCount + 1
		for i = 1, #schematicReagentSlots do
			local rs = schematicReagentSlots[i]
			local ra, isReq = rs.reagents, rs.required
			local rn1, reqQuant = #ra + 1, rs.quantityRequired
			local fillSlot = (not coverMap[rs] and not rs.locked and rs.dataSlotType == MUTABLE_DATASLOT_TYPE and (isReq or useBestReagents))
			if fillSlot then
				local reagentsToUse = {}
				for j = 1, rn1 - 1 do
					table.insert(reagentsToUse, ra[j])
				end
				if useCheapest then
					table.sort(reagentsToUse, function(a, b)
						if not a.itemID then return false end
						if not b.itemID then return true end
						local pa, pb = P(a.itemID), P(b.itemID)
						if pa and pb then return pa < pb end
						local qa = C_TradeSkillUI.GetItemReagentQualityByItemInfo(a.itemID) or 1
						local qb = C_TradeSkillUI.GetItemReagentQualityByItemInfo(b.itemID) or 1
						return qa < qb
					end)
				elseif useBestReagents then
					table.sort(reagentsToUse, function(a, b)
						return (a.concPref or 0) > (b.concPref or 0)
					end)
				elseif priceDiffThreshold then
					local slotCheapestPrice = nil
					for _, rj in ipairs(reagentsToUse) do
						if rj.itemID then
							local price = P(rj.itemID)
							if price and (slotCheapestPrice == nil or price < slotCheapestPrice) then
								slotCheapestPrice = price
							end
						end
					end
					if slotCheapestPrice then
						local thresholdCandidates = {}
						for _, rj in ipairs(reagentsToUse) do
							if rj.itemID then
								local price = P(rj.itemID)
								if price and (price - slotCheapestPrice) <= priceDiffThreshold then
									table.insert(thresholdCandidates, rj)
								end
							end
						end
						if #thresholdCandidates > 0 then
							local bestReagent = nil
							local bestConc = nil
							local testMutSz = nextMutReagent - 1
							local testMutAll = {}
							for ti = 1, testMutSz do
								testMutAll[ti] = mutReagents[ti]
							end
							for _, cand in ipairs(thresholdCandidates) do
								local tm = {itemID = cand.itemID, dataSlotIndex = rs.dataSlotIndex, quantity = rs.quantityRequired}
								tm.reagent = tm
								testMutAll[testMutSz + 1] = tm
								local ci = securecall(GetCraftingOperationInfo, recipeID, testMutAll, nil, false)
								testMutAll[testMutSz + 1] = nil
								if ci then
									local conc = ci.concentrationCost
									if ci.craftingQuality and ci.craftingQuality >= minQuality then
										conc = 0
									elseif not ci.craftingQuality or (ci.craftingQuality + 1) < minQuality then
										conc = nil
									end
									if conc ~= nil and (bestConc == nil or conc < bestConc) then
										bestConc = conc
										bestReagent = cand
									end
								end
							end
							if bestReagent then
								reagentsToUse = {bestReagent}
							end
						end
					end
				end
				for j = 1, #reagentsToUse do
					local rj = reagentsToUse[j]
					local aq = (isReq or rj.concPref > 0) and reqQuant or 0
					if aq > 0 then
						local uq = aq > reqQuant and reqQuant or aq
						local mr = {itemID = rj.itemID, dataSlotIndex = rs.dataSlotIndex, quantity = uq}
						mr.reagent = mr
						mutReagents[nextMutReagent] = mr
						nextMutReagent = nextMutReagent + 1
						reqQuant = reqQuant - uq
						if reqQuant == 0 then break end
					end
				end
			end
		end
		local ci = securecall(GetCraftingOperationInfo, recipeID, mutReagents, nil, false)
		for i = #mutReagents, oldMutReagentCount + 1, -1 do
			mutReagents[i] = nil
		end
		if not ci or (ci.craftingQuality + 1) < minQuality then
			return nil
		elseif ci.craftingQuality >= minQuality then
			return 0
		end
		return ci.concentrationCost
	end
	for i = 1, #schematicReagentSlots do
		local rs = schematicReagentSlots[i]
		if not coverMap[rs] and not rs.locked and rs.dataSlotType == MUTABLE_DATASLOT_TYPE then
			tempReagent.dataSlotIndex = rs.dataSlotIndex
			tempReagent.quantity = rs.quantityRequired
			for j = 1, #rs.reagents do
				local rj = rs.reagents[j]
				local itemID = rj.itemID
				local cachedConcPref = tempPrefCache[itemID]
				if itemID and not cachedConcPref then
					tempReagent.itemID = itemID
					local pref, ci = 0, securecall(GetCraftingOperationInfo, recipeID, mutReagents, nil, false)
					if ci then
						cachedConcPref = (ci.bonusSkill - bcSkill) - (ci.bonusDifficulty - bcDifficulty)
						if pref == 0 and (ci.craftingQuality or 0) == bcQuality then
							cachedConcPref = (bcConc - ci.concentrationCost)
						end
						tempPrefCache[itemID] = cachedConcPref
					end
				end
				rj.concPref = cachedConcPref or 0
			end
			table.sort(rs.reagents, function(a, b)
				if (a.concPref or 0) ~= (b.concPref or 0) then
					return (a.concPref or 0) > (b.concPref or 0)
				end
				if not a.itemID then return false end
				if not b.itemID then return true end
				local pa, pb = P(a.itemID), P(b.itemID)
				if pa and pb then return pa < pb end
				return (a.itemLevel or 0) < (b.itemLevel or 0)
			end)
		end
	end
	mutReagents[#mutReagents] = nil
	oi.lameConcentrationCost = checkConcentrationCost(false, false, minQuality, recipeID, schematicReagentSlots, mutReagents, nil, true)
	oi.goodConcentrationCost = checkConcentrationCost(false, true, minQuality, recipeID, schematicReagentSlots, mutReagents, oi.lameConcentrationCost, true)
	oi.bestConcentrationCost = checkConcentrationCost(false, true, minQuality, recipeID, schematicReagentSlots, mutReagents, oi.goodConcentrationCost, true)
	local priceDiffThreshold = DFCN_PatronOffersDB.priceDiffThreshold or 10000
	oi.ignorePriceDiffConcentrationCost = checkConcentrationCost(false, false, minQuality, recipeID, schematicReagentSlots, mutReagents, nil, false, priceDiffThreshold)
	oi._needsBetterMats = oi.ignorePriceDiffConcentrationCost ~= nil and (oi.lameConcentrationCost == nil or oi.lameConcentrationCost > 0)
end

local function releaseIconButtons(a, a2, ni)
	for i = #a, ni, -1 do
		a[i], a2[i] = Release("IconButton", a[i].root)
	end
end

local prepareOrders, sortOrders, mangleOrderName
do
	local function itemLink(iid)
		if iid then
			local _, link = C_Item.GetItemInfo(iid)
			return link
		end
	end
	local function nameOrder(o)
		local iid, sid = o.itemID, o.spellID
		local si, qmin = o.recipeInfo, o.minQuality or 0
		if qmin > 0 and si.qualityIDs then
			local rg, reagents = o.reagents, {}
			for i = 1, rg and #rg or 0 do
				reagents[i] = rg[i].reagent
			end
			local oi = C_TradeSkillUI.GetRecipeOutputItemData(sid, reagents, nil, si.qualityIDs[qmin], nil)
			local it = oi and (oi.hyperlink or itemLink(oi.itemID))
			if it then
				o.productItem = it
				return it
			end
		end
		local qiid = qmin == 0 and iid or qmin and si.qualityItemIDs and si.qualityItemIDs[qmin] or iid
		if qiid then
			o.productItem = qiid
			return itemLink(qiid)
		end
	end
	function mangleOrderName(o)
		local bad, nn = false, nameOrder(o)
		if ((nn or "") == "" or nn:match("|h%[ |A")) and o.spellID then
			bad, nn = true, C_Spell.GetSpellName(o.spellID)
		end
		o.requestName = ((nn or '???'):gsub('|h%[(.*)%]|h', '|h%1|h'):gsub('(|A:[^:]+:[^:|]*:[^:|]*:[^:|]*):[^:|]*', '%1:4'))
		o.badName, o.plainName = bad, C_StringUtil.StripHyperlinks(o.requestName)
	end
	local sortByFields, sortOrderData, sortBy = {"plainName", "profit", "rewardScore", "expirationTime"}
	local function cmpOrder(a, b)
		local oa, ob = sortOrderData[a], sortOrderData[b]
		local ac, bc = oa[sortBy], ob[sortBy]
		if sortBy == "profit" then
			local aUnknown = oa.hasUnknownCost
			local bUnknown = ob.hasUnknownCost
			if aUnknown and bUnknown then
			elseif aUnknown then
				return false
			elseif bUnknown then
				return true
			else
				if ac ~= bc then
					return (ac < bc) == ui.sortAsc
				end
			end
		else
			if ac ~= bc then
				return (ac < bc) == ui.sortAsc
			end
		end
		if oa.recipeInfo.learned ~= ob.recipeInfo.learned and not sortBy then
			return not ob.recipeInfo.learned
		elseif oa.rewardScore ~= ob.rewardScore then
			return oa.rewardScore > ob.rewardScore
		elseif oa.expirationTime ~= ob.expirationTime then
			return oa.expirationTime < ob.expirationTime
		end
		return a < b
	end
	function prepareOrders(oa)
		if oa and oa[1] and oa[1].orderType ~= 3 then
			return {}, true
		end
		local processedOrders = {}
		local badData = false
		for i = 1, oa and #oa or 0 do
			local orig_o = oa[i]
			local o = DeepCopy(orig_o)
			local coveredReagentSlots = {}
			local kp, ac = 0, 0
			local si = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(o.skillLineAbilityID, 2)
			if si then
				si = DeepCopy(si)
			end
			local sm = si and C_TradeSkillUI.GetRecipeSchematic(si.recipeID, o.isRecraft)
			if sm then
				sm = DeepCopy(sm)
			end
			o.recipeInfo = si
			o.recipeSchematic = sm
			mangleOrderName(o)
			for _, r in ipairs(o.reagents) do
				coveredReagentSlots[r.slotIndex] = r
			end
			if sm then
				for _, rs in ipairs(sm.reagentSlotSchematics) do
					rs.cover = coveredReagentSlots[rs.slotIndex]
				end
			end
			for _, reward in ipairs(o.npcOrderRewards or {}) do
				local iid = tonumber((reward.itemLink or ""):match("|Hitem:(%d+)"))
				local c = reward.count or 0
				kp = kp + (KNOWLEDGE_ITEMS[iid] or 0) * c
				ac = ac + (iid == ACUITY_ITEM_ID and c or 0)
			end
			local gold = (o.tipAmount or 0) - (o.consortiumCut or 0)
			o.rewardKnowledge = kp
			o.rewardAcuity = ac
			o.rewardScore = (kp * 1e3 + (kp == 0 and ac or 0)) * 1e9 + (kp == 0 and ac == 0 and gold or 0)
			o.goldRewardString = gold > 0 and GetMoneyString(gold, true) or ""
			local rewardTotal = gold
			for _, reward in ipairs(o.npcOrderRewards or {}) do
				local itemID = tonumber((reward.itemLink or ""):match("item:(%d+)"))
				if itemID then
					local itemValue = CalculateItemValue(itemID) * reward.count
					rewardTotal = rewardTotal + itemValue
				end
			end
			o.rewardTotalValue = rewardTotal
			o.craftingCost, o.hasUnknownCost = CalculateReagentsTotal(o.recipeSchematic)
			o.profit = o.rewardTotalValue - o.craftingCost
			local mutReagents = {}
			local tempReagent = {reagent = {}}
			local tempPrefCache = {}
			augSchematicInfo(o, mutReagents, tempReagent, tempPrefCache)
			if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and o.ignorePriceDiffConcentrationCost
				and (o.lameConcentrationCost == nil or o.lameConcentrationCost > 0) then
				o.concentrationCost = o.ignorePriceDiffConcentrationCost
			else
				o.concentrationCost = o.lameConcentrationCost or 0
			end
			if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and o._needsBetterMats then
				local newCost = 0
				for _, slot in ipairs(o.recipeSchematic.reagentSlotSchematics) do
					if slot.required and not slot.cover and slot.reagents then
						local best = DFPO_GetBestDisplayReagent(slot.reagents, o)
						if best and best.itemID then
							local p = CalculateItemValue(best.itemID) or 0
							newCost = newCost + p * slot.quantityRequired
						end
					end
				end
				o.craftingCost = newCost
				o.hasUnknownCost = false
				o.profit = o.rewardTotalValue - newCost
			end
			o.concentrationCurrencyID = o.concentrationCurrencyID
			badData = badData or #(o.npcOrderRewards or {}) == 0
			table.insert(processedOrders, o)
		end
		return processedOrders, badData
	end
	function sortOrders(oa)
		if oa and #oa > 1 then
			local ia = {}
			for i = 1, #oa do ia[i] = i end
			sortOrderData, sortBy = oa, sortByFields[ui.sortBy]
			table.sort(ia, cmpOrder)
			for i = 1, #ia do
				ia[i] = oa[ia[i]]
			end
			oa, sortOrderData = ia, nil
		end
		return oa
	end
end

local function confIconButton(ws, data, count, altReagents, extraText)
	if not ws then return end
	local w, icon, qa, _ = ws.root
	local item, cid
	if data then
		if data.currencyType then
			cid = data.currencyType
			count = data.count or count
			local ci = C_CurrencyInfo.GetBasicCurrencyInfo(cid, count)
			if ci then
				icon = ci.icon
				qa = QUALITY_SLOT_ATLAS[ci.quality or 1]
			end
		elseif data.productItem then
			item = data.productItem
		elseif data.itemLink then
			item = data.itemLink
		elseif data.itemID then
			item = data.itemID
		end
		if item then
			_, _, _, _, icon = C_Item.GetItemInfoInstant(item)
			qa = QUALITY_SLOT_ATLAS[C_Item.GetItemQualityByID(item)]
		end
	elseif cid then
		local ci = C_CurrencyInfo.GetBasicCurrencyInfo(cid, count)
		icon, qa = ci and ci.icon, QUALITY_SLOT_ATLAS[ci and ci.quality]
	end
	ws.item, ws.currency, ws.altReagents, ws.extraText = item, cid, altReagents, extraText
	w.item, w.currency = item, cid
	local n
	local isMultiQuality = altReagents and #altReagents > 1
	if isMultiQuality then
		local iid = nil
		if type(item) == "number" then
			iid = item
		elseif type(item) == "string" then
			iid = tonumber(item:match("item:(%d+)"))
		end
		if iid then
			n = C_Item.GetItemCount(iid, true, false, true, true)
		else
			n = 0
		end
	else
		n = altReagents and 0 or (count or 0)
		if altReagents then
			for _, cn in nextReagentOption, altReagents do
				n = n + cn
			end
		end
	end
	local showCount = (count or 0) >= 1
	if ws.icon then
		ws.icon:SetTexture(icon or "Interface/Icons/Temp")
		if count and n < count then
			ws.icon:SetVertexColor(0.7, 0.7, 0.7)
		else
			ws.icon:SetVertexColor(1, 1, 1)
		end
	end
	if ws.border then
		ws.border:SetAtlas(qa or QUALITY_SLOT_ATLAS[1])
	end
	if ws.count then
		ws.count:SetText(showCount and count or "")
		if count and n < count then
			ws.count:SetTextColor(1, 0.15, 0)
		else
			ws.count:SetTextColor(1, 1, 1)
		end
	end
	local itemID = nil
	if type(data) == "table" then
		itemID = data.itemID or data.productItem
	elseif type(data) == "number" then
		itemID = data
	end
	if altReagents and #altReagents > 1 and itemID and type(itemID) == "number" then
		local atlas = GetItemQualityAtlas(itemID)
		if atlas then
			if not ws.qualityTex then
				ws.qualityTex = w:CreateTexture(nil, "OVERLAY")
				ws.qualityTex:SetSize(20, 20)
				ws.qualityTex:SetPoint("TOPLEFT", w, "TOPLEFT", -3, 3)
			end
			ws.qualityTex:SetAtlas(atlas, false)
			ws.qualityTex:Show()
		else
			if ws.qualityTex then ws.qualityTex:Hide() end
		end
	else
		if ws.qualityTex then ws.qualityTex:Hide() end
	end
	w:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and IsShiftKeyDown() then
			if ws.item then
				local link
				if type(ws.item) == "number" then
					link = select(2, GetItemInfo(ws.item))
				else
					link = ws.item
				end
				if link then
					HandleModifiedItemClick(link)
				end
			end
		end
	end)
end

local function SecondsToTime(d)
	return d < 60 and "<" .. D_MINUTES:format(1) or _G.SecondsToTime(d, true, true)
end

local function confOrderRowPatron(i, s, notify)
	local oi = s.orderInfo
	if s.patron then
		s.patron:SetText(tostring(oi.customerName))
	end
	local d, cc = oi.expirationTime - C_CraftingOrders.GetCraftingOrderTime()
	for i = 2, #EXPIRE_THRESHOLDS, 2 do
		if d > EXPIRE_THRESHOLDS[i] then
			cc = EXPIRE_THRESHOLDS[i - 1]
			break
		end
	end
	local r, g, b = cc:match("(%x%x)(%x%x)(%x%x)$")
	local ac = tonumber(r, 16) .. ":" .. tonumber(g, 16) .. ":" .. tonumber(b, 16)
	if s.timeLeft then
		s.timeLeft:SetText(cc .. "|A:auctionhouse-icon-clock:14:14:0:0:" .. ac .. "|a " .. SecondsToTime(d))
	end
	if notify then
		EV("POFF_ORDER_TICK", s.root, i, oi.orderID)
	end
end

local function confOrderRow(s, oi, i, _cause)
	s.pendingMissingCheck = nil
	s.concIcon = nil
	local wr, orderName, rei, rs, et = s.root, oi.requestName, oi.recipeInfo, ""
	if not rei.learned then
		orderName = "|A:transmog-icon-remove:12:12:|a|cffa0a0a0 " .. orderName:gsub("|c%x%x%x%x%x%x%x%x", "")
		et = "|A:transmog-icon-remove:12:12:|a|cffe01010 " .. PROFESSIONS_CRAFTER_CANT_CLAIM_UNLEARNED
	elseif rei.firstCraft then
		rs = (rs ~= "" and rs or " ") .. "|A:Professions_Icon_FirstTimeCraft:14:12:0:1|a"
		et = "|A:Professions_Icon_FirstTimeCraft:14:10:0:1|a " .. PROFESSIONS_FIRST_CRAFT
	end
	if DIFFICULTY_ATLAS[rei.relativeDifficulty] then
		local d, sk = rei.relativeDifficulty, rei.numSkillUps
		local showAll = true
		if rei.recipeID then
			local tradeSkillID = C_TradeSkillUI.GetTradeSkillLineForRecipe(rei.recipeID)
			if tradeSkillID then
				local skillInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(tradeSkillID)
				if skillInfo and skillInfo.skillLevel and skillInfo.maxSkillLevel
				   and skillInfo.skillLevel >= skillInfo.maxSkillLevel then
					showAll = false
				end
			end
		end
		if showAll then
			rs = (rs ~= "" and rs or " ") .. " |A:" .. DIFFICULTY_ATLAS[d] .. ":13:14:|a"
			if (sk and sk > 1) then
				rs = rs .. DIFFICULTY_COLOR_CODE[d] .. sk .. "|r"
			end
		end
	end
	s.orderInfo, wr.orderID, wr.skillLineAbilityID = oi, oi.orderID, oi.skillLineAbilityID
	if s.request then
		s.request:SetText(orderName .. rs)
	end
	if s.reward then
		s.reward:SetText(oi.goldRewardString)
	end
	if s.evenBG then
		s.evenBG:SetShown(i % 2 == 0)
	end
	confOrderRowPatron(i, s, false)

	if s.totalReward then
		if oi.rewardTotalValue then
			s.totalReward:SetText(GetMoneyString(oi.rewardTotalValue, true))
		else
			s.totalReward:SetText("")
		end
	end
	if s.mainIcon then
		confIconButton(s.mainIcon, oi, nil, nil, et)
	end
	if s.craftingCost then
		if oi.craftingCost and oi.rewardTotalValue then
			local profit = oi.rewardTotalValue - oi.craftingCost
			local profitWithoutCopper = math.floor(profit / 100) * 100
			local colorCode
			if oi.hasUnknownCost then
				colorCode = "|cFFFFA500"
				s.craftingCost:SetText(colorCode .. L"Unknown|r")
			else
				if profit >= 0 then
					colorCode = "|cff00ff00"
					s.craftingCost:SetText(colorCode .. GetMoneyString(profitWithoutCopper, true) .. "|r")
				else
					colorCode = "|cffff0000"
					s.craftingCost:SetText(colorCode .. "-" .. GetMoneyString(math.abs(profitWithoutCopper), true) .. "|r")
				end
			end
			s.craftingCost:SetScript("OnEnter", function(self)
				if oi.hasUnknownCost then
					GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
					GameTooltip:SetText(L"Cost Unknown")
					GameTooltip:Show()
				else
					local profit = oi.rewardTotalValue - oi.craftingCost
					local totalRewardStr = GetMoneyString(oi.rewardTotalValue, true)
					local costStr = GetMoneyString(oi.craftingCost, true)
					local profitStr = GetMoneyString(math.abs(profit), true)
					GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
					GameTooltip:AddLine(L"Cost Details")
					GameTooltip:AddLine(" ")
					GameTooltip:AddDoubleLine(L"Total Reward:", SafeGetMoneyString(oi.rewardTotalValue), 1,1,1,1,1,1)
					GameTooltip:AddDoubleLine(L"Material Cost:", SafeGetMoneyString(oi.craftingCost), 1,1,1,1,1,1)
					GameTooltip:AddLine("——————————————")
					local profitStr = SafeGetMoneyString(math.abs(profit), true)
					if profit < 0 then
						GameTooltip:AddDoubleLine(L"Estimated Profit:", colorCode .. "-" .. profitStr .. "|r", 1, 1, 1, 1, 1, 1)
					else
						GameTooltip:AddDoubleLine(L"Estimated Profit:", colorCode .. profitStr .. "|r", 1, 1, 1, 1, 1, 1)
					end
					GameTooltip:Show()
				end
			end)
			s.craftingCost:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		else
			s.craftingCost:SetText("")
		end
	end
	local rr, rrw = s.rewards, s.rewardsW
	for i = 1, #oi.npcOrderRewards do
		local ri, rs = oi.npcOrderRewards[i], rr[i] or Acquire("IconButton", wr)
		if rs and rs.root then
			rs.root:SetPoint("TOPLEFT", REWARD_COLUMN_XOFS + 4 + 36 * (i - 1), -18)
			confIconButton(rs, ri, ri.count)
			rr[i], rrw[i] = rs, rs.root
		end
	end
	releaseIconButtons(rr, rrw, #oi.npcOrderRewards + 1)
	local rr, rrw, sm, ni = s.reagents, s.reagentsW, oi.recipeSchematic, 1
	for i = 1, #sm.reagentSlotSchematics do
		local rss = sm.reagentSlotSchematics[i]
		if rss.required and not rss.cover then
			local firstReagent = rss.reagents and rss.reagents[1]
			if firstReagent then
				local rs = rr[ni] or Acquire("IconButton", wr)
				if rs and rs.root then
					rs.root:SetPoint("TOPLEFT", s.mainIcon.root, "TOPRIGHT", 4 + 36 * (ni - 1), -18)
					rr[ni], rrw[ni], ni = rs, rs.root, ni + 1
					confIconButton(rs, firstReagent, rss.quantityRequired, rss.reagents)
				end
			end
		end
	end
	local oiConcF = oi.concentrationCost
	if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and oi.ignorePriceDiffConcentrationCost ~= nil
		and (oi.lameConcentrationCost == nil or oi.lameConcentrationCost > 0) then
		oiConcF = oi.ignorePriceDiffConcentrationCost
	end
	if oiConcF and oiConcF > 0 and oi.concentrationCurrencyID then
		local concData = {currencyType = oi.concentrationCurrencyID, count = oiConcF}
		local rs = rr[ni] or Acquire("IconButton", wr)
		if rs and rs.root then
			rs.root:SetPoint("TOPLEFT", s.mainIcon.root, "TOPRIGHT", 4 + 36 * (ni - 1), -18)
			rr[ni], rrw[ni], ni = rs, rs.root, ni + 1
			confIconButton(rs, concData, oiConcF)
			s.concIcon = rs.root
		end
	end
	releaseIconButtons(rr, rrw, ni)
	local lastIcon = s.mainIcon.root
	local rr, rrw, sm, ni = s.reagents, s.reagentsW, oi.recipeSchematic, 1

	local hasPlayerMaterials = false
	for _, rss in ipairs(sm.reagentSlotSchematics) do
		if rss.required and not rss.cover then
			hasPlayerMaterials = true
			break
		end
	end
	local missing = IsOrderMissingReagents(oi)
	for i = 1, #sm.reagentSlotSchematics do
		local rss = sm.reagentSlotSchematics[i]
		if rss.required and not rss.cover then
			local firstReagent = DFPO_GetBestDisplayReagent(rss.reagents, oi)
			if firstReagent then
				local rs = rr[ni] or Acquire("IconButton", wr)
				if rs and rs.root then
					rs.root:SetPoint("TOPLEFT", s.mainIcon.root, "TOPRIGHT", 4 + 36 * (ni - 1), -18)
					rr[ni], rrw[ni], ni = rs, rs.root, ni + 1
					confIconButton(rs, firstReagent, rss.quantityRequired, rss.reagents)
					lastIcon = rs.root
				end
			end
		end
	end
	local oiConcS = oi.concentrationCost
	if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and oi.ignorePriceDiffConcentrationCost ~= nil
		and (oi.lameConcentrationCost == nil or oi.lameConcentrationCost > 0) then
		oiConcS = oi.ignorePriceDiffConcentrationCost
	end
	if oiConcS and oiConcS > 0 and oi.concentrationCurrencyID then
		local concData = {currencyType = oi.concentrationCurrencyID, count = oiConcS}
		local rs = rr[ni] or Acquire("IconButton", wr)
		if rs and rs.root then
			rs.root:SetPoint("TOPLEFT", s.mainIcon.root, "TOPRIGHT", 4 + 36 * (ni - 1), -18)
			rr[ni], rrw[ni], ni = rs, rs.root, ni + 1
			confIconButton(rs, concData, oiConcS)
			lastIcon = rs.root
		end
	end
	releaseIconButtons(rr, rrw, ni)
	local hasPlayerMaterials = false
	for _, rss in ipairs(sm.reagentSlotSchematics) do
		if rss.required and not rss.cover then
			hasPlayerMaterials = true
			break
		end
	end
	if hasPlayerMaterials and not missing then
		s.materialReady:Show()
		s.materialReadyText:Show()
		local yOffset = (oi.concentrationCost and oi.concentrationCost > 0) and -5 or -5
		s.materialReady:SetPoint("LEFT", lastIcon, "RIGHT", 0, yOffset)
		s.materialReadyText:SetPoint("LEFT", s.materialReady, "RIGHT", 0, 0)
	else
		s.materialReady:Hide()
		s.materialReadyText:Hide()
	end
	if hasPlayerMaterials and missing then
		if not s.pendingMissingCheck then
			s.pendingMissingCheck = true
			C_Timer.After(0.5, function()
				s.pendingMissingCheck = nil
				if s.root and s.root:IsVisible() then
					local newMissing = IsOrderMissingReagents(oi)
					if not newMissing then
						confOrderRow(s, oi, i, 'delayed-refresh')
					end
				end
			end)
		end
	end
	if s.artText then
		s.artText:SetShown(not hasPlayerMaterials)
		if not hasPlayerMaterials then
			local anchorFrame = (s.concIcon and s.concIcon:IsShown()) and s.concIcon or s.mainIcon.root
			local yOffset = (anchorFrame == s.concIcon) and -12 or -30
			s.artText:ClearAllPoints()
			s.artText:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 6, yOffset)
		end
	end
	if s.checkbox then
		if oi and oi.orderID then
			if checkedOrders[oi.orderID] == nil then
				checkedOrders[oi.orderID] = true
			end
			s.checkbox:SetChecked(checkedOrders[oi.orderID])
			s.checkbox:Show()
		else
			s.checkbox:Hide()
		end
	end
	if s.redOverlay then
		local isChecked = (checkedOrders[oi.orderID] ~= false)
		s.redOverlay:SetShown(not isChecked)
	end
end

function DFPO_GetBestDisplayReagent(reagents, orderInfo)
	local function defaultCheapest()
		local itemID, _ = select(1, GetLowestCostReagentInfo(reagents))
		if itemID then
			for _, r in ipairs(reagents) do if r.itemID == itemID then return r end end
		end
		return reagents[1]
	end
	if not DFCN_PatronOffersDB or not DFCN_PatronOffersDB.ignorePriceDiff or not orderInfo or not orderInfo._needsBetterMats then
		return defaultCheapest()
	end
	local threshold = DFCN_PatronOffersDB.priceDiffThreshold or 10000
	local candidates = {}
	for _, r in ipairs(reagents) do
		if r.itemID then
			local p = CalculateItemValue(r.itemID) or 0
			local q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(r.itemID) or 1
			table.insert(candidates, {reagent = r, price = p, quality = q})
		end
	end
	if #candidates == 0 then return defaultCheapest() end
	table.sort(candidates, function(a, b) return a.price < b.price end)
	local cheapest = candidates[1]
	local best = cheapest
	for _, c in ipairs(candidates) do
		if c.price - cheapest.price <= threshold and c.quality > best.quality then
			best = c
		end
	end
	return best.reagent
end

local function confOrderList(oa, cause, rawCount)
	oa = sortOrders(oa)
	ui.nextUpdateTick, ui.forceResync = GetTime() + 60, nil
	ui.syncCount, ui.syncID, ui.orderList = oa and #oa or 0, ui.syncID + 1, oa
	local rows, rowsW, clip, origin = ui.rows, ui.rowsW, ui.clip, ui.origin
	if not ui.noOrdersText then
		local text = ui.clip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("CENTER", ui.clip, "CENTER", 0, 0)
		text:SetTextColor(0.6, 0.6, 0.6)
		ui.noOrdersText = text
	end
	local shouldUpdateHint = (cause == "rco-callback" or cause == "filter-changed" or cause == "sort")
	if shouldUpdateHint then
		if #oa == 0 then
			if rawCount and rawCount > 0 then
				ui.noOrdersText:SetText(string.format(L'Filtered no match', rawCount))
				ui.noOrdersText:Show()
			else
				ui.noOrdersText:Hide()
			end
		else
			ui.noOrdersText:Hide()
		end
	else
		if #oa > 0 then
			ui.noOrdersText:Hide()
		end
	end
	for i = 1, #oa do
		local oi, s = oa[i], rows[i] or Acquire("OrderRow", clip)
		if s and s.root then
			s.root:SetPoint("TOPLEFT", origin, 0, -54 * (i - 1))
			rows[i], rowsW[i] = s, s.root
			confOrderRow(s, oi, i, cause)
		end
	end
	ui.bar:SetMinMaxValues(0, math.max(0, #oa - 10))
	for i = #oa + 1, #rows do
		local s = rows[i]
		if s then
			releaseIconButtons(s.rewards, s.rewardsW, 1)
			releaseIconButtons(s.reagents, s.reagentsW, 1)
			rows[i], rowsW[i] = Release("OrderRow", s.root)
		end
	end
end

function syncOrderList(cause)
	if not ui.root or not ui.root:IsShown() then return end
	if not ui.ready then
		C_Timer.After(0.1, function() syncOrderList(cause) end)
		return
	end
	local request = {
		profession = 0,
		orderType = 3,
		forCrafter = true,
		offset = 0,
		searchFavorites = false,
		initialNonPublicSearch = false,
		primarySort = DUMMY_SORT,
		secondarySort = DUMMY_SORT,
		callback = function(res, ot)
			if res == 0 and ot == 3 and ui.root:IsVisible() then
				syncOrderList("rco-callback")
			end
		end
	}
	if cause == "initial" or cause == "cuoc-resync" or cause == "profession-changed" then
		orderListBackup = nil
	end
	local info = C_TradeSkillUI.GetBaseProfessionInfo()
	if not info or not info.profession then
		C_Timer.After(1, function() syncOrderList(cause) end)
		return
	end
	local syncID = ui.syncID
	if cause ~= "rco-callback" then
		if cause == "profession-changed" then
			local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
			if ordersPage and ordersPage.SetCraftingOrderType then
				ordersPage:SetCraftingOrderType(3)
			end
			local retryCount = 0
			local function makeRequest()
				request.profession = info.profession
				request.callback = function(res, ot)
					if res == 0 and ot == 3 and ui.root:IsVisible() then
						syncOrderList("rco-callback")
					elseif res ~= 0 and ui.root:IsVisible() and retryCount < 2 then
						retryCount = retryCount + 1
						C_Timer.After(0.3, makeRequest)
					end
				end
				C_CraftingOrders.RequestCrafterOrders(request)
				if ui.syncID ~= syncID then
					ui.forceResync = nil
					return
				end
			end
			makeRequest()
		elseif C_TradeSkillUI.IsNearProfessionSpellFocus(info.profession) then
			request.profession = info.profession
			C_CraftingOrders.RequestCrafterOrders(request)
			if ui.syncID ~= syncID then
				ui.forceResync = nil
				return
			end
		end
	end
	local allOrders = C_CraftingOrders.GetCrafterOrders()
	lastRawOrderCount = #allOrders
	local oa, badData = prepareOrders(allOrders)
	ui.fullOrderBackup = oa
	ui.partialData = badData
	local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
	local professionID = professionInfo and professionInfo.professionID or 0
	local enablePerSpec = (DFCN_PatronOffersDB.specEnabled or {})[professionID] or false
	local activeFilters
	if enablePerSpec then
		activeFilters = DFCN_PatronOffersDB.specFilters[professionID] or {}
	else
		activeFilters = DFCN_PatronOffersDB.filters
	end
	ui.lastActiveFilters = activeFilters
	local filteredOA = {}
	for _, order in ipairs(oa) do
		local shouldDisable = false
		if activeFilters.unlearned and not order.recipeInfo.learned then
			shouldDisable = true
		end
		if activeFilters.needFocus then
			local effConc = order.concentrationCost or 0
			if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and order.ignorePriceDiffConcentrationCost ~= nil
				and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
				effConc = order.ignorePriceDiffConcentrationCost
			end
			if effConc > 0 then
				shouldDisable = true
			end
		end
		if activeFilters.profitBelow and order.profit and order.profit < (activeFilters.profitThreshold or 0) then
			shouldDisable = true
		end
		if not activeFilters.showFilteredOrders then
			if not shouldDisable then
				table.insert(filteredOA, order)
			end
		else
			if checkedOrders[order.orderID] == nil then
				checkedOrders[order.orderID] = not shouldDisable
			end
			table.insert(filteredOA, order)
		end
	end
	ui.forceResync = nil
	if ui.root and ui.root:IsShown() then
		confOrderList(filteredOA, cause, #oa)
	else
		ui.orderList = filteredOA
		if SummaryFrame and SummaryFrame:IsShown() then
			T.UpdateSummaryWindow()
		end
	end
	if UpdateProfessionCurrencyDisplay then
		UpdateProfessionCurrencyDisplay()
	end
end

do
	local root = Acquire("RootUI", nil).root
	root:SetPoint("BOTTOMRIGHT", -2, 3)
	ui.clip:SetScript("OnShow", function()
		local currentProfId = C_TradeSkillUI.GetBaseProfessionInfo().professionID or 0
		if ui.lastShownProfId and ui.lastShownProfId ~= currentProfId then
			local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
			local professionID = professionInfo and professionInfo.professionID or 0
			local enablePerSpec = (DFCN_PatronOffersDB.specEnabled or {})[professionID] or false
			local activeFilters
			if enablePerSpec then
				activeFilters = DFCN_PatronOffersDB.specFilters[professionID] or {}
			else
				activeFilters = DFCN_PatronOffersDB.filters
			end
			RefreshHeaderFilterTexts(activeFilters)
			
			ui.lastShownProfId = currentProfId
			C_Timer.After(0.1, function()
				syncOrderList("profession-changed")
			end)
		else
			ui.lastShownProfId = currentProfId
			ui.forceResync = "onshow-resync"
			ui.updateFilterAndResync()
		end
	end)
	ui.clip:SetScript("OnUpdate", function()
		if ui.forceResync then
			syncOrderList(ui.forceResync)
		elseif ui.nextUpdateTick and ui.nextUpdateTick < GetTime() then
			ui.nextUpdateTick = GetTime() + 60
			for i = 1, #ui.rows do
				confOrderRowPatron(i, ui.rows[i], true)
			end
		end
	end)
	hooksecurefunc(ProfessionsFrame.OrdersPage, "SetCraftingOrderType", function(_, ot)
		local show = ot == 3 and not IsModifiedClick("ALT-SHIFT-BOOM")
		local bshow, bf = not show, ProfessionsFrame.OrdersPage.BrowseFrame
		bf.OrderList:SetShown(bshow)
		bf.SearchButton:SetShown(bshow)
		bf.FavoritesSearchButton:SetShown(bshow)
		ui.root:SetShown(show)
	end)
	function ui.cycleSortOrder(hid, reverse)
		if ui.sortBy ~= hid then
			ui.sortBy, ui.sortAsc = hid, not reverse
		elseif ui.sortAsc ~= reverse then
			ui.sortAsc = reverse
		else
			ui.sortBy = nil
		end
		if ui.sortBy then
			ui.sortArrow:SetParent(ui.headers[hid])
			ui.sortArrow:ClearAllPoints()
			ui.sortArrow:SetPoint("LEFT", ui.headers[hid]:GetFontString(), "RIGHT", 3, 0)
			ui.sortArrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
		end
		ui.sortArrow:SetShown(not not ui.sortBy)
		confOrderList(ui.orderList, "sort")
	end
	function root:RegisterOrderCallback(fun, includeTicks)
		assert(type(fun) == "function", 'Syntax: :RegisterOrderCallback(func[, includeTicks])')
		EV.POFF_ORDER_INIT = fun
		if includeTicks then
			EV.POFF_ORDER_TICK = fun
		end
	end
end

function EV:CRAFTINGORDERS_UPDATE_ORDER_COUNT(ot, count)
	if ot == 3 then
		if count == 0 and lastKnownOrderCount > 0 then
			ui.orderList = {}
			if SummaryFrame then SummaryFrame:Hide() end
		end
		lastKnownOrderCount = count
		if (lastRawOrderCount ~= count or ui.partialData) then
			syncOrderList("cuoc-resync")
		end
		ui.orderCount = count
	end
end

function EV:CRAFTINGORDERS_CAN_REQUEST()
	if (lastRawOrderCount ~= ui.orderCount or ui.partialData) and ui.root:IsVisible() then
		ui.forceResync = "ccr-resync"
	end
end

function EV:CRAFTINGORDERS_UPDATE_CUSTOMER_NAME(newCustomerName, orderID)
	for i = 1, #ui.rows do
		local s = ui.rows[i]
		if s and s.orderInfo and s.orderInfo.orderID == orderID then
			s.orderInfo.customerName = newCustomerName
			confOrderRowPatron(i, s, true)
		end
	end
end

function EV:CRAFTINGORDERS_UPDATE_REWARDS(newRewards, orderID)
	for i = 1, #ui.rows do
		local s = ui.rows[i]
		if s and s.orderInfo and s.orderInfo.orderID == orderID then
			s.orderInfo.npcOrderRewards = newRewards
			confOrderRow(s, s.orderInfo, i, 'cur-refresh')
		end
	end
end

function EV:ITEM_DATA_LOAD_RESULT(iid, ok)
	for i = 1, ok and not ui.forceResync and ui.root:IsVisible() and #ui.rows or 0 do
		local oi = ui.rows[i] and ui.rows[i].orderInfo
		if oi and oi.itemID == iid and oi.badName then
			mangleOrderName(oi)
			confOrderRow(ui.rows[i], oi, i, 'idlr-refresh')
		end
	end
end

local function pickOfferIfMatch(orderInfo, q, n)
	if orderInfo.recipeInfo.learned and
		(q == "acuity" and orderInfo.rewardAcuity >= n or
			q == "kp" and orderInfo.rewardKnowledge >= n or
			q == "") then
		return true, ProfessionsFrame.OrdersPage:ViewOrder(orderInfo)
	end
end

local function maybeShowPickWarning()
	if ui.pendingPickWarning then
		ui.pendingPickWarning = nil
		SilentPrint("|cfff00000" .. L"No matching patron orders available.")
	end
end

local OrderMultiButton = CreateFrame("Button", nil, ProfessionsFrame.OrdersPage.OrderView.OrderInfo, "MainMenuFrameButtonTemplate,InsecureActionButtonTemplate")
	if not OrderMultiButton.__bg then
		OrderMultiButton.__bg = {
			SetBackdropColor = function() end,
			SetBackdropBorderColor = function() end,
		}
	end
do
	local OrderView = ProfessionsFrame.OrdersPage.OrderView
	local OrderInfo = OrderView.OrderInfo
	local ConcToggleButton = OrderView.OrderDetails.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton

	local function GetCurrentOrderMirrorButton()
		local b1, b2, b3 = OrderInfo.StartOrderButton, OrderView.CreateButton, OrderView.CompleteOrderButton
		if b2:IsShown() then
			if (C_CraftingOrders.GetClaimedOrder() or "").isFulfillable then
				return b3, 3
			end
			return b2, 2
		elseif b1:IsShown() then
			return b1, 1
		elseif b3:IsShown() then
			return b3, 3
		end
	end
	local function DoesCurrentOrderNeedConcentration()
		local oi = OrderView.order
		local reqQuality = oi and oi.minQuality or 0
		local curQualityBase = math.floor(ConcToggleButton.quality or 0) - (ConcToggleButton:GetChecked() and 1 or 0)
		return reqQuality > 1 and not ConcToggleButton:AtMaxQuality() and curQualityBase < reqQuality
	end
	local ConcMirrorButton = CreateFrame("CheckButton", nil, OrderMultiButton, "InsecureActionButtonTemplate")
	do
		ConcMirrorButton:SetSize(28, 28)
		ConcMirrorButton:SetPoint("RIGHT", OrderMultiButton, "LEFT", -4, 0)
		ConcMirrorButton:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
		ConcMirrorButton:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
		ConcMirrorButton:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
		ConcMirrorButton:SetCheckedTexture("Interface/ICONS/Temp")
		ConcMirrorButton:GetCheckedTexture():SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
		ConcMirrorButton:SetDisabledTexture("Interface/ICONS/UI_Concentration")
		ConcMirrorButton:GetDisabledTexture():SetDesaturated(true)
		local ico = ConcMirrorButton:CreateTexture(nil, "BACKGROUND")
		ico:SetPoint("TOPLEFT")
		ico:SetPoint("BOTTOMRIGHT", -2, 0)
		ico:SetTexture("Interface/ICONS/UI_Concentration")
		ConcMirrorButton:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
		ConcMirrorButton:SetMotionScriptsWhileDisabled(true)
		ConcMirrorButton:SetAttribute("useOnKeyDown", false)
		ConcMirrorButton:SetAttribute("type", "click")
		ConcMirrorButton:SetAttribute("clickbutton", ConcToggleButton)
		ConcMirrorButton:SetScript("OnEnter", function(_, ...)
			ConcToggleButton:GetScript("OnEnter")(ConcMirrorButton, ...)
		end)
		ConcMirrorButton:SetScript("OnLeave", function(_, ...)
			ConcToggleButton:GetScript("OnLeave")(ConcMirrorButton, ...)
		end)
		for k in pairs(ProfessionsConcentrateToggleButtonMixin) do
			ConcMirrorButton[k] = function(_, ...) return ConcToggleButton[k](ConcToggleButton, ...) end
		end
	end
	local function ValidateMultiButton()
		local mbtn, idx = GetCurrentOrderMirrorButton()
		local isEnabled = mbtn and mbtn:IsEnabled() or false
		OrderMultiButton:SetEnabled(isEnabled)
		if mbtn and mbtn.LockHighlight and mbtn.UnlockHighlight then
			mbtn:LockHighlight()
			mbtn:UnlockHighlight()
		end
		if not isEnabled and idx == 2 then
			if DoesCurrentOrderNeedConcentration() then
				OrderMultiButton:SetText(L"Quality Not Met")
			else
				OrderMultiButton:SetText(L"Insufficient Materials")
			end
		else
			if idx == 2 and UnitCastingInfo("player") then
				OrderMultiButton:SetText(L"Cancel")
			else
				OrderMultiButton:SetText(idx == 1 and PROFESSIONS_START_ORDER
					or idx == 2 and mbtn:GetText()
					or idx == 3 and PROFESSIONS_COMPLETE_ORDER or "???")
			end
		end
		if idx == 2 then
			ConcMirrorButton:SetChecked(ConcToggleButton:GetChecked())
			ConcMirrorButton:SetEnabled(ConcToggleButton:IsEnabled())
			ConcMirrorButton:SetShown(DoesCurrentOrderNeedConcentration())
		else
			ConcMirrorButton:Hide()
			if ClearCastBarHold then
				ClearCastBarHold()
			end
		end
	end
	local CastBar, ClearCastBarHold = CreateFrame("Frame", nil, OrderMultiButton)
	do
		CastBar:SetPoint("BOTTOMLEFT", 4, 3)
		CastBar:SetPoint("BOTTOMRIGHT", -4, 3)
		CastBar:SetHeight(2)
		CastBar:Hide()
		local bg = CastBar:CreateTexture(nil, "BACKGROUND")
		bg:SetColorTexture(0.2, 0.2, 0.2)
		bg:SetHeight(2)
		bg:SetPoint("LEFT")
		bg:SetPoint("RIGHT")
		local tex = CastBar:CreateTexture(nil, "ARTWORK")
		tex:SetPoint("LEFT")
		tex:SetHeight(2)
		tex:SetColorTexture(1, 1, 1)
		local trackGUID, hold
		local function CastOnUpdate()
			local _, _, _, st, et, isTrade, guid = UnitCastingInfo("player")
			if isTrade and st and et then
				local w, p = CastBar:GetWidth(), (GetTime() * 1000 - st) / (et - st)
				tex:SetWidth(math.min(w, math.max(0.01, w * p)))
				trackGUID = guid
			elseif hold then
				tex:SetWidth(CastBar:GetWidth())
			else
				CastBar:Hide()
			end
		end
		local function WatchCast(_, e, _, guid)
			if e == "UNIT_SPELLCAST_START" and select(6, UnitCastingInfo("player")) and OrderMultiButton:IsVisible() then
				tex:SetVertexColor(1, 0.75, 0)
				CastBar:Show()
				CastOnUpdate(CastBar)
				ValidateMultiButton()
			elseif e == "UNIT_SPELLCAST_SUCCEEDED" and guid == trackGUID then
				CastBar:Show()
				tex:SetVertexColor(0.15, 0.85, 0.25)
				hold, trackGUID = 1, nil
				ValidateMultiButton()
			elseif e == "UNIT_SPELLCAST_STOP" and guid == trackGUID and not hold then
				CastBar:Hide()
				ValidateMultiButton()
			end
		end
		function ClearCastBarHold()
			hold = nil
		end
		CastBar:SetScript("OnEvent", WatchCast)
		CastBar:SetScript("OnUpdate", CastOnUpdate)
		CastBar:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
		CastBar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
		CastBar:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	end
	local abName, abInner = "DFCN_POFF_MagicButton"
	do
		local pfx, i = abName, 1
		while _G[abName] ~= nil do
			abName = pfx .. i
			i = i + 1
		end
		abInner = CreateFrame("Button", abName, nil, "InsecureActionButtonTemplate")
		abInner:SetAttribute("useOnKeyDown", false)
		local pendingClickA, pendingClickB, pendingClickC = nil
		local pendingSoundA = nil
		local function setPendingClickHandlers(a, b, c)
			pendingClickA, pendingClickB, pendingClickC = a, b, c
		end
		local function startOrder()
			return "click", OrderView.OrderInfo.StartOrderButton
		end
		local function craftOrderA()
			if ConcToggleButton:IsShown() and ConcToggleButton:GetChecked() and not DoesCurrentOrderNeedConcentration() then
				return "click", ConcToggleButton
			end
		end
		local function craftOrderB()
			return "click", OrderView.CreateButton
		end
		local function craftOrderC()
			local _, csp = StaticPopup_Visible("GENERIC_CONFIRMATION")
			if csp and csp.data.text == CRAFTING_ORDERS_OWN_REAGENTS_CONFIRMATION then
				return "click", csp:GetButton(1)
			end
		end
		local function completeOrder()
			return "click", OrderView.CompleteOrderButton
		end
		local function stopCasting()
			PlaySound(12334)
			return "macro", "/stopcasting"
		end
		abInner:SetScript("PreClick", function()
			local at, aa
			if pendingClickA then
				at, aa = pendingClickA()
			end
			pendingClickA, pendingClickB, pendingClickC = pendingClickB, pendingClickC, nil
			if at == "click" then
				abInner:SetAttribute("type", "click")
				abInner:SetAttribute("clickbutton", aa)
			else
				abInner:SetAttribute("type", nil)
			end
		end)
		OrderMultiButton:SetScript("PreClick", function()
			if DFCN_PatronOffersDB.autoEquipProficiencyTool then
				local order = ProfessionsFrame.OrdersPage.OrderView.order
				if order and order.orderType == 3 then
					EquipBestProficiencyTool()
				end
			end
			if InCombatLockdown() then
				GameTooltip:SetOwner(OrderMultiButton, "ANCHOR_TOP")
				GameTooltip:SetText("|cffff2000" .. SPELL_FAILED_AFFECTING_COMBAT)
				return
			end
			local _mbtn, idx = GetCurrentOrderMirrorButton()
			if idx == 1 then
				setPendingClickHandlers(startOrder)
			elseif idx == 2 then
				if UnitCastingInfo("player") then
					setPendingClickHandlers(stopCasting)
				else
					setPendingClickHandlers(craftOrderA, craftOrderB)
				end
			elseif idx == 3 then
				setPendingClickHandlers(completeOrder)
			end
			ValidateMultiButton()

			OrderMultiButton:SetAttribute("type", pendingClickA and "macro" or nil)
			if pendingClickA then
				PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
			end
		end)
		OrderMultiButton:SetScript("PostClick", function()
			local sid, ok, esh
			sid, pendingSoundA = pendingSoundA
			setPendingClickHandlers(nil)
			if sid then
				ok, esh = PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
				for i = sid, math.min(ok and esh or sid, sid + 10) do
					StopSound(i)
				end
			end
		end)
	end
	OrderMultiButton:SetAttribute("useOnKeyDown", false)
	OrderMultiButton:SetAttribute("type", "macro")
	OrderMultiButton:SetAttribute("macrotext", SLASH_STOPCASTING1 .. "\n" .. (SLASH_CLICK1 .. " " .. abName .. "\n"):rep(3))
	OrderMultiButton:SetHeight(32)
	OrderMultiButton:SetPoint("BOTTOM", 4, 50)
	OrderMultiButton:SetText("Magic Button")
	local function ApplyOrderMultiButtonSkin()
		if not OrderMultiButton then return end
		local E = _G.ElvUI and unpack(_G.ElvUI)
		local isElvUI = E and E.Skins
		if isElvUI then
			OrderMultiButton:SetNormalTexture("")
			OrderMultiButton:SetPushedTexture("")
			OrderMultiButton:SetDisabledTexture("")
			OrderMultiButton:SetHighlightTexture("")
			for i = 1, OrderMultiButton:GetNumRegions() do
				local region = select(i, OrderMultiButton:GetRegions())
				if region and region:GetObjectType() == "Texture" then
					region:SetTexture("")
					region:Hide()
				end
			end
			local bgTex = OrderMultiButton:CreateTexture(nil, "BACKGROUND")
			bgTex:SetAllPoints()
			bgTex:SetColorTexture(0.085, 0.085, 0.085, 1)
			OrderMultiButton.bgTex = bgTex
			local borderSize = 0.7
			local topBorder = OrderMultiButton:CreateTexture(nil, "OVERLAY")
			topBorder:SetPoint("TOPLEFT", OrderMultiButton, "TOPLEFT", 0, 0)
			topBorder:SetPoint("TOPRIGHT", OrderMultiButton, "TOPRIGHT", 0, 0)
			topBorder:SetHeight(borderSize)
			topBorder:SetColorTexture(1, 0, 0, 0)
			topBorder:Hide()
			local bottomBorder = OrderMultiButton:CreateTexture(nil, "OVERLAY")
			bottomBorder:SetPoint("BOTTOMLEFT", OrderMultiButton, "BOTTOMLEFT", 0, 0)
			bottomBorder:SetPoint("BOTTOMRIGHT", OrderMultiButton, "BOTTOMRIGHT", 0, 0)
			bottomBorder:SetHeight(borderSize)
			bottomBorder:SetColorTexture(1, 0, 0, 0)
			bottomBorder:Hide()
			local leftBorder = OrderMultiButton:CreateTexture(nil, "OVERLAY")
			leftBorder:SetPoint("TOPLEFT", OrderMultiButton, "TOPLEFT", 0, 0)
			leftBorder:SetPoint("BOTTOMLEFT", OrderMultiButton, "BOTTOMLEFT", 0, 0)
			leftBorder:SetWidth(borderSize)
			leftBorder:SetColorTexture(1, 0, 0, 0)
			leftBorder:Hide()
			local rightBorder = OrderMultiButton:CreateTexture(nil, "OVERLAY")
			rightBorder:SetPoint("TOPRIGHT", OrderMultiButton, "TOPRIGHT", 0, 0)
			rightBorder:SetPoint("BOTTOMRIGHT", OrderMultiButton, "BOTTOMRIGHT", 0, 0)
			rightBorder:SetWidth(borderSize)
			rightBorder:SetColorTexture(1, 0, 0, 0)
			rightBorder:Hide()
			OrderMultiButton.borders = {topBorder, bottomBorder, leftBorder, rightBorder}
			OrderMultiButton:SetNormalFontObject("GameFontNormal")
			OrderMultiButton:SetHighlightFontObject("GameFontHighlight")
			OrderMultiButton:SetDisabledFontObject("GameFontDisable")
			local fontString = OrderMultiButton:GetFontString()
			if fontString then
				fontString:SetTextColor(1, 0.82, 0, 1)
				fontString:ClearAllPoints()
				fontString:SetPoint("CENTER")
			end
			OrderMultiButton:SetScript("OnEnter", function(self)
				if self:IsEnabled() then
					local fs = self:GetFontString()
					if fs then fs:SetTextColor(1, 1, 1, 1) end
					if self.borders then
						for _, b in ipairs(self.borders) do
							b:SetColorTexture(0.769, 0.122, 0.231, 1)
							b:Show()
						end
					end
				end
			end)
			OrderMultiButton:SetScript("OnLeave", function(self)
				if self:IsEnabled() then
					local fs = self:GetFontString()
					if fs then fs:SetTextColor(1, 0.82, 0, 1) end
					if self.borders then
						for _, b in ipairs(self.borders) do
							b:SetColorTexture(1, 0, 0, 0)
							b:Hide()
						end
					end
				end
			end)
			OrderMultiButton:SetScript("OnEnable", function(self)
				local fs = self:GetFontString()
				if fs then fs:SetTextColor(1, 0.82, 0, 1) end
			end)
			OrderMultiButton:SetScript("OnDisable", function(self)
				local fs = self:GetFontString()
				if fs then fs:SetTextColor(1, 0, 0, 1) end
			end)
		else
			OrderMultiButton:SetNormalFontObject(GameFontNormalMed3)
			OrderMultiButton:SetHighlightFontObject(GameFontHighlightMedium)
			OrderMultiButton:SetDisabledFontObject(GameFontDisableMed3)
		end
	end
	local f = CreateFrame("Frame")
	f.elapsed = 0
	f:SetScript("OnUpdate", function(self, e)
		self.elapsed = self.elapsed + e
		if self.elapsed < 0.2 then return end
		self.elapsed = 0
		if OrderMultiButton then
			ApplyOrderMultiButtonSkin()
			self:SetScript("OnUpdate", nil)
		end
	end)
	local conParent = CreateFrame("Frame", nil, OrderInfo.StartOrderButton:GetParent())
	conParent:SetAllPoints()
	OrderInfo.StartOrderButton:SetParent(conParent)
	local function FixHighlightFont(b)
		if b and b.LockHighlight and b.UnlockHighlight then
			b:LockHighlight()
			b:UnlockHighlight()
		end
	end
	OrderMultiButton:HookScript("OnShow", function()
		conParent:Hide()
		ValidateMultiButton()
	end)
	OrderMultiButton:HookScript("OnHide", function()
		conParent:Show()
		OrderMultiButton:Hide()
		ClearCastBarHold()
		if GameTooltip:IsOwned(OrderMultiButton) then
			GameTooltip:Hide()
		end
	end)
	local MirrorOnEnter
	do
		local mirroredOnEnterFor
		local function MirrorOnLeave(self)
			local onLeave = mirroredOnEnterFor and mirroredOnEnterFor:GetScript("OnLeave")
			if onLeave then
				securecall(onLeave, mirroredOnEnterFor)
			end
			mirroredOnEnterFor = nil
			if not OrderMultiButton:IsMouseMotionFocus() and GameTooltip:IsOwned(OrderMultiButton) then
				GameTooltip:Hide()
			end
		end
		function MirrorOnEnter(self, ...)
			if OrderMultiButton:GetText() == L"Insufficient Materials" or OrderMultiButton:GetText() == L"Quality Not Met" then
				return
			end
			local m = GetCurrentOrderMirrorButton()
			local mOnEnter = m and m:GetScript("OnEnter")
			if mirroredOnEnterFor and mirroredOnEnterFor ~= m then
				MirrorOnLeave(self)
			end
			mirroredOnEnterFor = mOnEnter and m
			if mOnEnter then
				mOnEnter(m, ...)
			end
		end
		OrderMultiButton:SetScript("OnEnter", MirrorOnEnter)
		OrderMultiButton:SetScript("OnLeave", MirrorOnLeave)
	end
	hooksecurefunc(OrderView, "SetOrderState", function(self)
		if self ~= OrderView then return end
		ValidateMultiButton()
		if OrderMultiButton:IsMouseMotionFocus() then
			MirrorOnEnter(OrderMultiButton)
		end
	end)
	hooksecurefunc(OrderView, "UpdateCreateButton", ValidateMultiButton)
	hooksecurefunc(OrderView, "UpdateStartOrderButton", ValidateMultiButton)
	hooksecurefunc(OrderView, "SetOrder", function(_, order)
		local orderType = order and order.orderType
		OrderMultiButton:SetShown(orderType and orderType >= 0 and orderType <= 3)
	end)
end

local function UpdateOrderMultiButtonVisibility()
	if not OrderMultiButton then return end
	local orderView = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
	if not orderView then OrderMultiButton:Hide() return end
	local order = orderView.order
	if not order then OrderMultiButton:Hide() return end
	local orderType = order.orderType
	if orderType >= 0 and orderType <= 3 then
		OrderMultiButton:SetShown(true)
		if orderType == 2 then
			OrderMultiButton:ClearAllPoints()
			OrderMultiButton:SetPoint("BOTTOM", 4, 120)
		else
			OrderMultiButton:ClearAllPoints()
			OrderMultiButton:SetPoint("BOTTOM", 4, 50)
		end
	else
		OrderMultiButton:SetShown(false)
	end
end

local SUMMARY_ORDER_COLUMN_WIDTH = 300
local SUMMARY_COST_COLUMN_WIDTH = 90
local SUMMARY_REWARD_COLUMN_WIDTH = 90
local SUMMARY_TOTAL_WIDTH = SUMMARY_ORDER_COLUMN_WIDTH + SUMMARY_COST_COLUMN_WIDTH + SUMMARY_REWARD_COLUMN_WIDTH + 20
if not DFCN_PatronOffersDB.summaryFramePosition then
	DFCN_PatronOffersDB.summaryFramePosition = {"RIGHT", "UIParent", "RIGHT", -20, 0}
end

local function SafeViewOrder(orderInfo)
	if not orderInfo then return false end
	local info = C_TradeSkillUI.GetBaseProfessionInfo()
	if info and info.profession and not C_TradeSkillUI.IsNearProfessionSpellFocus(info.profession) then
		SilentPrint(L"Msg_FarFromStation")
		return false
	end
	ProfessionsFrame.OrdersPage:ViewOrder(orderInfo)
	return true
end

local function OpenOrderWithValidation(orderInfo)
	if not orderInfo then return end
	local targetOrderID = orderInfo.orderID
	local recipeID = orderInfo.recipeInfo.recipeID
	if not recipeID then return end
	local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
	if not (professionInfo and professionInfo.parentProfessionID) then return end
	local tradeSkillID = professionInfo.parentProfessionID
	C_TradeSkillUI.OpenTradeSkill(tradeSkillID)
	local info = C_TradeSkillUI.GetBaseProfessionInfo()
	if info and info.profession and not C_TradeSkillUI.IsNearProfessionSpellFocus(info.profession) then
		SilentPrint(L"Msg_FarFromStation")
		return
	end
	C_Timer.After(0.2, function()
		if ProfessionsFrame.OrdersPage then
			ProfessionsFrame.OrdersPage:SetCraftingOrderType(3)
		end
		local checkCount = 0
		local maxChecks = 30
		local function check()
			checkCount = checkCount + 1
			if not ProfessionsFrame or not ProfessionsFrame:IsShown() then return end
			local claimed = C_CraftingOrders.GetClaimedOrder()
			if claimed then
				if claimed.orderID == targetOrderID then
					SafeViewOrder(claimed)
					return
				else
					local itemLink = L"[Unknown Item]"
					if claimed.itemID then
						local displayItemID = claimed.itemID
						if claimed.minQuality and claimed.minQuality > 0 then
							local recipeInfo = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(claimed.skillLineAbilityID, 2)
							if recipeInfo and recipeInfo.qualityItemIDs and recipeInfo.qualityItemIDs[claimed.minQuality] then
								displayItemID = recipeInfo.qualityItemIDs[claimed.minQuality]
							end
						end
						local _, link = GetItemInfo(displayItemID)
						itemLink = link or ('|Hitem:' .. displayItemID .. '|h' .. L'[Item]' .. '|h')
					end
					SilentPrint(string.format(L"Msg_ExistingOrder", itemLink))
					SafeViewOrder(claimed)
					return
				end
			end
			local allOrders = C_CraftingOrders.GetCrafterOrders()
			for _, o in ipairs(allOrders) do
				if o.orderID == targetOrderID then
					SafeViewOrder(o)
					return
				end
			end
			if checkCount < maxChecks then
				C_Timer.NewTimer(0.1, check)
			end
		end
		check()
	end)
end

local SummaryFrame = CreateFrame("Frame", "PatronOffersSummary", UIParent)
SummaryFrame:SetSize(SUMMARY_TOTAL_WIDTH, 300)
SummaryFrame:EnableKeyboard(true)
SummaryFrame:SetPropagateKeyboardInput(true)
if DFCN_PatronOffersDB.summaryFramePosition then
	SummaryFrame:SetPoint(unpack(DFCN_PatronOffersDB.summaryFramePosition))
else
	SummaryFrame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
end

SummaryFrame:SetFrameStrata("DIALOG")
SummaryFrame:SetClampedToScreen(true)
SummaryFrame:EnableMouse(true)
SummaryFrame:SetMovable(true)
SummaryFrame:RegisterForDrag("LeftButton")
SummaryFrame:SetScript("OnDragStart", function(self)
	if DFCN_PatronOffersDB.summaryFrameLocked then return end
	self:StartMoving()
end)
SummaryFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
	local relativeToName = relativeTo and relativeTo:GetName()
	DFCN_PatronOffersDB.summaryFramePosition = {point, relativeToName, relativePoint, xOfs, yOfs}
	local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
	local left, bottom, width, height = self:GetRect()
	if not left then return end
	local right = left + width
	local top = bottom + height
	local deltaX, deltaY = 0, 0
	if left < 0 then
		deltaX = -left
	elseif right > screenWidth then
		deltaX = screenWidth - right
	end
	if bottom < 0 then
		deltaY = -bottom
	elseif top > screenHeight then
		deltaY = screenHeight - top
	end
	if deltaX ~= 0 or deltaY ~= 0 then
		self:ClearAllPoints()
		self:SetPoint(point, relativeTo or UIParent, relativePoint, xOfs + deltaX, yOfs + deltaY)
		local newPoint, newRelativeTo, newRelativePoint, newX, newY = self:GetPoint()
		local newRelativeToName = newRelativeTo and newRelativeTo:GetName()
		DFCN_PatronOffersDB.summaryFramePosition = {newPoint, newRelativeToName, newRelativePoint, newX, newY}
	end
end)
SummaryFrame:Hide()

local bg = SummaryFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.0, 0.0, 0.0, 0.8)
local titleBar = CreateFrame("Frame", nil, SummaryFrame)
titleBar:SetHeight(26)
titleBar:SetPoint("TOPLEFT", 5, -5)
titleBar:SetPoint("TOPRIGHT", -5, -5)
local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
titleBarBg:SetAllPoints()
titleBarBg:SetColorTexture(0, 0, 0, 0.0)
local leftIcon = titleBar:CreateTexture(nil, "OVERLAY")
leftIcon:SetSize(18, 18)
leftIcon:SetPoint("LEFT", titleBar, "LEFT", 5, 0)
leftIcon:SetTexture("Interface\\MINIMAP\\TRACKING\\Auctioneer")
SummaryFrame.leftIcon = leftIcon
local leftDataText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftDataText:SetPoint("LEFT", leftIcon, "RIGHT", 1, 0)
leftDataText:SetText(L"AH Data: ")
leftDataText:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
leftDataText:SetTextColor(1, 1, 1)
SummaryFrame.leftDataText = leftDataText
local centerTitleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
centerTitleText:SetPoint("CENTER")
centerTitleText:SetText(L"Patron Shopping Helper")
centerTitleText:SetFont(GameFontNormal:GetFont(), 16, "OUTLINE")
centerTitleText:SetTextColor(1, 1, 0.8)
SummaryFrame.centerTitleText = centerTitleText
local closeBtn = CreateFrame("Button", nil, titleBar)
closeBtn:SetPoint("RIGHT", -2, 0)
local lockBtn = CreateFrame("Button", nil, titleBar)
lockBtn:SetPoint("RIGHT", closeBtn, "LEFT", 2, 0)
lockBtn:SetSize(24, 24)
lockBtn.text = lockBtn:CreateFontString(nil, "OVERLAY")
lockBtn.text:SetFont(GameFontNormal:GetFont(), 16, "OUTLINE")
lockBtn.text:SetPoint("CENTER")
local blankTex2 = lockBtn:CreateTexture()
blankTex2:SetColorTexture(0, 0, 0, 0)
blankTex2:SetAllPoints()
lockBtn:SetNormalTexture(blankTex2)
lockBtn:SetPushedTexture(blankTex2)
lockBtn:SetHighlightTexture(blankTex2)
lockBtn:SetScript("OnEnter", function(self)
	self.text:SetTextColor(1, 1, 1)
end)
lockBtn:SetScript("OnLeave", function(self)
	if DFCN_PatronOffersDB.summaryFrameLocked then
		self.text:SetTextColor(1, 0.2, 0.2)
	else
		self.text:SetTextColor(0.2, 1, 0.2)
	end
end)
lockBtn:SetScript("OnClick", function()
	DFCN_PatronOffersDB.summaryFrameLocked = not DFCN_PatronOffersDB.summaryFrameLocked
	if DFCN_PatronOffersDB.summaryFrameLocked then
		lockBtn.text:SetTextColor(1, 0.2, 0.2)
		lockBtn.text:SetText("L")
	else
		lockBtn.text:SetTextColor(0.2, 1, 0.2)
		lockBtn.text:SetText("U")
	end
end)
if DFCN_PatronOffersDB.summaryFrameLocked then
	lockBtn.text:SetTextColor(1, 0.2, 0.2)
	lockBtn.text:SetText("L")
else
	lockBtn.text:SetTextColor(0.2, 1, 0.2)
	lockBtn.text:SetText("U")
end
SummaryFrame.lockBtn = lockBtn
closeBtn:SetSize(24, 24)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY")
closeBtn.text:SetFont(GameFontNormal:GetFont(), 20, "OUTLINE")
closeBtn.text:SetText("×")
closeBtn.text:SetPoint("CENTER")
closeBtn.text:SetTextColor(1, 1, 1)
local blankTex = closeBtn:CreateTexture()
blankTex:SetColorTexture(0, 0, 0, 0)
blankTex:SetAllPoints()
closeBtn:SetNormalTexture(blankTex)
closeBtn:SetPushedTexture(blankTex)
closeBtn:SetHighlightTexture(blankTex)
closeBtn:SetScript("OnEnter", function(self)
	self.text:SetTextColor(1, 0.2, 0.2)
end)
closeBtn:SetScript("OnLeave", function(self)
	self.text:SetTextColor(1, 1, 1)
end)
closeBtn:SetScript("OnClick", function()
	orderListBackup = nil
	ui.orderList = {}
	lastKnownOrderCount = 0
	SummaryFrame:Hide()
	ui.manualSummaryOpen = false
end)

local headerFrame = CreateFrame("Frame", nil, SummaryFrame)
headerFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -5)
headerFrame:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -5)
headerFrame:SetHeight(20)
local function CreateSortableHeader(parent, text, columnId, width)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, 20)
	btn.columnId = columnId
	local textLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textLabel:SetText(text)
	textLabel:SetTextColor(1, 1, 0.8)
	textLabel:SetJustifyH("LEFT")
	textLabel:SetPoint("LEFT", 5, 0)
	btn.textLabel = textLabel
	btn.arrow = btn:CreateTexture(nil, "ARTWORK")
	btn.arrow:SetAtlas("auctionhouse-ui-sortarrow", true)
	btn.arrow:SetSize(10, 10)
	btn.arrow:SetPoint("LEFT", textLabel, "RIGHT", 2, 0)
	btn.arrow:Hide()
	btn:SetScript("OnClick", function(_, button)
		ui.cycleSortOrder(btn.columnId, button == "RightButton")
	end)
	local tooltips = {
		[1] = L"Order Name Tooltip",
		[2] = L"Est Profit Tooltip",
		[3] = L"Order Reward Tooltip 2"
	}
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(tooltips[columnId], nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return btn
end

local craftHeader = CreateSortableHeader(headerFrame, L"You craft/provide:", 1, SUMMARY_ORDER_COLUMN_WIDTH)
craftHeader:SetPoint("LEFT", 0, 0)
ui.summaryCraftHeader = craftHeader
craftHeader.baseText = L"You craft/provide:"
local costHeader = CreateSortableHeader(headerFrame, L"Profit:", 2, SUMMARY_COST_COLUMN_WIDTH)
costHeader:SetPoint("LEFT", craftHeader, "RIGHT", 0, 0)
local rewardHeader = CreateSortableHeader(headerFrame, L"You receive:", 3, SUMMARY_REWARD_COLUMN_WIDTH)
rewardHeader:SetPoint("LEFT", costHeader, "RIGHT", 0, 0)
local scrollFrame = CreateFrame("ScrollFrame", "POFFSummaryScroll", SummaryFrame)
scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 5, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
local scrollBar = CreateFrame("Slider", "POFFSummaryScrollBar", scrollFrame, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -15, -12)
scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -15, 12)
scrollBar:SetWidth(16)
scrollBar:SetMinMaxValues(0, 100)
scrollBar:SetValueStep(1)
scrollBar:SetValue(0)
scrollBar:Hide()
local scrollBg = scrollBar:CreateTexture(nil, "BACKGROUND")
scrollBg:SetAllPoints(scrollBar)
scrollBg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
	local currentValue = scrollBar:GetValue()
	local newValue = currentValue - (delta * 20)
	local minValue, maxValue = scrollBar:GetMinMaxValues()
	if newValue < minValue then
		newValue = minValue
	elseif newValue > maxValue then
		newValue = maxValue
	end
	scrollBar:SetValue(newValue)
end)
local materialsContainer = CreateFrame("Frame", nil, SummaryFrame)
materialsContainer:SetPoint("TOP", scrollFrame, "BOTTOM", 0, -5)
materialsContainer:SetPoint("LEFT", SummaryFrame, "LEFT", 0, 0)
materialsContainer:SetPoint("RIGHT", SummaryFrame, "RIGHT", 0, 0)
materialsContainer:SetHeight(55)
materialsContainer:Hide()
SummaryFrame.materialsContainer = materialsContainer
materialsContainer:EnableMouse(true)
local bgTex = materialsContainer:CreateTexture(nil, "BACKGROUND")
bgTex:SetAllPoints()
bgTex:SetColorTexture(0.0, 0.0, 0.0, 0.8)
materialsContainer.bgTex = bgTex
local divider = materialsContainer:CreateTexture(nil, "OVERLAY")
divider:SetPoint("TOPLEFT", materialsContainer, "TOPLEFT", 0, 0)
divider:SetPoint("TOPRIGHT", materialsContainer, "TOPRIGHT", 0, 0)
divider:SetHeight(1)
divider:SetColorTexture(0.6, 0.6, 0.6, 0.8)
materialsContainer.divider = divider
local contentContainer = CreateFrame("Frame", nil, materialsContainer)
contentContainer:SetPoint("TOPLEFT", materialsContainer, "TOPLEFT", 5, -5)
contentContainer:SetPoint("TOPRIGHT", materialsContainer, "TOPRIGHT", -5, -5)
contentContainer:SetHeight(45)
materialsContainer.contentContainer = contentContainer
local titleText = contentContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("LEFT", 3, 2)
titleText:SetText(L"Summary with Icon")
titleText:SetTextColor(1, 0.82, 0, 1)
titleText:SetFont(GameFontNormal:GetFont(), 16, "OUTLINE")
materialsContainer.titleText = titleText
local tooltipButton = CreateFrame("Button", nil, contentContainer)
tooltipButton:SetPoint("LEFT", titleText, "LEFT", 0, 0)
tooltipButton:SetSize(titleText:GetStringWidth() + 10, 24)
tooltipButton:EnableMouse(true)
tooltipButton:SetScript("OnEnter", function(self)
	titleText:SetTextColor(0, 1, 0)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if HAS_AUCTIONATOR then
		GameTooltip:SetText(L"Buy All", nil, nil, nil, nil, true)
	else
		GameTooltip:SetText(L"Need Auctionator for Buy All", nil, nil, nil, nil, true)
	end
	GameTooltip:Show()
end)
tooltipButton:SetScript("OnLeave", function()
	titleText:SetTextColor(1, 0.82, 0)
	GameTooltip:Hide()
end)

	local function CopyNeeds(needs)
		if not needs then return {} end
		local copy = {}
		for itemID, data in pairs(needs) do
			if type(data) == "table" and data.count then
				copy[itemID] = { count = data.count, quality = data.quality, isConcentration = data.isConcentration }
			end
		end
	copy._pending = {}
	for itemID, count in pairs(pendingPurchases) do
		copy._pending[itemID] = count
	end
		return copy
end

local isShoppingInProgress = false
local ahReadySince = 0
local function PerformOneClickShopping()
	if isShoppingInProgress then return end
	isShoppingInProgress = true
	if not HAS_AUCTIONATOR then
		SilentPrint(L"Msg_NeedAuctionator")
		isShoppingInProgress = false
		return
	end
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
		SilentPrint(L'Msg_NeedOpenAH')
		isShoppingInProgress = false
		return
	end
	local needs = SummaryFrame and SummaryFrame.currentMaterialNeeds
	if not needs or next(needs) == nil then
		SilentPrint(L"Msg_NoMaterialsToBuy")
		isShoppingInProgress = false
		return
	end
	lastMaterialNeedsSnapshot = CopyNeeds(needs)
	local searchTerms = {}
	local excludedCount = 0
	for itemID, data in pairs(needs) do
		if itemID ~= -1 then
			local reagents = data.reagents
			if reagents then
				local allVersions = GetQualityVersionsFromReagents(reagents)
				local vendorPrice = nil
				if HAS_AUCTIONATOR and Auctionator.API.v1.GetVendorPriceByItemID and itemID > 0 then
					vendorPrice = Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
				end
				local ahPrice = nil
				if HAS_AUCTIONATOR then
					ahPrice = Auctionator.API.v1.GetAuctionPriceByItemID(AUCTIONATOR_L_REAGENT_SEARCH, itemID)
				end
				local buyFromVendor = vendorPrice and vendorPrice > 0 and (not ahPrice or vendorPrice <= ahPrice)
				if buyFromVendor then
					excludedCount = excludedCount + 1
				else
					local name = C_Item.GetItemInfo(itemID)
					if name then
						name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
								   :gsub("|r", "")
								   :gsub("%[", "")
								   :gsub("%]", "")
								   :gsub("|H.-|h", "")
								   :gsub("|h", "")
								   :gsub("|T.-|t", "")
								   :gsub("^%s*(.-)%s*$", "%1")
						if name ~= "" then
							local term = {
								searchString = name,
								isExact = true,
								quantity = data.count,
							}
							if #allVersions > 1 then
								term.tier = data.quality
							end
							table.insert(searchTerms, term)
						end
					end
				end
			end
		end
	end
	if excludedCount > 0 then
		SilentPrint(string.format(L"Msg_ShoppingExcluded", excludedCount))
	end
	if #searchTerms == 0 then
		isShoppingInProgress = false
		return
	end
	local success, err = pcall(Auctionator.API.v1.MultiSearchAdvanced, "DFCN_PatronOffers", searchTerms)
	if not success then
		SilentPrint(L"Msg_ShoppingFailed")
	else
		SilentPrint(string.format(L"Msg_ShoppingCreated", #searchTerms))
	end
	isShoppingInProgress = false
end

tooltipButton:SetScript("OnClick", function(self, button)
	if button ~= "LeftButton" then return end
	PerformOneClickShopping()
end)

local pendingPurchase = {
	itemID = nil,
	quantity = nil,
}

local originalConfirmCommoditiesPurchase = C_AuctionHouse.ConfirmCommoditiesPurchase
C_AuctionHouse.ConfirmCommoditiesPurchase = function(itemID, quantity)
	pendingPurchase.itemID = itemID
	pendingPurchase.quantity = quantity
	originalConfirmCommoditiesPurchase(itemID, quantity)
end

local successFrame = CreateFrame("Frame")
successFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
successFrame:SetScript("OnEvent", function(self, event)
	if event ~= "COMMODITY_PURCHASE_SUCCEEDED" then return end
	local itemID = pendingPurchase.itemID
	local quantity = pendingPurchase.quantity
	if not itemID or not quantity then
		return
	end
	if SummaryFrame and SummaryFrame:IsShown() then
		pendingPurchases[itemID] = (pendingPurchases[itemID] or 0) + quantity
		if SummaryFrame:IsShown() then
			T.UpdateSummaryWindow()
		end
	end
	C_Timer.After(0.2, function()
		if not HAS_AUCTIONATOR then
			pendingPurchase.itemID = nil
			pendingPurchase.quantity = nil
			return
		end
		local shoppingListName = "DFCN_PatronOffers (" .. (AUCTIONATOR_L_TEMPORARY_LOWER_CASE) .. ")"
		local ok, items = pcall(Auctionator.API.v1.GetShoppingListItems, "DFCN_PatronOffers", shoppingListName)
		if not ok or not items or #items == 0 then
			pendingPurchase.itemID = nil
			pendingPurchase.quantity = nil
			return
		end
		local itemName = C_Item.GetItemInfo(itemID)
		if not itemName then
			pendingPurchase.itemID = nil
			pendingPurchase.quantity = nil
			return
		end
		local plainName = itemName:gsub("|c%x%x%x%x%x%x%x%x", "")
							  :gsub("|r", "")
							  :gsub("%[", "")
							  :gsub("%]", "")
							  :gsub("|H.-|h", "")
							  :gsub("|h", "")
							  :gsub("|T.-|t", "")
							  :gsub("^%s*(.-)%s*$", "%1")
		local oldSearchString = nil
		for _, s in ipairs(items) do
			if s:find(plainName, 1, true) then
				oldSearchString = s
				break
			end
		end
		if not oldSearchString then
			pendingPurchase.itemID = nil
			pendingPurchase.quantity = nil
			return
		end
		local oldTerms = Auctionator.API.v1.ConvertFromSearchString("DFCN_PatronOffers", oldSearchString)
		local newQuantity = (oldTerms.quantity or 0) - quantity
		if newQuantity > 0 then
			local newTerms = {
				searchString = plainName,
				isExact = true,
				quantity = newQuantity,
			}
			if oldTerms.tier then
				newTerms.tier = oldTerms.tier
			end
			local newSearchString = Auctionator.API.v1.ConvertToSearchString("DFCN_PatronOffers", newTerms)
			Auctionator.API.v1.AlterShoppingListItem("DFCN_PatronOffers", shoppingListName, oldSearchString, newSearchString)
		else
			Auctionator.API.v1.DeleteShoppingListItem("DFCN_PatronOffers", shoppingListName, oldSearchString)
		end
		local updatedItems = Auctionator.API.v1.GetShoppingListItems("DFCN_PatronOffers", shoppingListName)
		if #updatedItems > 0 then
			Auctionator.API.v1.CreateShoppingList("DFCN_PatronOffers", shoppingListName, updatedItems)
		else
			Auctionator.Shopping.ListManager:Delete(shoppingListName)
		end
		pendingPurchase.itemID = nil
		pendingPurchase.quantity = nil
	end)
end)

local failFrame = CreateFrame("Frame")
failFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
failFrame:SetScript("OnEvent", function(self, event)
	if event == "COMMODITY_PURCHASE_FAILED" then
		pendingPurchase.itemID = nil
		pendingPurchase.quantity = nil
	end
end)

local materialsLayout = CreateFrame("Frame", nil, contentContainer)
materialsLayout:SetPoint("LEFT", titleText, "RIGHT", 8, 0)
materialsLayout:SetPoint("RIGHT", -3, 0)
materialsLayout:SetHeight(30)
SummaryFrame.materialsLayout = materialsLayout
materialsLayout:EnableMouse(true)
SummaryFrame.summaryMaterialsIcons = {}
local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(SUMMARY_ORDER_COLUMN_WIDTH + SUMMARY_COST_COLUMN_WIDTH + SUMMARY_REWARD_COLUMN_WIDTH, 100)
scrollFrame:SetScrollChild(content)
if not SummaryFrame.rows then
	SummaryFrame.rows = {}
end
local rows = SummaryFrame.rows
local function CreateSummaryOrderRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(SUMMARY_ORDER_COLUMN_WIDTH + SUMMARY_COST_COLUMN_WIDTH + SUMMARY_REWARD_COLUMN_WIDTH, 54)
	local ib = Acquire("IconButton", row)
	ib.root:SetSize(40, 40)
	ib.root:SetPoint("TOPLEFT", 2, -7)
	row.mainIcon = ib
	local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	statusText:SetPoint("TOPLEFT", ib.root, "TOPRIGHT", 4, 0)
	statusText:SetHeight(14)
	statusText:SetJustifyH("LEFT")
	row.statusText = statusText
	local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nameText:SetPoint("TOPLEFT", ib.root, "TOPRIGHT", 4, 0)
	nameText:SetJustifyH("LEFT")
	nameText:SetWidth(SUMMARY_ORDER_COLUMN_WIDTH - 45)
	nameText:SetHeight(16)
	row.nameText = nameText
	row.reagents = {}
	row.rewards = {}
	local allReagentsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	allReagentsText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
	allReagentsText:SetText("|A:Professions-Icon-Customer:19:21:|a |cffc8c8c8" .. PROFESSIONS_CUSTOMER_ORDER_REAGENTS_ALL)
	allReagentsText:SetJustifyH("LEFT")
	allReagentsText:Hide()
	row.allReagentsText = allReagentsText
	local reagentsContainer = CreateFrame("Frame", nil, row)
	reagentsContainer:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
	reagentsContainer:SetHeight(28)
	row.reagentsContainer = reagentsContainer
	local costText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	costText:SetPoint("TOPLEFT", SUMMARY_ORDER_COLUMN_WIDTH + 5, -18)
	costText:SetWidth(SUMMARY_COST_COLUMN_WIDTH - 10)
	costText:SetJustifyH("LEFT")
	row.costText = costText
	local rewardText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	rewardText:SetPoint("TOPLEFT", SUMMARY_ORDER_COLUMN_WIDTH + SUMMARY_COST_COLUMN_WIDTH + 5, -3)
	rewardText:SetWidth(SUMMARY_REWARD_COLUMN_WIDTH - 10)
	rewardText:SetJustifyH("LEFT")
	row.rewardText = rewardText
	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.05)
	row.bg = bg
	row:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not IsShiftKeyDown() then
			OpenOrderWithValidation(self.orderInfo)
		end
	end)
	return row
end

local function FormatGoldString(gold)
	gold = floor(gold / 100) * 100
	return GetMoneyString(gold, true)
end

function T.UpdateSummaryWindow()
	if not SummaryFrame.rows then
		SummaryFrame.rows = {}
	end
	local rows = SummaryFrame.rows
	local filteredOrders = {}
	local savedScrollValue = 0
	if scrollBar and scrollBar:IsShown() then
		savedScrollValue = scrollBar:GetValue()
	end
	local function GetDataFreshness()
		if not HAS_AUCTIONATOR then return nil end
		local itemID = 2770
		local age = Auctionator.API.v1.GetAuctionAgeByItemID("DFCN_PatronOffers", itemID)
		if age then
			local days = math.floor(age + 0.5)
			if days == 0 then return L"Today"
			elseif days == 1 then return L"1DayAgo"
			else return string.format(L"DaysAgo", days) end
		else
			return L"ScanFirst"
		end
	end
	local function GetColoredFreshness(freshness)
		if freshness == L"Today" then
			return "|cFF00FF00" .. freshness .. "|r"
		elseif freshness:find(L"ScanFirst") then
			return "|cFFFF0000" .. freshness .. "|r"
		else
			local days = tonumber(freshness:match(L"DaysAgoPattern"))
			if days then
				if days == 1 then
					return "|cFF00FF00" .. freshness .. "|r"
				elseif days > 1 then
					return "|cFFFF7F00" .. freshness .. "|r"
				end
			end
		end
		return freshness
	end
	local dataText = ""
	if HAS_AUCTIONATOR then
		local freshness = GetDataFreshness()
		local coloredFreshness = GetColoredFreshness(freshness)
		dataText = L"AH Data: " .. coloredFreshness
	else
		dataText = L"AH Data: None"
	end
	if SummaryFrame.leftDataText then
		SummaryFrame.leftDataText:SetText(dataText)
	end
	if SummaryFrame.centerTitleText then
		SummaryFrame.centerTitleText:SetText(L"Patron Shopping Helper")
	end
	for _, orderInfo in ipairs(ui.orderList) do
		local hasPlayerReagents = false
		if orderInfo.recipeSchematic then
			for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
				if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
					hasPlayerReagents = true
					break
				end
			end
		end
		if hasPlayerReagents and (checkedOrders[orderInfo.orderID] == nil or checkedOrders[orderInfo.orderID]) then
			table.insert(filteredOrders, orderInfo)
		end
	end
	for _, orderInfo in ipairs(filteredOrders) do
		if checkedOrders[orderInfo.orderID] == nil then
			checkedOrders[orderInfo.orderID] = true
		end
	end
	local materialNeeds = {}
	local totalConcentration = 0
	for _, orderInfo in ipairs(filteredOrders) do
		if checkedOrders[orderInfo.orderID] then
			if orderInfo.recipeSchematic then
				for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
					if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
						local cheapestItemID, _, cheapestQuality = GetLowestCostReagentInfo(slot.reagents)
						if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and orderInfo and orderInfo._needsBetterMats then
							local best = DFPO_GetBestDisplayReagent(slot.reagents, orderInfo)
							if best and best.itemID then
								cheapestItemID = best.itemID
								cheapestQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(best.itemID) or 1
							end
						end
						if cheapestItemID then
							local requiredQuantity = slot.quantityRequired
							local need = requiredQuantity
							if need > 0 then
								if not materialNeeds[cheapestItemID] then
									materialNeeds[cheapestItemID] = {
										count = need,
										itemID = cheapestItemID,
										quality = cheapestQuality,
										reagents = slot.reagents
									}
								else
									materialNeeds[cheapestItemID].count = materialNeeds[cheapestItemID].count + need
								end
							end
						end
					end
				end
			end
			if orderInfo.concentrationCost and orderInfo.concentrationCost > 0 then
				totalConcentration = totalConcentration + orderInfo.concentrationCost
			end
		end
	end
	for itemID, _ in pairs(materialNeeds) do
		if lastBagCount[itemID] == nil then
			lastBagCount[itemID] = GetItemCount(itemID, true)
		end
	end
	for itemID, pendingCount in pairs(pendingPurchases) do
		local currentCount = GetItemCount(itemID, true)
		local lastCount = lastBagCount[itemID] or 0
		local delta = currentCount - lastCount
		if delta > 0 then
			local newPending = pendingCount - delta
			if newPending <= 0 then
				pendingPurchases[itemID] = nil
			else
				pendingPurchases[itemID] = newPending
			end
		end
		lastBagCount[itemID] = currentCount
	end
	for itemID, data in pairs(materialNeeds) do
		if itemID ~= -1 then
			local playerHas = GetReagentCount(itemID, data.quality)
			local pending = pendingPurchases[itemID] or 0
			playerHas = playerHas + pending
			data.count = math.max(0, data.count - playerHas)
			if data.count == 0 then
				materialNeeds[itemID] = nil
			end
		end
	end
	if totalConcentration > 0 then
		materialNeeds[-1] = {
			count = totalConcentration,
			itemID = -1,
			isConcentration = true,
		}
	end
	SummaryFrame.currentMaterialNeeds = materialNeeds
	if HAS_AUCTIONATOR and not InCombatLockdown() then
		if not filteredOrders then return end
		local tier2Items = {}
		for _, orderInfo in ipairs(filteredOrders) do
			if checkedOrders[orderInfo.orderID] then
				local schematic = orderInfo.recipeSchematic
				if schematic then
					for _, slot in ipairs(schematic.reagentSlotSchematics) do
						if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
							for _, reagent in ipairs(slot.reagents) do
								local itemID = reagent.itemID
								if itemID then
									local _, link = GetItemInfo(itemID)
									if link and link:find("Quality%-12%-Tier2") then
										tier2Items[itemID] = true
									end
								end
							end
						end
					end
				end
			end
		end
		local allHaveVendor = true
		for itemID, _ in pairs(tier2Items) do
			local vendorPrice = Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
			if not vendorPrice then
				allHaveVendor = false
				break
			end
		end
		if allHaveVendor and next(tier2Items) then
			if AUCTIONATOR_VENDOR_PRICE_CACHE then
				wipe(AUCTIONATOR_VENDOR_PRICE_CACHE)
			end
			SilentPrint(L"Msg_PriceContaminated")
		end
	end
	for i = #filteredOrders + 1, #rows do
		local row = rows[i]
		if row then
			row:Hide()
			row:ClearAllPoints()
		end
	end
	if not ui or not ui.orderList then
		return false
	end
	local orderCount = #filteredOrders
	if orderCount == 0 then
		return false
	end
	craftHeader.arrow:SetShown(ui.sortBy == 1)
	costHeader.arrow:SetShown(ui.sortBy == 2)
	rewardHeader.arrow:SetShown(ui.sortBy == 3)
	if ui.sortBy then
		craftHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
		costHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
		rewardHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
	end
	local rowHeight = 54
	local currentY = 0
	local claimedOrder = C_CraftingOrders.GetClaimedOrder()
	local claimedOrderID = claimedOrder and claimedOrder.orderID
	for i, orderInfo in ipairs(filteredOrders) do
		local row = rows[i]
		if not row then
			row = CreateSummaryOrderRow(content)
			rows[i] = row
		end
		if not row.checkMark then
			local checkMark = row:CreateTexture(nil, "OVERLAY")
			checkMark:SetSize(22, 22)
			checkMark:SetAtlas("transmog-icon-tick-small")
			checkMark:SetVertexColor(0, 1, 0)
			checkMark:Hide()
			row.checkMark = checkMark
			local checkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			checkText:SetText(L"Materials Ready")
			checkText:SetFont(GameFontNormal:GetFont(), 14)
			checkText:SetTextColor(0, 1, 0)
			checkText:Hide()
			row.checkMarkText = checkText
		end
	row.orderInfo = orderInfo
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -currentY)
		row:Show()
		local missing = IsOrderMissingReagents(orderInfo)
		local hasPlayerReagents = false
		if orderInfo.recipeSchematic then
			for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
				if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
					hasPlayerReagents = true
					break
				end
			end
		end
		if row.allReagentsText then
			row.allReagentsText:SetShown(not hasPlayerReagents)
		end
		local orderName = orderInfo.requestName
		local rei = orderInfo.recipeInfo
		local rs = ""
		local et = ""
		if not rei.learned then
			orderName = "|cffa0a0a0" .. orderName:gsub("|c%x%x%x%x%x%x%x%x", "") .. "|r"
			rs = "|A:transmog-icon-remove:12:12:|a"
			et = "|A:transmog-icon-remove:12:12:|a|cffe01010 " .. PROFESSIONS_CRAFTER_CANT_CLAIM_UNLEARNED
		elseif rei.firstCraft then
			rs = "|A:Professions_Icon_FirstTimeCraft:14:12:0:1|a"
			et = "|A:Professions_Icon_FirstTimeCraft:14:10:0:1|a " .. PROFESSIONS_FIRST_CRAFT
		end
		if DIFFICULTY_ATLAS[rei.relativeDifficulty] then
			local d, sk = rei.relativeDifficulty, rei.numSkillUps
			local showAll = true
			if rei.recipeID then
				local tradeSkillID = C_TradeSkillUI.GetTradeSkillLineForRecipe(rei.recipeID)
				if tradeSkillID then
					local skillInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(tradeSkillID)
					if skillInfo and skillInfo.skillLevel and skillInfo.maxSkillLevel
					   and skillInfo.skillLevel >= skillInfo.maxSkillLevel then
						showAll = false
					end
				end
			end
			if showAll then
				rs = rs .. "|A:" .. DIFFICULTY_ATLAS[d] .. ":13:13:|a"
				if (sk and sk > 1) then
					rs = rs .. DIFFICULTY_COLOR_CODE[d] .. sk .. "|r"
				end
			end
		end
		row.statusText:SetText(rs)
		if rs and rs ~= "" then
			local statusWidth = row.statusText:GetStringWidth() or 0
			row.nameText:SetPoint("TOPLEFT", row.statusText, "TOPRIGHT", 2, 0)
		else
			row.nameText:SetPoint("TOPLEFT", row.mainIcon.root, "TOPRIGHT", 4, 0)
		end
		if claimedOrderID and claimedOrderID == orderInfo.orderID then
			orderName = "|A:CampCollection-icon-star:14:14|a" .. orderName
		end
		row.nameText:SetText(orderName)
		confIconButton(row.mainIcon, orderInfo, nil, nil, et)
		local lastIcon = nil
		local slotIndex = 1
		if orderInfo.recipeSchematic then
			for j = 1, #row.reagents do
				if row.reagents[j] and row.reagents[j].root then
					row.reagents[j].root:Hide()
				end
			end
			local maxSlots = 8
			for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
				if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover and slotIndex <= maxSlots then
				local cheapestItemID, cheapestPrice, cheapestQuality = GetLowestCostReagentInfo(slot.reagents)
				if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and orderInfo and orderInfo._needsBetterMats then
					local bestReagent = DFPO_GetBestDisplayReagent(slot.reagents, orderInfo)
					if bestReagent and bestReagent.itemID ~= cheapestItemID then
						cheapestItemID = bestReagent.itemID
						cheapestQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(bestReagent.itemID) or 1
					end
				end
				if cheapestItemID then
						local requiredQuantity = slot.quantityRequired
						local playerHasQuantity = GetReagentCount(cheapestItemID, cheapestQuality)
						if playerHasQuantity < requiredQuantity then
							local reagentFrame = row.reagents[slotIndex]
							if not reagentFrame then
								reagentFrame = Acquire("IconButton", row)
								reagentFrame.root:SetSize(28, 28)
								reagentFrame.root:SetPoint("TOPLEFT", row.mainIcon.root, "TOPRIGHT", 4 + 30 * (slotIndex - 1), -18)
								row.reagents[slotIndex] = reagentFrame
							else
								reagentFrame.root:Show()
							end
							local reagentInfo = {itemID = cheapestItemID}
							confIconButton(reagentFrame, reagentInfo, slot.quantityRequired)
							local atlas = GetItemQualityAtlas(cheapestItemID)
							if atlas then
								if not reagentFrame.qualityTex then
									reagentFrame.qualityTex = reagentFrame.root:CreateTexture(nil, "OVERLAY")
									reagentFrame.qualityTex:SetSize(20, 20)
									reagentFrame.qualityTex:SetPoint("TOPLEFT", reagentFrame.root, "TOPLEFT", -5, 5)
								end
								reagentFrame.qualityTex:SetAtlas(atlas, false)
								reagentFrame.qualityTex:Show()
							elseif reagentFrame.qualityTex then
								reagentFrame.qualityTex:Hide()
							end
							if reagentFrame.count then
								reagentFrame.count:SetFont(reagentFrame.count:GetFont(), 14, "OUTLINE")
								reagentFrame.count:SetPoint("BOTTOMRIGHT", -2, 1)
								reagentFrame.count:SetText(requiredQuantity - playerHasQuantity)
								reagentFrame.count:SetTextColor(1, 0.15, 0)
							end
							if reagentFrame.icon then
								reagentFrame.icon:SetVertexColor(0.7, 0.7, 0.7)
							end
							reagentFrame.root:SetScript("OnEnter", function(self)
								GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
								if not slot.reagents or #slot.reagents == 0 then return end
								local allVersions = GetQualityVersionsFromReagents(slot.reagents)
								local firstReagent = slot.reagents[1]
								if firstReagent then
									local needToBuy = math.max(0, requiredQuantity - playerHasQuantity)
									local plainName = (select(2, GetItemInfo(cheapestItemID)) or L"Unknown Item"):gsub("%[", ""):gsub("%]", "")
									local hasVendorPrice = false
									local vendorPrice = 0
									if HAS_AUCTIONATOR and Auctionator.API.v1.GetVendorPriceByItemID and itemID and itemID > 0 then
										local vp = Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
										if vp and vp > 0 then
											hasVendorPrice = true
											vendorPrice = vp
										end
									end
									if hasVendorPrice then
										GameTooltip:SetText(L"Missing Materials (Vendor)")
										GameTooltip:AddLine(" ")
										GameTooltip:AddLine(string.format(L"Need to buy %d x %s", needToBuy, plainName), 1, 1, 1)
										GameTooltip:AddLine(string.format(L"Need %d total, you have %d", requiredQuantity, playerHasQuantity), 0.7, 0.7, 0.7)
										GameTooltip:AddLine(" ")
										GameTooltip:AddLine(string.format(L"NPC Price: %s", SafeGetMoneyString(vendorPrice, true)), 1, 1, 1)
										GameTooltip:Show()
										return
									end
									if #allVersions > 1 then
										GameTooltip:SetText(L"Missing Cheap Materials")
										GameTooltip:AddLine(" ")
										GameTooltip:AddLine(string.format(L"Current Rank %d is cheapest", cheapestQuality), 1, 1, 1)
										GameTooltip:AddLine(" ")
										local itemLink = select(2, GetItemInfo(cheapestItemID)) or L"Unknown Item"
										local plainName2 = itemLink:gsub("%[", ""):gsub("%]", "")
										GameTooltip:AddLine(string.format(L"Need to buy %d x %s", needToBuy, plainName2), 1, 1, 1)
										GameTooltip:AddLine(string.format(L"Need %d total, you have %d", requiredQuantity, playerHasQuantity), 0.7, 0.7, 0.7)
										GameTooltip:AddLine(" ")
										GameTooltip:AddLine(L"Current Price: ", 0.8, 0.8, 0.8)
										for _, version in ipairs(allVersions) do
											local price = CalculateItemValue(version.itemID) or 0
											local color = version.quality == cheapestQuality and "|cff00ff00" or "|cffffffff"
											local versionItemLink = select(2, GetItemInfo(version.itemID)) or string.format(L"Star Material", version.quality)
											local versionPlainName = versionItemLink:gsub("%[", ""):gsub("%]", "")
											local priceDisplay
											if price == 0 and not HAS_AUCTIONATOR then
												priceDisplay = L"Install Auctionator for prices"
											else
												priceDisplay = SafeGetMoneyString(price, true)
											end
											GameTooltip:AddDoubleLine(versionPlainName, priceDisplay, 1,1,1,1,1,1)
										end
									else
										GameTooltip:SetText(L"Missing Materials")
										GameTooltip:AddLine(" ")
										local itemLink = select(2, GetItemInfo(cheapestItemID)) or L"Unknown Item"
										local plainName2 = itemLink:gsub("%[", ""):gsub("%]", "")
										GameTooltip:AddLine(string.format(L"Need to buy %d x %s", needToBuy, plainName2), 1, 1, 1)
										GameTooltip:AddLine(string.format(L"Need %d total, you have %d", requiredQuantity, playerHasQuantity), 0.7, 0.7, 0.7)
										if cheapestPrice then
											GameTooltip:AddLine(" ")
											if cheapestPrice == 0 and not HAS_AUCTIONATOR then
												GameTooltip:AddLine(L"Current Price: " .. L"Install Auctionator for prices", 1, 1, 1)
											else
												GameTooltip:AddLine(string.format(L"Current Price: %s", SafeGetMoneyString(cheapestPrice, true)), 1,1,1)
											end
										end
									end
									GameTooltip:Show()
								end
							end)
							reagentFrame.root:SetScript("OnLeave", function()
								GameTooltip:Hide()
							end)
							lastIcon = reagentFrame.root
							slotIndex = slotIndex + 1
						end
					end
				end
			end
		end
		local concIcon = row.concentrationIcon
		if orderInfo.concentrationCost and orderInfo.concentrationCost > 0 then
			if not concIcon then
				concIcon = Acquire("IconButton", row)
				concIcon.root:SetSize(28, 28)
				row.concentrationIcon = concIcon
			else
				concIcon.root:Show()
			end
			concIcon.root:SetPoint("TOPLEFT", row.mainIcon.root, "TOPRIGHT", 4 + 30 * (slotIndex - 1), -18)
			concIcon.icon:SetTexture("Interface/ICONS/UI_Concentration")
			concIcon.icon:SetVertexColor(1, 1, 1)
			concIcon.border:SetAtlas(QUALITY_SLOT_ATLAS[1])
			if concIcon.count then
				concIcon.count:SetText(orderInfo.concentrationCost)
				concIcon.count:SetFont(GameFontNormal:GetFont(), 12, "OUTLINE")
				concIcon.count:SetTextColor(1, 1, 1)
			end
			concIcon.root:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(L"Needs Concentration")
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format(L"Need %d Concentration to qualify", orderInfo.concentrationCost))
				GameTooltip:Show()
			end)
			concIcon.root:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			lastIcon = concIcon.root
			slotIndex = slotIndex + 1
		else
			if concIcon then
				concIcon.root:Hide()
			end
		end
		if not missing then
			row.checkMark:Show()
			row.checkMarkText:Show()
			row.checkMark:ClearAllPoints()
			row.checkMarkText:ClearAllPoints()
			if lastIcon then
				row.checkMark:SetPoint("CENTER", lastIcon, "CENTER", 25, -3)
				row.checkMarkText:SetPoint("LEFT", row.checkMark, "RIGHT", 2, 0)
			else
				row.checkMark:SetPoint("LEFT", row.mainIcon.root, "RIGHT", 2, -15)
				row.checkMarkText:SetPoint("LEFT", row.checkMark, "RIGHT", 2, 0)
			end
		else
			row.checkMark:Hide()
			row.checkMarkText:Hide()
		end
		for j = 1, #row.rewards do
			if row.rewards[j] and row.rewards[j].root then
				row.rewards[j].root:Hide()
			end
		end
		local rewardIndex = 1
		for _, reward in ipairs(orderInfo.npcOrderRewards) do
			if rewardIndex <= 3 then
				local rewardFrame = row.rewards[rewardIndex]
				if not rewardFrame then
					rewardFrame = Acquire("IconButton", row)
					rewardFrame.root:SetSize(28, 28)
					local rewardColumnStart = SUMMARY_ORDER_COLUMN_WIDTH + SUMMARY_COST_COLUMN_WIDTH
					rewardFrame.root:SetPoint("TOPLEFT", row, "TOPLEFT", rewardColumnStart + 5 + 25 * (rewardIndex - 1), -18)
					row.rewards[rewardIndex] = rewardFrame
				else
					rewardFrame.root:Show()
				end
				confIconButton(rewardFrame, reward, reward.count)
				rewardIndex = rewardIndex + 1
			end
		end
		if row.costText then
			if orderInfo.craftingCost and orderInfo.rewardTotalValue then
				if orderInfo.hasUnknownCost then
					row.costText:SetText(L"Unknown|r")
				else
					local profit = orderInfo.rewardTotalValue - orderInfo.craftingCost
					local colorCode = profit >= 0 and "|cff00ff00" or "|cffff0000"
					local profitWithoutCopper = math.floor(profit / 10000 + 0.5) * 10000
					local profitString = SafeGetMoneyString(math.abs(profitWithoutCopper), true)
					if profit >= 0 then
						row.costText:SetText(colorCode .. profitString .. "|r")
					else
						row.costText:SetText(colorCode .. "-" .. profitString .. "|r")
					end
				end
				row.costText:SetScript("OnEnter", function(self)
					if orderInfo.hasUnknownCost then
						GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
						GameTooltip:SetText(L"Cost Unknown")
						GameTooltip:Show()
					else
						local profit = orderInfo.rewardTotalValue - orderInfo.craftingCost
						local profitColor = profit >= 0 and "|cff00ff00" or "|cffff0000"
						local totalRewardStr = SafeGetMoneyString(orderInfo.rewardTotalValue, true)
						local costStr = SafeGetMoneyString(orderInfo.craftingCost, true)
						local profitStr = SafeGetMoneyString(math.abs(profit), true)
						GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
						GameTooltip:AddLine(L"Estimated Profit")
						GameTooltip:AddLine(" ")
						GameTooltip:AddDoubleLine(L"Total Reward:", totalRewardStr, 1, 1, 1, 1, 1, 1)
						GameTooltip:AddDoubleLine(L"Material Cost:", costStr, 1, 1, 1, 1, 1, 1)
						GameTooltip:AddLine("——————————————")
						if profit < 0 then
							GameTooltip:AddDoubleLine(L"Estimated Profit:", profitColor .. "-" .. profitStr .. "|r", 1, 1, 1, 1, 1, 1)
						else
							GameTooltip:AddDoubleLine(L"Estimated Profit:", profitColor .. profitStr .. "|r", 1, 1, 1, 1, 1, 1)
						end
						GameTooltip:Show()
					end
				end)
				row.costText:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)
			else
				row.costText:SetText("")
			end
		end
		if row.rewardText then
			local goldReward = orderInfo.tipAmount - (orderInfo.consortiumCut or 0)
			if goldReward > 0 then
				row.rewardText:SetText(FormatGoldString(goldReward))
			else
				row.rewardText:SetText("")
			end
		end
		if row.bg then
			row.bg:SetShown(i % 2 == 0)
		end
		currentY = currentY + rowHeight
	end
	content:SetHeight(currentY)
	if currentY > scrollFrame:GetHeight() then
		local maxValue = currentY - scrollFrame:GetHeight()
		scrollBar:SetMinMaxValues(0, maxValue)
		local newValue = math.min(savedScrollValue, maxValue)
		scrollBar:SetValue(newValue)
		scrollBar:Show()
		scrollBar:SetScript("OnValueChanged", function(self, value)
			content:SetPoint("TOPLEFT", 0, value)
			content:SetPoint("TOPRIGHT", 0, value)
		end)
		content:SetPoint("TOPLEFT", 0, newValue)
		content:SetPoint("TOPRIGHT", 0, newValue)
	else
		scrollBar:Hide()
	end
	local container = SummaryFrame.materialsContainer
	local contentContainer = SummaryFrame.materialsContainer.contentContainer
	local layout = SummaryFrame.materialsLayout
	if next(materialNeeds) then
		for _, icon in ipairs(SummaryFrame.summaryMaterialsIcons) do
			if icon and icon.root then
				Release("IconButton", icon.root)
			end
		end
		table.wipe(SummaryFrame.summaryMaterialsIcons)
		local container = SummaryFrame.materialsContainer
		local layout = SummaryFrame.materialsLayout
		if not layout then
			layout = CreateFrame("Frame", nil, container)
			layout:SetPoint("TOPLEFT", container.titleText, "TOPLEFT", 0, 0)
			layout:SetPoint("RIGHT", -3, 0)
			layout:SetHeight(30)
			SummaryFrame.materialsLayout = layout
		else
			layout:ClearAllPoints()
			layout:SetPoint("TOPLEFT", container.titleText, "TOPLEFT", 0, 0)
			layout:SetPoint("RIGHT", -3, 0)
		end
		local iconSize = 36
		local spacing = 2
		local leftMargin = 8
		local rightMargin = 5
		local containerWidth = container:GetWidth()
		local titleWidth = container.titleText:GetStringWidth() or 50
		local firstRowAvailable = containerWidth - titleWidth - leftMargin - rightMargin - spacing
		local secondRowAvailable = containerWidth - leftMargin - rightMargin
		if firstRowAvailable < 50 then firstRowAvailable = 300 end
		if secondRowAvailable < 50 then secondRowAvailable = 300 end
		local maxIconsRow1 = math.floor(firstRowAvailable / (iconSize + spacing))
		local maxIconsRow2 = math.floor(secondRowAvailable / (iconSize + spacing))
		if maxIconsRow1 < 1 then maxIconsRow1 = 1 end
		if maxIconsRow2 < 1 then maxIconsRow2 = 1 end
		local maxRows = 2
		local maxIconsToShow = maxIconsRow1 + maxIconsRow2
		local sortedEntries = {}
		for itemID, data in pairs(materialNeeds) do
			table.insert(sortedEntries, {itemID = itemID, data = data})
		end
		table.sort(sortedEntries, function(a, b)
			if a.itemID == -1 then return true end
			if b.itemID == -1 then return false end
			return a.itemID < b.itemID
		end)
		local totalCount = #sortedEntries
		local extraCount = totalCount - maxIconsToShow
		if extraCount < 0 then extraCount = 0 end
		local visibleEntries = {}
		for i = 1, math.min(totalCount, maxIconsToShow) do
			table.insert(visibleEntries, sortedEntries[i])
		end
		local xOffset, yOffset = 0, 5
		local rowIndex = 1
		local colIndex = 0
		local currentRowMaxIcons = maxIconsRow1
		for idx, entry in ipairs(visibleEntries) do
			if colIndex >= currentRowMaxIcons then
				rowIndex = rowIndex + 1
				colIndex = 0
				if rowIndex == 2 then
					currentRowMaxIcons = maxIconsRow2
					xOffset = math.max(0, leftMargin - 8)
				else
					break
				end
				yOffset = yOffset - (iconSize + spacing)
			end
			if rowIndex == 1 and colIndex == 0 then
				xOffset = titleWidth + leftMargin + spacing
			end
			local itemID = entry.itemID
			local data = entry.data
			local icon = Acquire("IconButton", layout)
			icon.root:SetSize(iconSize, iconSize)
			icon.root:ClearAllPoints()
			icon.root:SetPoint("TOPLEFT", layout, "TOPLEFT", xOffset, yOffset)
			if data.isConcentration then
				icon.icon:SetTexture("Interface/ICONS/UI_Concentration")
				icon.icon:SetVertexColor(1, 1, 1)
				icon.border:SetAtlas(QUALITY_SLOT_ATLAS[1], true)
				if icon.count then
					icon.count:SetText(data.count)
					icon.count:SetTextColor(1, 1, 1)
				end
				if icon.qualityTex then icon.qualityTex:Hide() end
				icon.root:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(L"Concentration")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine(string.format(L"Total Concentration needed: %d", data.count))
					GameTooltip:Show()
				end)
			else
				confIconButton(icon, {itemID = itemID}, data.count)
				if icon.count then
					icon.count:SetText(data.count)
					icon.count:SetTextColor(1, 1, 1)
					icon.count:Show()
				end
				local atlas = GetItemQualityAtlas(itemID)
				if atlas then
					if not icon.qualityTex then
						icon.qualityTex = icon.root:CreateTexture(nil, "OVERLAY")
						icon.qualityTex:SetSize(20, 20)
						icon.qualityTex:SetPoint("TOPLEFT", icon.root, "TOPLEFT", -3, 3)
					end
					icon.qualityTex:SetAtlas(atlas, false)
					icon.qualityTex:Show()
				elseif icon.qualityTex then
					icon.qualityTex:Hide()
				end
				icon.root:SetScript("OnEnter", function(self)
					local itemName = C_Item.GetItemInfo(itemID) or L"Unknown Item"
					local reagents = data.reagents
					if not reagents then
						reagents = { { itemID = itemID } }
					end
					local allVersions = GetQualityVersionsFromReagents(reagents)

					local cheapestItemID, cheapestPrice, cheapestQuality
					cheapestPrice = math.huge
					for _, ver in ipairs(allVersions) do
						local price = CalculateItemValue(ver.itemID) or 0
						if price > 0 and price < cheapestPrice then
							cheapestPrice = price
							cheapestItemID = ver.itemID
							cheapestQuality = ver.quality
						end
					end
					if cheapestPrice == math.huge then
						cheapestItemID = allVersions[1].itemID
						cheapestQuality = allVersions[1].quality
						cheapestPrice = 0
					end
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText(itemName)
					GameTooltip:AddLine(" ")
					local hasVendorPrice = false
					local vendorPrice = 0
					if HAS_AUCTIONATOR and Auctionator.API.v1.GetVendorPriceByItemID and itemID and itemID > 0 then
						local vp = Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
						if vp and vp > 0 then
							hasVendorPrice = true
							vendorPrice = vp
						end
					end
					if hasVendorPrice then
						GameTooltip:AddLine(L"Missing Materials (Vendor)")
						GameTooltip:AddLine(" ")
						GameTooltip:AddLine(string.format(L"Need to buy %d x %s", data.count, itemName), 1, 1, 1)
						GameTooltip:AddLine(string.format(L"NPC Price: %s", SafeGetMoneyString(vendorPrice, true)), 1, 1, 1)
						GameTooltip:Show()
						return
					end
					local playerHas = GetReagentCount(cheapestItemID, cheapestQuality)
					if #allVersions > 1 then
						GameTooltip:AddLine(string.format(L"Current Rank %d is cheapest", cheapestQuality))
						GameTooltip:AddLine(" ")
						GameTooltip:AddLine(string.format(L"Need to buy %d x %s", data.count, itemName), 1, 1, 1)
						GameTooltip:AddLine(string.format(L"Currently have %d", playerHas), 0.7, 0.7, 0.7)
						GameTooltip:AddLine(" ")
						GameTooltip:AddLine(L"Current Price: ", 0.8, 0.8, 0.8)
						for _, version in ipairs(allVersions) do
							local price = CalculateItemValue(version.itemID) or 0
							local versionName = select(2, GetItemInfo(version.itemID)) or string.format(L"Star Material", version.quality)
							local priceDisplay = (price == 0 and not HAS_AUCTIONATOR) and L"Install Auctionator for prices" or SafeGetMoneyString(price, true)
							GameTooltip:AddDoubleLine(versionName, priceDisplay, 1, 1, 1, 1, 1, 1)
						end
					else
						GameTooltip:AddLine(L"Missing Materials")
						GameTooltip:AddLine(" ")
						GameTooltip:AddLine(string.format(L"Need to buy %d x %s", data.count, itemName), 1, 1, 1)
						GameTooltip:AddLine(string.format(L"Currently have %d", playerHas), 0.7, 0.7, 0.7)
						if cheapestPrice then
							GameTooltip:AddLine(" ")
							if cheapestPrice == 0 and not HAS_AUCTIONATOR then
								GameTooltip:AddLine(L"Current Price: " .. L"Install Auctionator for prices", 1, 1, 1)
							else
								GameTooltip:AddLine(string.format(L"Current Price: %s", SafeGetMoneyString(cheapestPrice, true)), 1, 1, 1)
							end
						end
					end
					GameTooltip:Show()
				end)
			end
			icon.root:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			table.insert(SummaryFrame.summaryMaterialsIcons, icon)
			colIndex = colIndex + 1
			xOffset = xOffset + iconSize + spacing
		end
		local actualRows = rowIndex
		local contentHeight = actualRows * (iconSize + spacing)
		layout:SetHeight(contentHeight)
		container:SetHeight(contentHeight + 10)
		container:Show()
	else
		SummaryFrame.materialsContainer:Hide()
		if SummaryFrame.materialsContainer.moreText then
			SummaryFrame.materialsContainer.moreText:Hide()
		end
	end
	if AuctionHouseFrame and AuctionHouseFrame:IsShown() and not lastMaterialNeedsSnapshot then
		lastMaterialNeedsSnapshot = CopyNeeds(SummaryFrame.currentMaterialNeeds)
	end
	return true
end

function ShowSummaryWindow()
	if not SummaryFrame then return false end
	local pos = DFCN_PatronOffersDB and DFCN_PatronOffersDB.summaryFramePosition
	local success = false
	if pos and type(pos) == "table" then
		local point, relativeToName, relativePoint, xOfs, yOfs = unpack(pos)
		local relativeTo = UIParent
		if type(relativeToName) == "string" then
			local frame = _G[relativeToName]
			if frame and frame.GetObjectType and frame:GetObjectType() == "Frame" then
				relativeTo = frame
			end
		end
		if point == "LEFT" and relativePoint == "LEFT" and xOfs < 0 then
			xOfs = 0
		end
		SummaryFrame:ClearAllPoints()
		success = pcall(SummaryFrame.SetPoint, SummaryFrame, point, relativeTo, relativePoint, xOfs, yOfs)
	end
	if not success then
		SummaryFrame:ClearAllPoints()
		SummaryFrame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
	end
	if T.UpdateSummaryWindow() then
		if scrollBar then scrollBar:SetValue(0) end
		if SummaryFrame.lockBtn then
			if DFCN_PatronOffersDB.summaryFrameLocked then
				SummaryFrame.lockBtn.text:SetTextColor(1, 0.2, 0.2)
				SummaryFrame.lockBtn.text:SetText("L")
			else
				SummaryFrame.lockBtn.text:SetTextColor(0.2, 1, 0.2)
				SummaryFrame.lockBtn.text:SetText("U")
			end
		end
		SummaryFrame:Show()
		return true
	else
		SummaryFrame:Hide()
		return false
	end
end

function ui.cycleSortOrder(hid, reverse)
	if ui.sortBy ~= hid then
		ui.sortBy, ui.sortAsc = hid, not reverse
	elseif ui.sortAsc ~= reverse then
		ui.sortAsc = reverse
	else
		ui.sortBy = nil
	end
	if ui.sortBy and ui.sortArrow then
		ui.sortArrow:SetParent(ui.headers[ui.sortBy])
		ui.sortArrow:ClearAllPoints()
		ui.sortArrow:SetPoint("LEFT", ui.headers[ui.sortBy]:GetFontString(), "RIGHT", 3, 0)
		ui.sortArrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
	end
	if ui.sortArrow then
		ui.sortArrow:SetShown(not not ui.sortBy)
	end
	if craftHeader.arrow then
		craftHeader.arrow:SetShown(ui.sortBy == 1)
	end
	if costHeader.arrow then
		costHeader.arrow:SetShown(ui.sortBy == 2)
	end
	if rewardHeader.arrow then
		rewardHeader.arrow:SetShown(ui.sortBy == 3)
	end
	if ui.sortBy then
		if craftHeader.arrow then
			craftHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 1 or 0, ui.sortAsc and 0 or 1)
		end
		if costHeader.arrow then
			costHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 0 or 1, ui.sortAsc and 1 or 0)
		end
		if rewardHeader.arrow then
			rewardHeader.arrow:SetTexCoord(0, 1, ui.sortAsc and 0 or 1, ui.sortAsc and 1 or 0)
		end
	end
	confOrderList(ui.orderList, "sort")
	if SummaryFrame and SummaryFrame:IsShown() then
		T.UpdateSummaryWindow()
	end
end

SummaryFrame:RegisterEvent("BAG_UPDATE_DELAYED")
SummaryFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
SummaryFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "BAG_UPDATE_DELAYED" then
		if self.autoUseTimer then
			self.autoUseTimer:Cancel()
			self.autoUseTimer = nil
		end
		local function TryAutoUse()
			if not DFCN_PatronOffersDB.autoOpenRewardItems then return end
			if UnitCastingInfo("player") or UnitChannelInfo("player") then
				if not self.autoUseRetryTimer then
					self.autoUseRetryTimer = C_Timer.NewTimer(1, function()
						self.autoUseRetryTimer = nil
						TryAutoUse()
					end)
				end
				return
			end
			if self.autoUseRetryTimer then
				self.autoUseRetryTimer:Cancel()
				self.autoUseRetryTimer = nil
			end
			local autoUseItems = {246585, 227713}
			local now = GetTime()
			if self.lastAutoUseTime and now - self.lastAutoUseTime <= 0.5 then return end
			local hasLockedItem = false
			for checkBag = 0, NUM_BAG_SLOTS do
				for checkSlot = 1, C_Container.GetContainerNumSlots(checkBag) do
					local itemInfo = C_Container.GetContainerItemInfo(checkBag, checkSlot)
					if itemInfo and itemInfo.isLocked then
						hasLockedItem = true
						break
					end
				end
				if hasLockedItem then break end
			end
			if hasLockedItem then return end
			local inInstance = IsInInstance()
			if not inInstance then
				local used = false
				for bag = 0, NUM_BAG_SLOTS do
					for slot = 1, C_Container.GetContainerNumSlots(bag) do
						local itemID = C_Container.GetContainerItemID(bag, slot)
						for _, targetID in ipairs(autoUseItems) do
							if itemID == targetID then
								if InCombatLockdown() then break end
								local hasFreeSlot = false
								for checkBag = 0, NUM_BAG_SLOTS do
									local freeSlots = C_Container.GetContainerNumFreeSlots(checkBag)
									if freeSlots and freeSlots > 0 then
										hasFreeSlot = true
										break
									end
								end
								local itemLink = select(2, C_Item.GetItemInfo(targetID)) or ('|Hitem:' .. targetID .. '|h' .. L'[Item]' .. '|h')
								local iconPath = select(10, C_Item.GetItemInfo(targetID))
								local itemIconTag = iconPath and ("|T" .. iconPath .. ":14:14|t") or ""
								if hasFreeSlot then
									if (not C_Bank or not C_Bank.AreAnyBankTypesViewable())
										and (not GuildBankFrame or not GuildBankFrame:IsVisible())
										and not MerchantFrame:IsVisible() then
										C_Container.UseContainerItem(bag, slot)
										SilentPrint(L"Msg_OpenRewardItem" .. itemIconTag .. itemLink)
									end
								else
									SilentPrint(L"Msg_BagFull" .. itemIconTag .. itemLink)
								end
								self.lastAutoUseTime = now
								used = true
								break
							end
						end
						if used then break end
					end
					if used then break end
				end
			end
		end
		self.autoUseTimer = C_Timer.NewTimer(1, function()
			self.autoUseTimer = nil
			TryAutoUse()
		end)
		if self:IsShown() then
			T.UpdateSummaryWindow()
		end
	elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
		ahReadySince = GetTime()
		if reselectTimer then
			reselectTimer:Cancel()
		end
		reselectTimer = C_Timer.NewTimer(1.1, function()
			reselectTimer = nil
			if not (SummaryFrame and SummaryFrame:IsShown()) then return end
			local backup = ui.fullOrderBackup
			if not backup or #backup == 0 then
				if ui.orderList then
					for _, order in ipairs(ui.orderList) do
						if order.recipeSchematic then
							local cost, hasUnknown = CalculateReagentsTotal(order.recipeSchematic)
							order.craftingCost = cost
							order.hasUnknownCost = hasUnknown
							if order.rewardTotalValue then
								order.profit = order.rewardTotalValue - cost
							end
							if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and order.ignorePriceDiffConcentrationCost ~= nil
								and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
								local newCost = 0
								for _, slot in ipairs(order.recipeSchematic.reagentSlotSchematics) do
									if slot.required and not slot.cover and slot.reagents then
										local best = DFPO_GetBestDisplayReagent(slot.reagents, order)
										if best and best.itemID then
											local p = CalculateItemValue(best.itemID) or 0
											newCost = newCost + p * slot.quantityRequired
										end
									end
								end
								order.craftingCost = newCost
								order.hasUnknownCost = false
								if order.rewardTotalValue then
									order.profit = order.rewardTotalValue - newCost
								end
							end
						end
					end
					T.UpdateSummaryWindow()
				end
			else
				for _, order in ipairs(backup) do
					local gold = (order.tipAmount or 0) - (order.consortiumCut or 0)
					local itemRewardValue = 0
					if order.npcOrderRewards then
						for _, reward in ipairs(order.npcOrderRewards) do
							if reward and reward.itemLink then
								local itemID = tonumber(reward.itemLink:match("item:(%d+)"))
								if itemID then
									itemRewardValue = itemRewardValue + CalculateItemValue(itemID) * (reward.count or 1)
								end
							end
						end
					end
					order.rewardTotalValue = gold + itemRewardValue
					if order.recipeSchematic then
						local cost, hasUnknown = CalculateReagentsTotal(order.recipeSchematic)
						order.craftingCost = cost
						order.hasUnknownCost = hasUnknown
						if order.rewardTotalValue then
							order.profit = order.rewardTotalValue - cost
						end
						if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and order.ignorePriceDiffConcentrationCost ~= nil
							and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
							local newCost = 0
							for _, slot in ipairs(order.recipeSchematic.reagentSlotSchematics) do
								if slot.required and not slot.cover and slot.reagents then
									local best = DFPO_GetBestDisplayReagent(slot.reagents, order)
									if best and best.itemID then
										local p = CalculateItemValue(best.itemID) or 0
										newCost = newCost + p * slot.quantityRequired
									end
								end
							end
							order.craftingCost = newCost
							order.hasUnknownCost = false
							if order.rewardTotalValue then
								order.profit = order.rewardTotalValue - newCost
							end
						end
					else
						order.craftingCost, order.hasUnknownCost = 0, true
						order.profit = order.rewardTotalValue
					end
				end
				local activeFilters = ui.lastActiveFilters or DFCN_PatronOffersDB.filters
				local filteredOA = {}
				for _, order in ipairs(backup) do
					local learned = order.recipeInfo and order.recipeInfo.learned
					local shouldDisable = false
					if activeFilters.unlearned and not learned then
						shouldDisable = true
					end
					if activeFilters.needFocus then
						local effConc = order.concentrationCost or 0
						if DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff and order.ignorePriceDiffConcentrationCost ~= nil
							and (order.lameConcentrationCost == nil or order.lameConcentrationCost > 0) then
							effConc = order.ignorePriceDiffConcentrationCost
						end
						if effConc > 0 then
							shouldDisable = true
						end
					end
					if activeFilters.profitBelow and order.profit and order.profit < (activeFilters.profitThreshold or 0) then
						shouldDisable = true
					end
					if not activeFilters.showFilteredOrders then
						if not shouldDisable then
							table.insert(filteredOA, order)
						end
					else
						if order.orderID and checkedOrders[order.orderID] == nil then
							checkedOrders[order.orderID] = not shouldDisable
						end
						table.insert(filteredOA, order)
					end
				end
				ui.orderList = sortOrders(filteredOA)
				T.UpdateSummaryWindow()
			end
			local currentNeeds = SummaryFrame.currentMaterialNeeds
			if not currentNeeds or next(currentNeeds) == nil then return end
			local oldNeeds = lastMaterialNeedsSnapshot
			if oldNeeds then
				local needRescan = false
				for itemID, curData in pairs(currentNeeds) do
					local oldData = oldNeeds[itemID]
					local curCount = curData.count or 0
					if not oldData then
						needRescan = true
						break
					end
					local oldCount = oldData.count or 0
					if curCount > oldCount then
						needRescan = true
						break
					elseif curCount < oldCount then
						local oldPending = (oldNeeds._pending and oldNeeds._pending[itemID]) or 0
						local newPending = pendingPurchases[itemID] or 0
						if curCount + (newPending - oldPending) < oldCount then
							needRescan = true
							break
						end
					end
				end
				if not needRescan then
					for itemID, oldData in pairs(oldNeeds) do
						if type(itemID) == "number" and not currentNeeds[itemID] then
							local oldCount = oldData.count or 0
							if oldCount > 0 then
								local oldPending = (oldNeeds._pending and oldNeeds._pending[itemID]) or 0
								local newPending = pendingPurchases[itemID] or 0
								if oldCount > (newPending - oldPending) then
									needRescan = true
									break
								end
							end
						end
					end
				end
				if needRescan then
					SilentPrint(L"Msg_RescanTriggered")
					lastMaterialNeedsSnapshot = CopyNeeds(currentNeeds)
					if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
						local function tryRescan()
							if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
								if GetTime() - ahReadySince >= 1 then
									PerformOneClickShopping()
								else
									C_Timer.After(0.5, tryRescan)
								end
							end
						end
						C_Timer.After(0.3, tryRescan)
					end
				else
					lastMaterialNeedsSnapshot = CopyNeeds(currentNeeds)
				end
			else
				lastMaterialNeedsSnapshot = CopyNeeds(currentNeeds)
			end
		end)
		if AuctionatorShoppingFrame and AuctionatorShoppingFrame:IsShown() then
			C_Timer.After(0, function()
				if ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage:IsShown() then
					local recipeList = ProfessionsFrame.CraftingPage.RecipeList
					if recipeList then
						local searchBox = recipeList.SearchBox
						if searchBox then
							local selectedRecipeID = recipeList.previousRecipeID
							SearchBoxTemplate_ClearText(searchBox)
							if selectedRecipeID then
								C_Timer.After(0, function()
									local scrollBox = recipeList.ScrollBox
									if scrollBox then
										local foundNode = nil
										scrollBox:ForEachElementData(function(node)
											if not foundNode then
												local data = node:GetData()
												if data and data.recipeInfo and data.recipeInfo.recipeID == selectedRecipeID then
													foundNode = node
												end
											end
										end)
										if foundNode then
											local selectionBehavior = recipeList.selectionBehavior
											if selectionBehavior and selectionBehavior.SelectElementData then
												selectionBehavior:SelectElementData(foundNode)
											end
											if scrollBox.ScrollToElementData then
												scrollBox:ScrollToElementData(foundNode)
											end
										end
									end
								end)
							end
						end
					end
				end
			end)
		end
	end
end)

local function updateSummaryVisibility()
	if ui.manualSummaryOpen then
		if (not ui.orderList or #ui.orderList == 0) and orderListBackup then
			ui.orderList = CopyTable(orderListBackup)
		end
		if ui.orderList and #ui.orderList > 0 then
			ShowSummaryWindow()
		else
			if SummaryFrame then SummaryFrame:Hide() end
		end
		return
	end
	if not ui or not ui.autoShowSummary then
		if SummaryFrame then SummaryFrame:Hide() end
		return
	end
	if ProfessionsFrame:IsShown() then
		if SummaryFrame then SummaryFrame:Hide() end
		return
	end
	if (not ui or not ui.orderList or #ui.orderList == 0) and orderListBackup then
		ui.orderList = CopyTable(orderListBackup)
		if SummaryFrame and SummaryFrame:IsShown() then
			T.UpdateSummaryWindow()
		end
	end
	if not ui or not ui.orderList or #ui.orderList == 0 then
		if SummaryFrame then SummaryFrame:Hide() end
		return
	end
	ShowSummaryWindow()
end

local function setupHooks()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", function()
		if not DFCN_PatronOffersDB.autoSwitchActionBar then return end
		C_Timer.After(0.1, function()
			local searchBox = ProfessionsFrame.CraftingPage.RecipeList.SearchBox
			if searchBox then
				SearchBoxTemplate_ClearText(searchBox)
			end
			local dropdown = ProfessionsFrame.CraftingPage.RecipeList.FilterDropdown
			if dropdown and dropdown.ResetButton then
				dropdown.ResetButton:Click()
			end
		end)
	end)
	ProfessionsFrame.OrdersPage:HookScript("OnShow", function()
		if ui and ui.orderList and #ui.orderList > 0 then
			local success, result = pcall(CopyTable, ui.orderList)
			if success then
				orderListBackup = result
			else
				orderListBackup = nil
			end
		end
	end)
	local currentOrders = C_CraftingOrders.GetCrafterOrders()
	if currentOrders then
		local hasGuest = false
		for _, o in ipairs(currentOrders) do
			if o.orderType == 3 then hasGuest = true; break end
		end
		if not hasGuest then
			ui.orderList = {}
			ui.fullOrderBackup = {}
			SummaryFrame.currentMaterialNeeds = nil
			SummaryFrame:Hide()
		end
	end
	ProfessionsFrame:HookScript("OnHide", updateSummaryVisibility)
	hooksecurefunc(ProfessionsFrame, "Show", function()
		C_Timer.After(0.2, function()
			local tabSystem = ProfessionsFrame.TabSystem
			local selectedTabID = tabSystem and tabSystem.selectedTabID
			if selectedTabID == ProfessionsFrame.craftingOrdersTabID then
				SwitchActionBarIfNeeded()
			end
		end)
	end)
	hooksecurefunc(ProfessionsFrame, "Hide", function()
		if not DFCN_PatronOffersDB.autoSwitchActionBar then return end
		if InCombatLockdown() then return end
		local tabSystem = ProfessionsFrame.TabSystem
		local tabID = ProfessionsFrame.craftingOrdersTabID
		if not tabSystem or not tabID then return end
		if tabSystem.selectedTabID == tabID then ChangeActionBarPage(1) end
	end)
	hooksecurefunc(ProfessionsFrame.OrdersPage, "SetCraftingOrderType", function(_, ot)
		local isCustomer = (ot == 3 and not IsModifiedClick("ALT-SHIFT-BOOM"))
		local bshow, bf = not isCustomer, ProfessionsFrame.OrdersPage.BrowseFrame
		bf.OrderList:SetShown(bshow)
		bf.SearchButton:SetShown(bshow)
		bf.FavoritesSearchButton:SetShown(bshow)
		if isCustomer then
			SwitchActionBarIfNeeded()
		end
		ui.root:SetShown(isCustomer)
		if not isCustomer then
			updateSummaryVisibility()
		else
			if SummaryFrame and not ui.manualSummaryOpen then
				SummaryFrame:Hide()
			end
		end
	end)
	local publicOrdersRefreshed = false
	local function SetupPublicOrderRefresh()
		local function ScheduleRefresh(self)
			if not self or type(self.RequestOrders) ~= "function" then return end
			C_Timer.NewTimer(0, function()
				if not publicOrdersRefreshed and not InCombatLockdown() and self.orderType == 0 then
					self:RequestOrders(nil, false, false)
					publicOrdersRefreshed = true
				end
			end)
		end
		hooksecurefunc(ProfessionsFrame.OrdersPage, "SetCraftingOrderType", function(self, orderType)
			if orderType == 0 then
				publicOrdersRefreshed = false
				ScheduleRefresh(self)
			else
				publicOrdersRefreshed = false
			end
		end)
		ProfessionsFrame.OrdersPage:HookScript("OnShow", function(self)
			if self.orderType == 0 then
				publicOrdersRefreshed = false
				ScheduleRefresh(self)
			end
		end)
	end
	EventRegistry:RegisterCallback("Professions.TransactionUpdated", UpdateOrderMultiButtonVisibility)
	local orderView = ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView
	if orderView then
		hooksecurefunc(orderView, "SetOrder", function(self, order)
			UpdateOrderMultiButtonVisibility()
		end)
	end
	SetupPublicOrderRefresh()
end

C_Timer.After(1, function()
	setupHooks()
	C_Timer.After(3, function()
		updateSummaryVisibility()
	end)
end)

do
	local dfpoToolSetupDone = false
	local function StatName(st)
		local names = {P = ITEM_MOD_MULTICRAFT_SHORT, R = ITEM_MOD_RESOURCEFULNESS_SHORT, I = ITEM_MOD_INGENUITY_SHORT}
		return (st == "P" and "|cff66DD66" or st == "I" and "|cff9966EE" or "|cff66AAEE") .. (names[st] or names.R) .. "|r"
	end
	ProfessionsFrame:HookScript("OnShow", function()
		local sf = ProfessionsFrame.CraftingPage.SchematicForm
		if sf and sf.Init and not sf.dfpoHooked then
			hooksecurefunc(sf, "Init", function(self, recipeInfo, ...)
				if InCombatLockdown() then return end
				if not DFCN_PatronOffersDB.enableRecipeToolSwitch then
					if self.dfpoToolCB then self.dfpoToolCB:Hide() self.dfpoToolVal:Hide() end if self.dfpoAutoText then self.dfpoAutoText:Hide() end
					return
				end
				if not recipeInfo or not recipeInfo.recipeID then
					if self.dfpoToolCB then self.dfpoToolCB:Hide() self.dfpoToolVal:Hide() end
					return
				end
				local recipeID = recipeInfo.recipeID
				local cp = C_TradeSkillUI.GetProfessionChildSkillLineID()
				if cp and not (PROFESSION_TOOLS_BY_ID[cp] or PROFESSION_TOOLS_BY_ID[UPGRADE_PROF_MAP[cp]]) then
					if self.dfpoToolCB then self.dfpoToolCB:Hide() self.dfpoToolVal:Hide() end
					if self.dfpoAutoText then self.dfpoAutoText:Hide() end
					return
				end
				if not DFCN_PatronOffersDB.recipeToolPref then DFCN_PatronOffersDB.recipeToolPref = {} end
				if not self.dfpoToolCB then
					local trackCB = self.TrackRecipeCheckbox
					if not trackCB then return end
					if not trackCB:IsShown() then
						local isSalvage = self.recipeSchematic and self.recipeSchematic.recipeType == Enum.TradeskillRecipeType.Salvage
						if not isSalvage then return end
					end
					local cb = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
					cb:SetSize(24, 24)
					local autoText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
					autoText:SetText(L"Auto Tool")
					local valText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
					valText:SetPoint("RIGHT", self, "RIGHT", -20, 0)
					valText:SetPoint("TOP", self, "TOPRIGHT", -13, -102)
					autoText:SetPoint("RIGHT", valText, "LEFT", -4, 0)
					cb:SetPoint("RIGHT", autoText, "LEFT", 2, 0)
					valText:SetText(L"Disabled")
					valText:EnableMouse(true)
					SkinElvUI(cb)
					cb:SetScript("OnClick", function(cbSelf)
						local ri = self:GetRecipeInfo()
						if not ri then return end
						if cbSelf:GetChecked() then
							local p = DFCN_PatronOffersDB.recipeToolPref[ri.recipeID] or {}
							p.enabled = true
							if not p.stat then p.stat = "R" end
							DFCN_PatronOffersDB.recipeToolPref[ri.recipeID] = p
							EquipBestProficiencyTool(p.stat, true)
							if self.dfpoToolVal then
								self.dfpoToolVal:SetText(StatName(p.stat))
							end
						else
							DFCN_PatronOffersDB.recipeToolPref[ri.recipeID] = nil
							if self.dfpoToolVal then
								self.dfpoToolVal:SetText(L"Disabled")
							end
						end
					end)
					valText:SetScript("OnMouseDown", function(vSelf, button)
						if button ~= "LeftButton" then return end
						local ri = self:GetRecipeInfo()
						if not ri then return end
						local p = DFCN_PatronOffersDB.recipeToolPref[ri.recipeID] or {}
						p.stat = ({P="R",R="I",I="P"})[p.stat] or "R"
						if not p.enabled then p.enabled = true end
						DFCN_PatronOffersDB.recipeToolPref[ri.recipeID] = p
						vSelf:SetText(StatName(p.stat))
						if self.dfpoToolCB then self.dfpoToolCB:SetChecked(true) end
						EquipBestProficiencyTool(p.stat, true)
					end)
					self.dfpoToolCB = cb
					self.dfpoToolVal = valText
					self.dfpoAutoText = autoText
				end
				local pref = DFCN_PatronOffersDB.recipeToolPref[recipeID]
				if self._prefTimer then self._prefTimer:Cancel() self._prefTimer = nil end
				if pref and pref.enabled then
					self.dfpoToolCB:SetChecked(true)
					self.dfpoToolVal:SetText(StatName(pref.stat))
					self._prefTimer = C_Timer.NewTimer(0.1, function()
						if ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage:IsShown() then
							EquipBestProficiencyTool(pref.stat, true)
						end
					end)
				else
					self.dfpoToolCB:SetChecked(false)
					if self._prefTimer then self._prefTimer:Cancel() self._prefTimer = nil end
					self.dfpoToolVal:SetText(L"Disabled")
				end
				local showCB = self.TrackRecipeCheckbox
				if showCB and not showCB:IsShown() then
					local isSalvage = self.recipeSchematic and self.recipeSchematic.recipeType == Enum.TradeskillRecipeType.Salvage
					if not isSalvage then
						if self.dfpoToolCB then self.dfpoToolCB:Hide() self.dfpoToolVal:Hide() end
						if self.dfpoAutoText then self.dfpoAutoText:Hide() end
						return
					end
				end
				self.dfpoToolCB:Show()
				self.dfpoToolVal:Show()
				if self.dfpoAutoText then self.dfpoAutoText:Show() end
			end)
			sf.dfpoHooked = true
		end
	end)
end

local orig_syncOrderList = syncOrderList
function syncOrderList(cause)
	orig_syncOrderList(cause)
	updateSummaryVisibility()
end

local function SkipWorkOrderConfirmation(customData, insertedFrame)
	if customData and customData.text == CRAFTING_ORDERS_OWN_REAGENTS_CONFIRMATION then
		local orderView = ProfessionsFrame.OrdersPage.OrderView
		if orderView and orderView.order then
			local orderType = orderView.order.orderType
			if orderType == 3 then
				if customData.callback then
					customData.callback()
				end
				StaticPopup_Hide("GENERIC_CONFIRMATION")
			end
		end
	end
end

hooksecurefunc("StaticPopup_ShowCustomGenericConfirmation", SkipWorkOrderConfirmation)
if not ProfessionsAutoCompleteFrame then
	ProfessionsAutoCompleteFrame = CreateFrame("Frame")
	ProfessionsAutoCompleteFrame.checkTimer = nil
	ProfessionsAutoCompleteFrame:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN")
	ProfessionsAutoCompleteFrame:RegisterEvent("TRADE_SKILL_CLOSE")
	ProfessionsAutoCompleteFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "TRADE_SKILL_CRAFT_BEGIN" then
			self:StartOrderCompletionCheck()
		elseif event == "TRADE_SKILL_CLOSE" then
			self:StopCheckTimer()
		end
	end)
	function ProfessionsAutoCompleteFrame:StartOrderCompletionCheck()
		self:StopCheckTimer()
		self.checkPhase = 1
		self.checkTimer = C_Timer.NewTicker(0, function()
			self:CheckOrderState()
		end)
	end
	function ProfessionsAutoCompleteFrame:CheckOrderState()
		if not ProfessionsFrame or not ProfessionsFrame:IsShown() then
			self:StopCheckTimer()
			return
		end
		if self.checkPhase == 1 then
			local inOrderView = ProfessionsFrame.OrdersPage and
				ProfessionsFrame.OrdersPage:IsShown() and
				ProfessionsFrame.OrdersPage.OrderView and
				ProfessionsFrame.OrdersPage.OrderView:IsShown()
			if inOrderView then
				self.checkPhase = 2
			end
		end
		if self.checkPhase == 2 then
			local orderView = ProfessionsFrame.OrdersPage.OrderView
			local completeButton = orderView and orderView.CompleteOrderButton
			if completeButton and completeButton:IsShown() and completeButton:IsEnabled() then
				local order = orderView.order
				local shouldComplete = false
				if DFCN_PatronOffersDB.autoCompleteAllOrders then
					shouldComplete = true
				else
					shouldComplete = (order.orderType == 3)
				end
				if shouldComplete then
					local completeID = C_CraftingOrders.GetClaimedOrder()
					completeID = completeID and completeID.orderID
					if completeID then checkedOrders[completeID] = false end
					completeButton:Click()
					lastOrderSubmitTime = GetTime()
					lastCastFinishTime = 0
					self:StopCheckTimer()
					if order and ui.orderList then
						for i = #ui.orderList, 1, -1 do
							if ui.orderList[i].orderID == order.orderID then
								table.remove(ui.orderList, i)
								break
							end
						end
						checkedOrders[order.orderID] = false
						T.UpdateSummaryWindow()
					end
				end
			end
		end
	end
	function ProfessionsAutoCompleteFrame:StopCheckTimer()
		if self.checkTimer then
			self.checkTimer:Cancel()
			self.checkTimer = nil
		end
		self.checkPhase = nil
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "DFCN_PatronOffers" then
		EnsureDatabaseDefaults()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		C_Timer.After(5, function()
			syncOrderList("initial")
			lastKnownOrderCount = ui.orderList and #ui.orderList or 0
			if ui.updateFilterAndResync then
				ui.updateFilterAndResync()
			end
			updateSummaryVisibility()
		end)
	end
end)

local lastDfpoExecuteTime = 0
local castingWarningSent = false
local lastPrintMsg = ""
local lastPrintTime = 0
local lastCastingEndTime = 0

local function PrintOnce(msg)
	if DFCN_PatronOffersDB and DFCN_PatronOffersDB.silentMode then return end
	local now = GetTime()
	if msg == lastPrintMsg and now - lastPrintTime < 3 then
		return
	end
	lastPrintMsg = msg
	lastPrintTime = now
	SilentPrint(msg)
end

local spellCastFrame = CreateFrame("Frame")
spellCastFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
spellCastFrame:SetScript("OnEvent", function(self, event, unit)
	if unit ~= "player" then return end
	if ProfessionsFrame and ProfessionsFrame:IsShown() and
	   ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() and
	   ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView:IsShown() then
		lastCastFinishTime = GetTime()
	end
end)

SLASH_DFPO1 = "/dfpo"
function SlashCmdList.DFPO(msg)
	local function DelayedErrorPrint(message)
	if DFCN_PatronOffersDB and DFCN_PatronOffersDB.silentMode then return end
		if dfpoErrorTimer then
			dfpoErrorTimer:Cancel()
		end
		dfpoErrorTimer = C_Timer.NewTimer(0.5, function()
			dfpoErrorTimer = nil
			local stillCasting = UnitCastingInfo("player") or UnitChannelInfo("player")
			if not stillCasting then
				PrintOnce(message)
			end
		end)
	end
	local cmd = msg and msg:trim():lower() or ""
	if cmd ~= "auto" then
		print(L"Msg_Usage")
		return
	end
	local now = GetTime()
	if now - lastOrderSubmitTime < 0.8 then return end
	if now - lastOrderSubmitTime < 1.5 then
		local orderView = ProfessionsFrame and ProfessionsFrame:IsShown() and
				ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() and
				ProfessionsFrame.OrdersPage.OrderView
		if orderView and orderView:IsShown() then return end
	end
	if now - lastDfpoExecuteTime < 0.3 then return end
	if now - lastCastingEndTime < 0.3 then return end
	if now - lastCastFinishTime < 1.5 then
		local orderView = ProfessionsFrame and ProfessionsFrame:IsShown() and
			ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() and
			ProfessionsFrame.OrdersPage.OrderView
		if orderView and orderView:IsShown() then return end
	end
	lastDfpoExecuteTime = now
	local isCasting = UnitCastingInfo("player") or UnitChannelInfo("player")
	if isCasting then
		if not castingWarningSent then
			castingWarningSent = true
		end
		return
	else
		if castingWarningSent then
			if lastCastingEndTime <= now then
				lastCastingEndTime = now
			end
			castingWarningSent = false
		end
	end
	local claimedOrder = C_CraftingOrders.GetClaimedOrder()
	if claimedOrder then
		local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
		local orderView = ordersPage and ordersPage.OrderView
		local inDetail = orderView and orderView:IsShown()
		local currentOrder = inDetail and (orderView.order or claimedOrder)
		if not inDetail or (currentOrder and currentOrder.orderID ~= claimedOrder.orderID) then
			SafeViewOrder(claimedOrder)
			lastOrderSubmitTime = 0
			lastCastFinishTime = 0
			PrintOnce(L"Msg_OpeningOrder")
			return
		end
	end
	if SummaryFrame and SummaryFrame:IsShown() and SummaryFrame.rows and #SummaryFrame.rows > 0 then
		local orderToOpen = nil
		for _, row in ipairs(SummaryFrame.rows) do
			if row and row.orderInfo and row.orderInfo.orderType == 3 then
				local orderID = row.orderInfo.orderID
				local isSelected = checkedOrders[orderID] == nil or checkedOrders[orderID]
				if isSelected and not IsOrderMissingReagents(row.orderInfo) then
					orderToOpen = row.orderInfo
					break
				end
			end
		end
		if orderToOpen then
			SummaryFrame:Hide()
			OpenOrderWithValidation(orderToOpen)
			lastOrderSubmitTime = 0
			lastCastFinishTime = 0
		else
			DelayedErrorPrint(L'Msg_NoReadyOrders')
		end
		return
	end
	local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
	local orderView = ordersPage and ordersPage.OrderView
	local inDetail = ProfessionsFrame and ProfessionsFrame:IsShown() and ordersPage and ordersPage:IsShown() and orderView and orderView:IsShown()
	if inDetail then
		local info = C_TradeSkillUI.GetBaseProfessionInfo()
		if info and info.profession and not C_TradeSkillUI.IsNearProfessionSpellFocus(info.profession) then
			PrintOnce(L'Msg_FarFromStationAuto')
			return
		end
		local startButton = orderView.OrderInfo.StartOrderButton
		local createButton = orderView.CreateButton
		local currentOrder = C_CraftingOrders.GetClaimedOrder()
		if not currentOrder then
			currentOrder = orderView.order
		end
		if currentOrder and not currentOrder.recipeSchematic and currentOrder.spellID then
			local schematic = C_TradeSkillUI.GetRecipeSchematic(currentOrder.spellID, currentOrder.isRecraft)
			if schematic then
				currentOrder.recipeSchematic = schematic
				if currentOrder.reagents then
					for _, reagentInfo in ipairs(currentOrder.reagents) do
						local slotIndex = reagentInfo.slotIndex
						for _, slot in ipairs(schematic.reagentSlotSchematics) do
							if slot.slotIndex == slotIndex then
								slot.cover = true
								break
							end
						end
					end
				end
			end
		end
			if currentOrder and IsOrderMissingReagents(currentOrder) then
			PrintOnce(L'Msg_MissingMatsCantCraft')
			return
		end
		local orderDisplay = L"Order"
		if currentOrder then
			if currentOrder.requestName and currentOrder.requestName ~= "" then
				orderDisplay = currentOrder.requestName
			else
				local link = nil
				if currentOrder.spellID and currentOrder.skillLineAbilityID and currentOrder.minQuality then
					local recipeInfo = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(currentOrder.skillLineAbilityID)
					if recipeInfo and recipeInfo.qualityIDs then
						local qualityID = recipeInfo.qualityIDs[currentOrder.minQuality]
						if qualityID then
							local outputData = C_TradeSkillUI.GetRecipeOutputItemData(
								currentOrder.spellID,
								nil,
								nil,
								qualityID,
								nil
							)
							if outputData and outputData.hyperlink then
								link = outputData.hyperlink
							end
						end
					end
				end
				if not link and currentOrder.itemID then
					_, link = C_Item.GetItemInfo(currentOrder.itemID)
				end
				if link then
					orderDisplay = link
				elseif currentOrder.plainName and currentOrder.plainName ~= "" then
					orderDisplay = currentOrder.plainName
				end
			end
		end
		if startButton and startButton:IsShown() and startButton:IsEnabled() then
			EquipBestProficiencyTool()
			startButton:Click()
			lastCastFinishTime = 0
			if ProfessionsAutoCompleteFrame then
				ProfessionsAutoCompleteFrame:StopCheckTimer()
			end
			PrintOnce(L'Msg_TakingOrder' .. orderDisplay)
			return
		end
		if ProfessionsAutoCompleteFrame and ProfessionsAutoCompleteFrame.checkTimer then
			if UnitCastingInfo("player") or UnitChannelInfo("player") then
				return
			end
			ProfessionsAutoCompleteFrame:StopCheckTimer()
		end
		if currentOrder and IsOrderMissingReagents(currentOrder) then
			PrintOnce(L'Msg_MissingMatsCantCraft')
			return
		end
		local schematicForm = orderView.OrderDetails and orderView.OrderDetails.SchematicForm
		if schematicForm and schematicForm.transaction and currentOrder and currentOrder.spellID then
			local transaction = schematicForm.transaction
			local schematic = C_TradeSkillUI.GetRecipeSchematic(currentOrder.spellID, currentOrder.isRecraft)
			if schematic then
				if currentOrder.reagents then
					for _, reagentInfo in ipairs(currentOrder.reagents) do
						local slotIndex = reagentInfo.slotIndex
						for _, slot in ipairs(schematic.reagentSlotSchematics) do
							if slot.slotIndex == slotIndex then
								slot.cover = true
								break
							end
						end
					end
				end
				local anySwitched = false
				local ignorePriceDiff = DFCN_PatronOffersDB and DFCN_PatronOffersDB.ignorePriceDiff or false
				local threshold = (DFCN_PatronOffersDB and DFCN_PatronOffersDB.priceDiffThreshold) or 10000
				local _ctb = orderView.OrderDetails.SchematicForm.Details.CraftingChoicesContainer.ConcentrateContainer.ConcentrateToggleButton; local _sc = _ctb and _ctb:GetChecked()
				for _, slot in ipairs(schematic.reagentSlotSchematics) do
					if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover and #slot.reagents > 1 then
						local reagents = slot.reagents						
						if not ignorePriceDiff then
							local cheapestItemID, _, _ = GetLowestCostReagentInfo(reagents)
							if cheapestItemID then
								local targetReagent = nil
								for idx, reagent in ipairs(reagents) do
									if reagent.itemID == cheapestItemID then
										targetReagent = reagent
										break
									end
								end
								if targetReagent then
									local allocations = transaction:GetAllocations(slot.slotIndex)
									if allocations then
										allocations:Clear()
										allocations:Allocate(targetReagent, slot.quantityRequired)
										anySwitched = true
										local slotFrame = nil
										local basicSlots = schematicForm:GetSlotsByReagentType(Enum.CraftingReagentType.Basic)
										if basicSlots then
											for _, s in ipairs(basicSlots) do
												if s:GetSlotIndex() == slot.slotIndex then
													slotFrame = s
													break
												end
											end
										end
										if slotFrame then slotFrame:Update() end
									end
								end
							end
						else
							local candidates = {}
							for idx, reagent in ipairs(reagents) do
								local itemID = reagent.itemID
								if itemID then
									local price = CalculateItemValue(itemID) or 0
									local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 1
									local playerHas = GetReagentCount(itemID, quality)
									table.insert(candidates, {
										idx = idx,
										itemID = itemID,
										price = price,
										quality = quality,
										has = playerHas,
									})
								end
							end
							table.sort(candidates, function(a, b) return a.price < b.price end)
							local cheapest = candidates[1]
							local targetReagent = nil
							local needsBetterMats = false
							if ui and ui.orderList then
								for _, po in ipairs(ui.orderList) do
									if po.orderID == currentOrder.orderID then
										needsBetterMats = po._needsBetterMats
										break
									end
								end
							end
							if needsBetterMats then
								local affordableByQuality = {}
								for _, cand in ipairs(candidates) do
									if cand.price - cheapest.price <= threshold then
										table.insert(affordableByQuality, cand)
									end
								end
								table.sort(affordableByQuality, function(a, b) return a.quality > b.quality end)
								for _, cand in ipairs(affordableByQuality) do
									if cand.has >= slot.quantityRequired then
										targetReagent = reagents[cand.idx]
										break
									end
								end
								if not targetReagent and cheapest.has >= slot.quantityRequired then
									targetReagent = reagents[cheapest.idx]
								end
							else
								if cheapest and cheapest.has >= slot.quantityRequired then
									targetReagent = reagents[cheapest.idx]
								end
							end
							if not targetReagent and cheapest then
								for _, cand in ipairs(candidates) do
									if cand.idx ~= cheapest.idx then
										local priceDiff = cand.price - cheapest.price
										if priceDiff <= threshold then
											if cand.has >= slot.quantityRequired then
												targetReagent = reagents[cand.idx]
												break
											end
										end
									end
								end
							end
							if targetReagent then
								local allocations = transaction:GetAllocations(slot.slotIndex)
								if allocations then
									allocations:Clear()
									allocations:Allocate(targetReagent, slot.quantityRequired)
									anySwitched = true
									local slotFrame = nil
									local basicSlots = schematicForm:GetSlotsByReagentType(Enum.CraftingReagentType.Basic)
									if basicSlots then
										for _, s in ipairs(basicSlots) do
											if s:GetSlotIndex() == slot.slotIndex then
												slotFrame = s
												break
											end
										end
									end
									if slotFrame then slotFrame:Update() end
								end
							end
						end
					end
				end
				if anySwitched then
					if schematicForm.TriggerEvent then
						schematicForm:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
					end
					if _sc and _ctb and not _ctb:GetChecked() then _ctb:Click() end
					if createButton and createButton:IsShown() and createButton:IsEnabled() then
						if currentOrder then
						ApplyFinishingItemToCurrentOrder()
					end
					lastCastingEndTime = GetTime()
					lastOrderSubmitTime = 0
					createButton:Click()
					PrintOnce(L'Msg_StartingCraft')
				else
						PrintOnce(L'Msg_QualityNotMetCantCraft')
					end
					return
				end
			end
		end
		if createButton and createButton:IsShown() and createButton:IsEnabled() then
			if currentOrder then
			ApplyFinishingItemToCurrentOrder()
		end
		lastCastingEndTime = GetTime()
		lastOrderSubmitTime = 0
		createButton:Click()
		PrintOnce(L'Msg_StartingCraft')
	else
			PrintOnce(L'Msg_NoCraftableOrders')
		end
		return
	end
	local inList = ui.root and ui.root:IsShown()
	if inList then
		local orderList = ui.orderList or {}
		local selectedOrder = nil
		for _, orderInfo in ipairs(orderList) do
			if orderInfo.orderType == 3 then
				local orderID = orderInfo.orderID
				local isSelected = checkedOrders[orderID] == nil or checkedOrders[orderID]
				if isSelected and not IsOrderMissingReagents(orderInfo) then
					selectedOrder = orderInfo
					break
				end
			end
		end
		if selectedOrder then
			local name = selectedOrder.requestName or selectedOrder.plainName or L"Order"
			local found = false
			for _, row in ipairs(ui.rows) do
				if row and row.orderInfo == selectedOrder then
					row.root:Click()
					lastOrderSubmitTime = 0
					lastCastFinishTime = 0
					found = true
					break
				end
			end
			if not found then
				ProfessionsFrame.OrdersPage:ViewOrder(selectedOrder)
				lastOrderSubmitTime = 0
				lastCastFinishTime = 0
			end
		else
			local isOrderPageVisible = ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown()
			local isSummaryVisible = SummaryFrame and SummaryFrame:IsShown()
			if isOrderPageVisible or isSummaryVisible then
				DelayedErrorPrint(L'Msg_NoReadyOrdersInList')
			end
		end
		return
	end
	if ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() then
		local allOrders = C_CraftingOrders.GetCrafterOrders() or {}
		local selectedOrder = nil
		local function IsOrderReadyForNonCustomer(order)
			local spellID = order.spellID
			if not spellID then return false end
			local recipeInfo = C_TradeSkillUI.GetRecipeInfoForSkillLineAbility(order.skillLineAbilityID)
			if not recipeInfo or not recipeInfo.learned then return false end
			local recipeID = recipeInfo.recipeID
	local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, order and order.isRecraft)
			if not schematic then return false end
			local coveredSlots = {}
			if order.reagents then
				for _, reagentInfo in ipairs(order.reagents) do
					coveredSlots[reagentInfo.slotIndex] = true
				end
			end
			for _, slot in ipairs(schematic.reagentSlotSchematics) do
				local slotIdx = slot.slotIndex
				local isProvided = coveredSlots[slotIdx] or false
				if slot.required and slot.reagentType == Enum.CraftingReagentType.Basic then
					if not isProvided then return false end
				end
				if isProvided then
					if slot.slotInfo and slot.slotInfo.mcrSlotID then
						local locked = C_TradeSkillUI.GetReagentSlotStatus(slot.slotInfo.mcrSlotID, recipeID, order.skillLineAbilityID)
						if locked then return false end
					end
				end
			end
			return true
		end
		for _, orderInfo in ipairs(allOrders) do
			local orderType = orderInfo.orderType
			if orderType == 0 or orderType == 1 or orderType == 2 then
				if IsOrderReadyForNonCustomer(orderInfo) then
					selectedOrder = orderInfo
					break
				end
			end
		end
		if selectedOrder then
			ProfessionsFrame.OrdersPage:ViewOrder(selectedOrder)
			lastOrderSubmitTime = 0
			lastCastFinishTime = 0
			else
			DelayedErrorPrint(L'Msg_NoAutoCraftableOrders')
		end
		return
	end
end

local lastAutoSwitchTime = 0
local function SwitchToCustomerOrdersComplete()
	if not DFCN_PatronOffersDB.autoSwitchToCustomer then return end
	local frame = ProfessionsFrame
	if not frame or not frame:IsShown() then return end
	local tabID = frame.craftingOrdersTabID
	if not tabID then return end
	local tabSystem = frame.TabSystem
	if tabSystem then
		if tabSystem.IsTabShown and not tabSystem:IsTabShown(tabID) then
			return
		end
		local tabButton = tabSystem.GetTabButton and tabSystem:GetTabButton(tabID)
		if tabButton and not tabButton:IsEnabled() then return end
	else
		return
	end
	if frame.SetTab then
		pcall(frame.SetTab, frame, tabID)
	end
	C_Timer.After(0, function()
		local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
		if ordersPage and ordersPage.SetCraftingOrderType then
			pcall(ordersPage.SetCraftingOrderType, ordersPage, 3)
		end
	end)
end

hooksecurefunc(ProfessionsFrame, "Show", function()
	C_Timer.After(0.1, function()
		if ui.versionToggleBtn and ui.UpdateVersionButtonColor then
			ui.UpdateVersionButtonColor(ui.versionToggleBtn)
		end
	end)
	local now = GetTime()
	if now - lastAutoSwitchTime > 0.3 then
		lastAutoSwitchTime = now
		C_Timer.After(0, SwitchToCustomerOrdersComplete)
	end
end)

C_Timer.After(0, function()
	if ProfessionsFrame and ProfessionsFrame:IsShown() then
		SwitchToCustomerOrdersComplete()
	end
end)

local originalCraftingGetWidth = nil
local originalSpecGetWidth = nil
local originalUIScale = nil
local isUIScaled = false

local function getSafeWidthByScale(scale)
	if scale < 0.78 then
		return 940
	else
		return 680
	end
end

local function shouldOverride(scale)
	return scale >= 0.65
end

local function needUIScale(scale)
	return scale >= 0.86
end

local function applyWidthHook(fixedWidth)
	if not ProfessionsFrame then return end
	if ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.GetDesiredPageWidth then
		if not originalCraftingGetWidth then
			originalCraftingGetWidth = ProfessionsFrame.CraftingPage.GetDesiredPageWidth
		end
		ProfessionsFrame.CraftingPage.GetDesiredPageWidth = function()
			return fixedWidth
		end
	end
	if ProfessionsFrame.SpecPage and ProfessionsFrame.SpecPage.GetDesiredPageWidth then
		if not originalSpecGetWidth then
			originalSpecGetWidth = ProfessionsFrame.SpecPage.GetDesiredPageWidth
		end
		ProfessionsFrame.SpecPage.GetDesiredPageWidth = function()
			return fixedWidth
		end
	else
		local function hookSpecLater()
			if ProfessionsFrame.SpecPage and ProfessionsFrame.SpecPage.GetDesiredPageWidth then
				if not originalSpecGetWidth then
					originalSpecGetWidth = ProfessionsFrame.SpecPage.GetDesiredPageWidth
				end
				ProfessionsFrame.SpecPage.GetDesiredPageWidth = function()
					return fixedWidth
				end
				if ProfessionsFrame.ApplyDesiredWidth then
					ProfessionsFrame:ApplyDesiredWidth()
				end
			else
				C_Timer.After(0.2, hookSpecLater)
			end
		end
		hookSpecLater()
	end
	if ProfessionsFrame.ApplyDesiredWidth then
		ProfessionsFrame:ApplyDesiredWidth()
	end
end

local function restoreWidthHook()
	if not ProfessionsFrame then return end
	if originalCraftingGetWidth and ProfessionsFrame.CraftingPage then
		ProfessionsFrame.CraftingPage.GetDesiredPageWidth = originalCraftingGetWidth
		originalCraftingGetWidth = nil
	end
	if originalSpecGetWidth and ProfessionsFrame.SpecPage then
		ProfessionsFrame.SpecPage.GetDesiredPageWidth = originalSpecGetWidth
		originalSpecGetWidth = nil
	end
	if ProfessionsFrame.ApplyDesiredWidth then
		ProfessionsFrame:ApplyDesiredWidth()
	end
end

local function OnAuctionHouseShow()
	if not DFCN_PatronOffersDB.autoAdjustWithAH then return end
	local currentScale = UIParent:GetScale()
	if not shouldOverride(currentScale) then
		return
	end

	if needUIScale(currentScale) then
		originalUIScale = currentScale
		UIParent:SetScale(0.85)
		isUIScaled = true
		applyWidthHook(680)
	else
		local fixedWidth = getSafeWidthByScale(currentScale)
		applyWidthHook(fixedWidth)
	end
end

local function OnAuctionHouseClosed()
	if not DFCN_PatronOffersDB.autoAdjustWithAH then return end
	restoreWidthHook()
	if isUIScaled and originalUIScale then
		UIParent:SetScale(originalUIScale)
		isUIScaled = false
		originalUIScale = nil
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "AUCTION_HOUSE_SHOW" then
		SwitchActionBarIfNeeded()
		OnAuctionHouseShow()
		if DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoShoppingSearch then
			if SummaryFrame and SummaryFrame:IsShown() and SummaryFrame.currentMaterialNeeds and next(SummaryFrame.currentMaterialNeeds) then
				C_Timer.After(1, PerformOneClickShopping)
			end
		end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		OnAuctionHouseClosed()
		if DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoSwitchActionBar and not InCombatLockdown() then
			ChangeActionBarPage(1)
		end
	end
end)

local function Initialize()
	if ProfessionsFrame then
		if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
			OnAuctionHouseShow()
		end
	else
		C_Timer.After(0.5, Initialize)
	end
end
Initialize()

local function GetSafeVendorPrice(itemID)
	if not (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetVendorPriceByItemID) then
		return nil
	end
	local vp = Auctionator.API.v1.GetVendorPriceByItemID("DFCN_PatronOffers", itemID)
	if type(vp) == "number" and vp > 0 then
		return vp
	end
	return nil
end

local function AutoBuyMissingVendorItems()
	if not (DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoBuyVendorItems) then return	end
	if not SummaryFrame then return	end
	local needs = SummaryFrame.currentMaterialNeeds
	if not needs then return end
	local vendorNeeds = {}
	for itemID, data in pairs(needs) do
		if itemID ~= -1 then
			local count = data and data.count
			if type(count) ~= "number" then
				count = 0
			end
			if count > 0 then
				local vp = GetSafeVendorPrice(itemID)
				if vp then
					local ahPrice = nil
					if HAS_AUCTIONATOR then
						ahPrice = Auctionator.API.v1.GetAuctionPriceByItemID(AUCTIONATOR_L_REAGENT_SEARCH, itemID)
					end
					if not ahPrice or vp <= ahPrice then
						vendorNeeds[itemID] = { count = count, price = vp }
					end
				end
			end
		end
	end
	if not next(vendorNeeds) then return end
	local merchantCount = GetMerchantNumItems()
	if type(merchantCount) ~= "number" or merchantCount <= 0 then
		return
	end
	local purchased = 0
	for i = 1, merchantCount do
		local itemID = GetMerchantItemID(i)
		if itemID and vendorNeeds[itemID] then
			local need = vendorNeeds[itemID].count
			local price = vendorNeeds[itemID].price
			if type(price) == "number" and price > 0 then
				local playerMoney = GetMoney()
				local canBuyCount = math.floor(playerMoney / price)
				local buyCount = math.min(need, canBuyCount)
				if buyCount > 0 then
					BuyMerchantItem(i, buyCount)
					purchased = purchased + buyCount
					local itemLink = GetMerchantItemLink(i) or ('|Hitem:' .. itemID .. '|h' .. L'[Item]' .. '|h')
					SilentPrint(L'Msg_BuyFromNPC' .. itemLink .. ' x ' .. buyCount)
					vendorNeeds[itemID].count = need - buyCount
					if vendorNeeds[itemID].count <= 0 then
						vendorNeeds[itemID] = nil
					end
				end
			end
		end
	end
	if purchased > 0 then
		C_Timer.After(0.5, function()
			if SummaryFrame and SummaryFrame:IsShown() then
				T.UpdateSummaryWindow()
			end
		end)
	end
end

local merchantEventFrame = CreateFrame("Frame")
merchantEventFrame:RegisterEvent("MERCHANT_SHOW")
merchantEventFrame:SetScript("OnEvent", function(self, event)
	if event == "MERCHANT_SHOW" then
		if not (DFCN_PatronOffersDB and DFCN_PatronOffersDB.autoBuyVendorItems) then return end
		if not (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetVendorPriceByItemID) then return end
		local hasVendorNeed = false
		if SummaryFrame and SummaryFrame.currentMaterialNeeds then
			for itemID, data in pairs(SummaryFrame.currentMaterialNeeds) do
				if itemID ~= -1 then
					local vp = GetSafeVendorPrice(itemID)
					if vp then
						hasVendorNeed = true
						break
					end
				end
			end
		end
		if not hasVendorNeed then return end
		C_Timer.After(1, AutoBuyMissingVendorItems)
	end
end)

local mailFrame = CreateFrame("Frame")
mailFrame:RegisterEvent("MAIL_SHOW")
mailFrame:SetScript("OnEvent", function()
	if InCombatLockdown() then return end
	SwitchActionBarIfNeeded()
	openAllMailActive = false
	local closeMonitorTimer = nil
	local function stopCloseMonitor()
		if closeMonitorTimer then
			closeMonitorTimer:Cancel()
			closeMonitorTimer = nil
		end
	end
	local function monitorMailClosed()
		if not (MailFrame and MailFrame:IsShown()) then
			if DFCN_PatronOffersDB.autoSwitchActionBar and not InCombatLockdown() then
				local shouldRestore = true
				if (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (ProfessionsFrame and ProfessionsFrame:IsShown()) then
					shouldRestore = false
				end
				if shouldRestore and not (UnitCastingInfo("player") or UnitChannelInfo("player")) then
					ChangeActionBarPage(1)
				end
			end
			if DFCN_PatronOffersDB.autoMailManagement and not InCombatLockdown() then
				C_Container.SortBags()
			end
			stopCloseMonitor()
		else
			closeMonitorTimer = C_Timer.NewTimer(0.3, monitorMailClosed)
		end
	end
	C_Timer.After(0.2, monitorMailClosed)
	if DFCN_PatronOffersDB.autoMailManagement then
		local emptyDeletionTimer = nil
		local pendingDeleteIndex = nil
		local pendingCheckCount = 0
		local printedEmptyInfo = false
		local function stopEmptyDeletion()
			if emptyDeletionTimer then
				emptyDeletionTimer:Cancel()
				emptyDeletionTimer = nil
			end
			pendingDeleteIndex = nil
			pendingCheckCount = 0
		end
		local function isMailEmpty(index)
			local success, _, _, _, _, money, CODAmount, _, hasItem = pcall(GetInboxHeaderInfo, index)
			if not success then return false end
			return (not hasItem or hasItem == 0) and (money or 0) == 0 and (CODAmount or 0) == 0
		end
		local function deleteEmptyMails()
			if InCombatLockdown() then return end
			if not (MailFrame and MailFrame:IsShown()) then stopEmptyDeletion() return end
			if pendingDeleteIndex then
				local currentCount = GetInboxNumItems()
				if not currentCount or pendingDeleteIndex > currentCount then
					pendingDeleteIndex = nil
					pendingCheckCount = 0
					deleteEmptyMails()
					return
				end
				if isMailEmpty(pendingDeleteIndex) then
					pendingCheckCount = pendingCheckCount + 1
					if pendingCheckCount >= 2 then
						DeleteInboxItem(pendingDeleteIndex)
						if not printedEmptyInfo then
							SilentPrint(L'Msg_DeletedEmptyMail')
							printedEmptyInfo = true
						end
						pendingDeleteIndex = nil
						pendingCheckCount = 0
						emptyDeletionTimer = C_Timer.NewTimer(0.2, deleteEmptyMails)
						return
					else
						emptyDeletionTimer = C_Timer.NewTimer(0.1, deleteEmptyMails)
						return
					end
				else
					pendingDeleteIndex = nil
					pendingCheckCount = 0
					emptyDeletionTimer = C_Timer.NewTimer(0.1, deleteEmptyMails)
					return
				end
			end
			local numMails = GetInboxNumItems()
			if not numMails or numMails == 0 then
				stopEmptyDeletion()
				return
			end
			for i = numMails, 1, -1 do
				if isMailEmpty(i) then
					pendingDeleteIndex = i
					pendingCheckCount = 0
					deleteEmptyMails()
					return
				end
			end
			stopEmptyDeletion()
		end
		local function pollOpenAllMail()
			if not (MailFrame and MailFrame:IsShown()) then
				if openAllMailTimer then openAllMailTimer:Cancel() end
				openAllMailTimer = nil
				return
			end
		if _G.OpenAllMail and _G.OpenAllMail.Click and not openAllMailActive then
			local count = 0
			local numMails = GetInboxNumItems()
			if numMails and numMails > 0 then
				for i = 1, numMails do
					local ok, _, _, _, _, money, _, _, hasItem = pcall(GetInboxHeaderInfo, i)
					if ok and (hasItem or (money and money > 0)) then
						count = count + 1
					end
				end
			end
			if count > 0 then
				SilentPrint(string.format(L"Msg_CollectingMail", count))
				_G.OpenAllMail:Click()
				openAllMailActive = true
			end
		elseif openAllMailActive then
			local numMails = GetInboxNumItems()
			local done = true
			if numMails and numMails > 0 then
				for i = 1, numMails do
					local ok, _, _, _, _, money, _, _, hasItem = pcall(GetInboxHeaderInfo, i)
					if ok and (hasItem or (money and money > 0)) then
						done = false
						break
					end
				end
			end
			if done then openAllMailActive = false end
		end
		openAllMailTimer = C_Timer.NewTimer(0.5, pollOpenAllMail)
	end
	openAllMailTimer = C_Timer.NewTimer(SummaryFrame and SummaryFrame:IsShown() and 1.5 or 0.5, pollOpenAllMail)
	local mailCountStableTimer = nil
		local lastCount = nil
		local stableCount = 0
		local function checkMailCountStable()
			if not (MailFrame and MailFrame:IsShown()) then
				if mailCountStableTimer then
					mailCountStableTimer:Cancel()
					mailCountStableTimer = nil
				end
				return
			end
			local currentCount = GetInboxNumItems()
			if currentCount == lastCount then
				stableCount = stableCount + 1
				if stableCount >= 2 then
					if mailCountStableTimer then
						mailCountStableTimer:Cancel()
						mailCountStableTimer = nil
					end
					if MailFrame and MailFrame:IsShown() then
						deleteEmptyMails()
					end
					return
				end
			else
				stableCount = 0
			end
			lastCount = currentCount
			mailCountStableTimer = C_Timer.NewTimer(0.3, checkMailCountStable)
	end
	C_Timer.After(SummaryFrame and SummaryFrame:IsShown() and 1.5 or 0.5, checkMailCountStable)
	end
	if not (DFCN_PatronOffersDB.autoShoppingSearch and SummaryFrame and SummaryFrame:IsShown()) then return	end
	local filteredOrders = {}
	for _, orderInfo in ipairs(ui.orderList) do
		local hasPlayerReagents = false
		if orderInfo.recipeSchematic then
			for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
				if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
					hasPlayerReagents = true
					break
				end
			end
		end
		if hasPlayerReagents and (checkedOrders[orderInfo.orderID] == nil or checkedOrders[orderInfo.orderID]) then
			table.insert(filteredOrders, orderInfo)
		end
	end
	local totalDemand = {}
	for _, orderInfo in ipairs(filteredOrders) do
		if orderInfo.recipeSchematic then
			for _, slot in ipairs(orderInfo.recipeSchematic.reagentSlotSchematics) do
				if slot.reagentType == Enum.CraftingReagentType.Basic and slot.required and not slot.cover then
					local cheapestItemID, _, _ = GetLowestCostReagentInfo(slot.reagents)
					if cheapestItemID then
						local required = slot.quantityRequired
						totalDemand[cheapestItemID] = (totalDemand[cheapestItemID] or 0) + required
					end
				end
			end
		end
	end
	if not next(totalDemand) then return end
	local printed = false
	local pollTimer = nil
	local INTERVAL = 0.2
	local function stopPoll()
		if pollTimer then
			pollTimer:Cancel()
			pollTimer = nil
		end
	end
	local function pollMail()
		if not (MailFrame and MailFrame:IsShown()) then
			stopPoll()
			return
		end
		local currentNeedMap = {}
		for itemID, totalReq in pairs(totalDemand) do
			local playerHas = C_Item.GetItemCount(itemID, true, false, true, true)
			local need = math.max(0, totalReq - playerHas)
			if need > 0 then
				currentNeedMap[itemID] = need
			end
		end
		if not next(currentNeedMap) then
			stopPoll()
			return
		end
		local numMails = GetInboxNumItems()
		if numMails and numMails > 0 then
			local taken = false
			for msgIdx = 1, numMails do
				for attachIdx = 1, ATTACHMENTS_MAX_RECEIVE do
					local _, itemID, _, count = GetInboxItem(msgIdx, attachIdx)
					if itemID and currentNeedMap[itemID] and currentNeedMap[itemID] > 0 then
						if not printed then
							SilentPrint(L'Msg_CollectingMaterials')
							printed = true
						end
						if not InCombatLockdown() then
							TakeInboxItem(msgIdx, attachIdx)
							taken = true
							break
						end
					end
				end
				if taken then break end
			end
			if taken then
				pollTimer = C_Timer.NewTimer(INTERVAL, pollMail)
				return
			end
		end
		pollTimer = C_Timer.NewTimer(INTERVAL, pollMail)
	end
	C_Timer.After(0.5, function()
		pollMail()
	end)
end)
