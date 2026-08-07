local _, GF = ...

GF.ApplicantSnapshotBuilder = {}
local Builder = GF.ApplicantSnapshotBuilder

local LABEL_GOLD = CreateColor and CreateColor(1, 0.82, 0)
		or { r = 1, g = 0.82, b = 0 }
local IL_VALUE = CreateColor and CreateColor(0.1, 1, 0.1)
		or { r = 0.1, g = 1, b = 0.1 }

local STATUS_GRAY = CreateColor and CreateColor(0.5, 0.5, 0.5)
		or { r = 0.5, g = 0.5, b = 0.5 }
local STATUS_GREEN = GREEN_FONT_COLOR
		or (CreateColor and CreateColor(0, 1, 0))
		or { r = 0, g = 1, b = 0 }
local MAX_APPLICANT_API_ID = 4294967295

local function isAccessibleValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function normalizeRosterIdentityName(name, realm)
	if not isAccessibleValue(name) or type(name) ~= "string" or name == "" then
		return nil
	end
	if realm ~= nil
		and (not isAccessibleValue(realm) or type(realm) ~= "string")
	then
		return nil
	end
	local normalize = GF.NormalizeExternalFullPlayerName
	if type(normalize) ~= "function" then
		return nil
	end
	local ok, fullName = pcall(normalize, name, realm)
	if not ok or not isAccessibleValue(fullName)
		or type(fullName) ~= "string" or fullName == ""
	then
		return nil
	end
	return fullName:gsub("%s+", ""):lower()
end

local function readUnitRosterIdentity(unit)
	if type(unit) ~= "string" or unit == "" then
		return nil
	end
	if type(UnitExists) == "function" then
		local okExists, exists = pcall(UnitExists, unit)
		if not okExists or not isAccessibleValue(exists) or exists ~= true then
			return nil
		end
	end
	local name, realm
	if type(UnitFullName) == "function" then
		local ok
		ok, name, realm = pcall(UnitFullName, unit)
		if not ok then
			name, realm = nil, nil
		end
	end
	if (not isAccessibleValue(name) or type(name) ~= "string" or name == "")
		and type(UnitName) == "function"
	then
		local ok, fallbackName = pcall(UnitName, unit)
		if ok then
			name = fallbackName
		end
	end
	local nameKey = normalizeRosterIdentityName(name, realm)
	local guidKey
	if type(UnitGUID) == "function" then
		local ok, guid = pcall(UnitGUID, unit)
		if ok and isAccessibleValue(guid)
			and type(guid) == "string" and guid ~= ""
		then
			guidKey = guid:lower()
		end
	end
	if not nameKey and not guidKey then
		return nil
	end
	return {
		guidKey = guidKey,
		nameKey = nameKey,
		unit = unit,
	}
end

local function readNumber(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if not ok or not isAccessibleValue(value) then
		return nil
	end
	return tonumber(value)
end

local function readBoolean(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if not ok or not isAccessibleValue(value) or type(value) ~= "boolean" then
		return nil
	end
	return value
end

local GRAYED_STATUSES = {}
for _, status in ipairs({
	"cancelled", "declined", "declined_delisted", "declined_full",
	"failed", "inviteaccepted", "invitedeclined", "timedout",
}) do
	GRAYED_STATUSES[status] = true
end

local ROLE_SORT_RANK = {
	TANK = 1,
	HEALER = 2,
	DAMAGER = 3,
	DPS = 3,
}
local UNKNOWN_ROLE_SORT_RANK = 4

local function getActivityInfo()
	local api = C_LFGList
	if not api or type(api.GetActiveEntryInfo) ~= "function"
		or type(api.GetActivityInfoTable) ~= "function"
	then
		return nil
	end
	local entry = api.GetActiveEntryInfo()
	local activityIDs = type(entry) == "table" and entry.activityIDs or nil
	local activityID = type(activityIDs) == "table" and activityIDs[1] or nil
	if activityID == nil then
		return nil
	end
	return api.GetActivityInfoTable(activityID, entry.questID)
end

local function isGrayedOut(appInfo)
	if type(appInfo) ~= "table" then
		return true
	end
	if appInfo.pendingApplicationStatus ~= nil then
		return false
	end
	return GRAYED_STATUSES[appInfo.applicationStatus] == true
end

local function getBlocklistMatch(playerName)
	local bl = GF.Blocklist
	if type(playerName) ~= "string" or playerName == "" or not bl then
		return nil
	end
	if type(bl.IsEnabled) == "function" and bl:IsEnabled() ~= true then
		return nil
	end
	if type(bl.FindPlayerMatch) == "function" then
		return bl:FindPlayerMatch(playerName)
	end
	return nil
end

local function getSpecName(specID)
	if specID ~= nil and PlayerUtil
		and type(PlayerUtil.GetSpecNameBySpecID) == "function"
	then
		local specName = PlayerUtil.GetSpecNameBySpecID(specID)
		if specName and specName ~= "" then
			return specName
		end
	end
	return nil
end

local function specDisplayName(specID, localizedClass)
	local specName = getSpecName(specID)
	return specName or localizedClass or ""
end

local function memberItemLevel(activityInfo, itemLevel, pvpItemLevel)
	local raw = activityInfo and activityInfo.isPvpActivity
		and pvpItemLevel or itemLevel
	return math.floor(tonumber(raw) or 0)
end

local function getListingDungeonScore(applicantID, memberIdx)
	local api = C_LFGList
	if not api or type(api.GetApplicantDungeonScoreForListing) ~= "function" then
		return nil
	end
	local entry = api.GetActiveEntryInfo()
	local activities = entry and entry.activityIDs
	local activityID = type(activities) == "table" and activities[1] or nil
	if activityID == nil then
		return nil
	end
	local ok, scoreInfo = pcall(
		api.GetApplicantDungeonScoreForListing,
		applicantID,
		memberIdx,
		activityID)
	return ok and scoreInfo or nil
end

local function getBestDungeonScore(applicantID, memberIdx)
	if not C_LFGList or not C_LFGList.GetApplicantBestDungeonScore then
		return nil
	end
	local ok, scoreInfo = pcall(C_LFGList.GetApplicantBestDungeonScore, applicantID, memberIdx)
	return ok and scoreInfo or nil
end

local function shouldBuildMplusProfile(activityInfo)
	return activityInfo and (activityInfo.categoryID == GF.CAT_DUNGEON or activityInfo.isMythicPlusActivity)
end

local function buildMplusProfileDetail(applicantID, memberIdx, dungeonScore, activityInfo)
	if shouldBuildMplusProfile(activityInfo) ~= true then
		return nil
	end
	local includeListingDungeon = activityInfo.isMythicPlusActivity == true
	local numericScore = tonumber(dungeonScore)
	local overall = numericScore and numericScore > 0 and numericScore or nil
	local listing = includeListingDungeon
		and getListingDungeonScore(applicantID, memberIdx) or nil
	local bestOverall = getBestDungeonScore(applicantID, memberIdx)
	if overall == nil and listing == nil and bestOverall == nil then
		return includeListingDungeon and {} or nil
	end
	return {
		bestLevelIncrement = listing and listing.bestLevelIncrement,
		bestOverallScore = bestOverall,
		bestRunLevel = listing and listing.bestRunLevel,
		currentDungeon = listing,
		finishedSuccess = listing and listing.finishedSuccess,
		mapName = listing and listing.mapName,
		mapScore = listing and listing.mapScore,
		overall = overall,
	}
end

local function memberRatingText(applicantID, memberIdx, level, dungeonScore, activityInfo, mplusProfileDetail)
	local maxLevel = type(GetMaxLevelForPlayerExpansion) == "function"
		and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL or 80
	local numericLevel = tonumber(level)
	if numericLevel and numericLevel < maxLevel then
		return "level", numericLevel, nil, nil
	end
	if activityInfo and activityInfo.isRatedPvpActivity
		and type(C_LFGList.GetApplicantPvpRatingInfoForListing) == "function"
	then
		local entry = C_LFGList.GetActiveEntryInfo()
		local activities = entry and entry.activityIDs
		local activityID = type(activities) == "table" and activities[1] or nil
		if activityID ~= nil then
			local pvp = C_LFGList.GetApplicantPvpRatingInfoForListing(
				applicantID,
				memberIdx,
				activityID)
			if type(pvp) == "table" and type(pvp.rating) == "number"
				and pvp.rating >= 0
			then
				return "rating", pvp.rating, GF.GetPvpRatingColor(pvp.rating), pvp
			end
		end
	end
	if activityInfo and activityInfo.isMythicPlusActivity then
		return "mplus", nil, nil, mplusProfileDetail or {}
	end
	local score = tonumber(dungeonScore)
	if score and score > 0 then
		local colorGetter = C_ChallengeMode
			and C_ChallengeMode.GetDungeonScoreRarityColor
		local color = type(colorGetter) == "function" and colorGetter(score)
			or HIGHLIGHT_FONT_COLOR
		return "rating", score, color, nil
	end
	local emptyRatingKind = "rating"
	return emptyRatingKind, nil, nil, nil
end

local function buildRoles(tank, healer, damage)
	local roles = {}
	for _, candidate in ipairs({
		{ enabled = tank, name = "TANK" },
		{ enabled = healer, name = "HEALER" },
		{ enabled = damage, name = "DAMAGER" },
	}) do
		if candidate.enabled then
			roles[#roles + 1] = candidate.name
		end
	end
	return roles[1], roles[2], roles[3]
end

local function normalizeApplicantAPIID(applicantID)
	applicantID = tonumber(applicantID)
	if not applicantID or applicantID < 0 or applicantID > MAX_APPLICANT_API_ID then
		return nil
	end
	return applicantID
end

local function getApplicantDataSocialSortPin(data)
	for _, memberData in ipairs(data and data.members or {}) do
		local socialType = GF.GetSocialRelationshipType
			and GF.GetSocialRelationshipType(memberData and memberData.relationship)
		if socialType then
			return GF.GetSocialSortPin and GF.GetSocialSortPin(socialType) or 0
		end
	end
	return GF.NORMAL_SORT_PIN or 1
end

local function asPositiveNumber(value)
	value = tonumber(value)
	if value and value > 0 then
		return value
	end
	return nil
end

local function getRoleSortRank(role)
	if not role then
		return nil
	end
	return ROLE_SORT_RANK[tostring(role):upper()]
end

local function getApplicantDataRoleSortKey(data)
	local bestRank = UNKNOWN_ROLE_SORT_RANK
	for _, memberData in ipairs(data and data.members or {}) do
		local rank1 = getRoleSortRank(memberData and memberData.role1)
		if rank1 and rank1 < bestRank then
			bestRank = rank1
		end
		local rank2 = getRoleSortRank(memberData and memberData.role2)
		if rank2 and rank2 < bestRank then
			bestRank = rank2
		end
		local rank3 = getRoleSortRank(memberData and memberData.role3)
		if rank3 and rank3 < bestRank then
			bestRank = rank3
		end
	end
	return { value = bestRank }
end

local function getMemberScoreSortParts(memberData)
	if not memberData then
		return nil
	end
	if memberData.ratingKind == "mplus" then
		local detail = memberData.ratingDetail
		local overall = asPositiveNumber(detail and detail.overall) or 0
		local mapScore = asPositiveNumber(detail and detail.mapScore) or 0
		local bestRunLevel = asPositiveNumber(detail and detail.bestRunLevel) or 0
		if overall > 0 or mapScore > 0 or bestRunLevel > 0 then
			return { overall, mapScore, bestRunLevel }
		end
	end
	local value = asPositiveNumber(memberData.ratingValue)
	if value then
		return { value, 0, 0 }
	end
	return nil
end

local function isScorePartsGreater(a, b)
	if not b then
		return true
	end
	for i = 1, 3 do
		local av = a[i] or 0
		local bv = b[i] or 0
		if av ~= bv then
			return av > bv
		end
	end
	return false
end

local function getApplicantDataScoreSortKey(data)
	local bestParts
	for _, memberData in ipairs(data and data.members or {}) do
		local parts = getMemberScoreSortParts(memberData)
		if parts and isScorePartsGreater(parts, bestParts) then
			bestParts = parts
		end
	end
	return { missing = bestParts == nil, values = bestParts or { 0, 0, 0 } }
end

local function getApplicantDataIlvlSortKey(data)
	local bestIlvl = 0
	for _, memberData in ipairs(data and data.members or {}) do
		local ilvl = asPositiveNumber(memberData and memberData.ilvl)
		if ilvl and ilvl > bestIlvl then
			bestIlvl = ilvl
		end
	end
	return { missing = bestIlvl <= 0, value = bestIlvl }
end

local function compareRoleSortKey(a, b, asc)
	local av = (a and a.value) or UNKNOWN_ROLE_SORT_RANK
	local bv = (b and b.value) or UNKNOWN_ROLE_SORT_RANK
	if av == bv then
		return nil
	end
	if asc then
		return av < bv
	end
	return av > bv
end

local function compareScalarSortKey(a, b, asc)
	local aMissing = not a or a.missing == true
	local bMissing = not b or b.missing == true
	if aMissing ~= bMissing then
		return not aMissing
	end
	local av = (a and a.value) or 0
	local bv = (b and b.value) or 0
	if av == bv then
		return nil
	end
	if asc then
		return av < bv
	end
	return av > bv
end

local function compareScoreSortKey(a, b, asc)
	local aMissing = not a or a.missing == true
	local bMissing = not b or b.missing == true
	if aMissing ~= bMissing then
		return not aMissing
	end
	local avs = (a and a.values) or {}
	local bvs = (b and b.values) or {}
	for i = 1, 3 do
		local av = avs[i] or 0
		local bv = bvs[i] or 0
		if av ~= bv then
			if asc then
				return av < bv
			end
			return av > bv
		end
	end
	return nil
end

local function compareApplicantSortKey(columnID, a, b, asc)
	if columnID == "role" then
		return compareRoleSortKey(a, b, asc)
	end
	if columnID == "score" then
		return compareScoreSortKey(a, b, asc)
	end
	if columnID == "ilvl" then
		return compareScalarSortKey(a, b, asc)
	end
	return nil
end

local function getApplicantDataSortKey(data, columnID)
	if columnID == "role" then
		return getApplicantDataRoleSortKey(data)
	end
	if columnID == "score" then
		return getApplicantDataScoreSortKey(data)
	end
	if columnID == "ilvl" then
		return getApplicantDataIlvlSortKey(data)
	end
	return nil
end

function Builder:GetApplicantSocialSortPin(applicantID)
	if GF.ApplicantTestData and GF.ApplicantTestData.IsTestApplicantID
		and GF.ApplicantTestData:IsTestApplicantID(applicantID)
		and GF.ApplicantTestData.BuildApplicant then
		return getApplicantDataSocialSortPin(GF.ApplicantTestData:BuildApplicant(applicantID))
	end

	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID or not (C_LFGList and C_LFGList.GetApplicantInfo and C_LFGList.GetApplicantMemberInfo) then
		return GF.NORMAL_SORT_PIN or 1
	end
	local okInfo, appInfo = pcall(C_LFGList.GetApplicantInfo, applicantID)
	if not okInfo or not isAccessibleValue(appInfo) or type(appInfo) ~= "table" then
		return GF.NORMAL_SORT_PIN or 1
	end
	local rawNumMembers = appInfo.numMembers
	if not isAccessibleValue(rawNumMembers) then
		return GF.NORMAL_SORT_PIN or 1
	end
	local okCount, numericCount = pcall(tonumber, rawNumMembers)
	if not okCount then
		return GF.NORMAL_SORT_PIN or 1
	end
	local numMembers = math.max(1, numericCount or 1)
	for i = 1, numMembers do
		local ok, _, _, _, _, _, _, _, _, _, _, relationship =
			pcall(C_LFGList.GetApplicantMemberInfo, applicantID, i)
		if ok and isAccessibleValue(relationship) then
			local socialType = GF.GetSocialRelationshipType and GF.GetSocialRelationshipType(relationship)
			if socialType then
				return GF.GetSocialSortPin and GF.GetSocialSortPin(socialType) or 0
			end
		end
	end
	return GF.NORMAL_SORT_PIN or 1
end

function Builder:GetApplicantSortKey(applicantID, columnID)
	local data = self:BuildApplicantSafely(applicantID)
	return getApplicantDataSortKey(data, columnID)
end

function Builder:GetSortedApplicantIDs()
	local getApplicants = C_LFGList and C_LFGList.GetApplicants
	local okApplicants, ids = false, nil
	if type(getApplicants) == "function" then
		okApplicants, ids = pcall(getApplicants)
	end
	local providerReadable = okApplicants and type(ids) == "table"
	if not providerReadable then
		ids = {}
	end
	if LFGListUtil_SortApplicants then
		local sortedIDs = {}
		for index, applicantID in ipairs(ids) do
			sortedIDs[index] = applicantID
		end
		local okSort = pcall(LFGListUtil_SortApplicants, sortedIDs)
		if okSort then
			ids = sortedIDs
		end
	end
	local testDataEnabled = GF.ApplicantTestData
		and GF.ApplicantTestData.IsEnabled
		and GF.ApplicantTestData:IsEnabled()
	if testDataEnabled then
		local testIDs = GF.ApplicantTestData:GetApplicantIDs()
		for _, applicantID in ipairs(testIDs) do
			ids[#ids + 1] = applicantID
		end
		-- The fixture provider is authoritative on its own.  Outside an active
		-- listing Blizzard can make GetApplicants() unavailable; that must not
		-- cause the applicant panel to reject otherwise readable debug rows.
		providerReadable = true
	end
	if #ids > 1 then
		local originalIndex = {}
		local socialPins = {}
		local sortSpec = GF.ListColumns
			and GF.ListColumns.GetApplicantSort
			and GF.ListColumns:GetApplicantSort()
		local sortKeys = {}
		for i, applicantID in ipairs(ids) do
			originalIndex[applicantID] = i
			socialPins[applicantID] = self:GetApplicantSocialSortPin(applicantID)
			if sortSpec then
				sortKeys[applicantID] = self:GetApplicantSortKey(applicantID, sortSpec.column)
			end
		end
		table.sort(ids, function(a, b)
			local pa = socialPins[a] or (GF.NORMAL_SORT_PIN or 1)
			local pb = socialPins[b] or (GF.NORMAL_SORT_PIN or 1)
			if pa ~= pb then
				return pa < pb
			end
			if sortSpec then
				local sorted = compareApplicantSortKey(
					sortSpec.column,
					sortKeys[a],
					sortKeys[b],
					sortSpec.asc ~= false
				)
				if sorted ~= nil then
					return sorted
				end
			end
			return (originalIndex[a] or 0) < (originalIndex[b] or 0)
		end)
	end
	return ids, providerReadable
end

function Builder:BuildMember(applicantID, memberIdx, appInfo, activityInfo)
	local values = { C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx) }
	local name, class, localizedClass = values[1], values[2], values[3]
	local level, itemLevel, honorLevel = values[4], values[5], values[6]
	local tank, healer, damage = values[7], values[8], values[9]
	local assignedRole, relationship = values[10], values[11]
	local dungeonScore, pvpItemLevel = values[12], values[13]
	local factionGroup, specID, isLeaver = values[14], values[16], values[17]
	local role1, role2, role3 = buildRoles(tank, healer, damage)
	local profile = buildMplusProfileDetail(
		applicantID,
		memberIdx,
		dungeonScore,
		activityInfo)
	local ratingKind, ratingValue, ratingColor, ratingDetail = memberRatingText(
		applicantID,
		memberIdx,
		level,
		dungeonScore,
		activityInfo,
		profile)
	local blacklistEntry = getBlocklistMatch(name)
	local specName = getSpecName(specID)
	local isLaonongFan = false
	if type(GF.IsLaonongFanDirectoryReady) == "function"
		and GF.IsLaonongFanDirectoryReady()
		and type(GF.IsLaonongFanName) == "function"
	then
		isLaonongFan = GF.IsLaonongFanName(name, nil, true) == true
	end
	local member = {
		activityInfo = activityInfo,
		assignedRole = assignedRole,
		blacklistEntry = blacklistEntry,
		class = class,
		comment = appInfo.comment or "",
		displayName = name and Ambiguate(name, "short") or nil,
		factionGroup = factionGroup,
		grayed = isGrayedOut(appInfo),
		honorLevel = honorLevel,
		ilvl = memberItemLevel(activityInfo, itemLevel, pvpItemLevel),
		isBlacklisted = blacklistEntry ~= nil,
		isLaonongFan = isLaonongFan,
		isLeaver = isLeaver,
		level = level,
		localizedClass = localizedClass,
		memberIdx = memberIdx,
		name = name,
		noTouchy = appInfo.applicationStatus == "invited",
		rosterIdentityKey = normalizeRosterIdentityName(name),
		ratingColor = ratingColor,
		ratingDetail = ratingDetail,
		ratingKind = ratingKind,
		ratingValue = ratingValue,
		relationship = relationship,
		role1 = role1,
		role2 = role2,
		role3 = role3,
		specID = specID,
		specName = specName,
		specText = specName or specDisplayName(specID, localizedClass),
		mplusProfileDetail = profile,
	}
	return member
end

function Builder:BuildApplicant(applicantID)
	local testData = GF.ApplicantTestData
	if testData and type(testData.IsTestApplicantID) == "function"
		and testData:IsTestApplicantID(applicantID)
	then
		return testData:BuildApplicant(applicantID)
	end
	local numericID = normalizeApplicantAPIID(applicantID)
	if numericID == nil then
		return nil
	end
	local appInfo = C_LFGList.GetApplicantInfo(numericID)
	if type(appInfo) ~= "table" then
		return nil
	end
	local activityInfo = getActivityInfo()
	local numMembers = tonumber(appInfo.numMembers) or 1
	local members = {}
	for memberIndex = 1, numMembers do
		members[memberIndex] = self:BuildMember(
			numericID,
			memberIndex,
			appInfo,
			activityInfo)
	end
	local status = appInfo.applicationStatus
	-- Blizzard's applicant-level spinner is owned by truthy applicantInfo.  The
	-- documented pending status gates actions only while the record is still
	-- applied; it must not hide a terminal status or its acknowledgement.
	local nativePending = status == "applied"
		and appInfo.pendingApplicationStatus ~= nil
	local statusText, statusColor
	if not appInfo.applicantInfo and status ~= nil then
		if status == "inviteaccepted" then
			statusText = (GF.L and GF.L.APPLICANT_STATUS_JOINED)
				or GF.ApplicantActionService:GetStatusText(status)
		else
			statusText = GF.ApplicantActionService:GetStatusText(status)
		end
		if status == "invited" or status == "inviteaccepted" then
			statusColor = STATUS_GREEN
		elseif GRAYED_STATUSES[status] then
			statusColor = STATUS_GRAY
		end
	end
	local showActions = not appInfo.applicantInfo and status == "applied"
	local declineIsAck = status ~= "applied" and status ~= "invited"
	local useCompactInvite = activityInfo ~= nil
		and (activityInfo.isMythicPlusActivity or activityInfo.isRatedPvpActivity)
	local applicant = {
		activityInfo = activityInfo,
		appInfo = appInfo,
		applicantID = numericID,
		canDecline = showActions and not nativePending
			and GF.ApplicantActionService:CanDecline(numericID),
		canInvite = showActions and not nativePending
			and GF.ApplicantActionService:CanInvite(numericID),
		comment = appInfo.comment or "",
		declineIsAck = declineIsAck,
		grayed = isGrayedOut(appInfo),
		isNew = appInfo.isNew,
		loading = appInfo.applicantInfo and true or nativePending,
		members = members,
		numMembers = numMembers,
		showDecline = showActions,
		showInvite = showActions,
		status = status,
		statusColor = statusColor,
		statusText = statusText,
		useCompactInvite = useCompactInvite,
	}
	return applicant
end

function Builder:BuildApplicantSafely(applicantID)
	local ok, data = pcall(self.BuildApplicant, self, applicantID)
	if not ok or type(data) ~= "table" then
		return nil
	end
	return data
end

function Builder:CloneApplicantData(data)
	if type(data) ~= "table" then
		return nil
	end
	local clone = {}
	for key, value in pairs(data) do
		clone[key] = value
	end
	clone.members = {}
	for index, member in ipairs(data.members or {}) do
		local memberClone = {}
		for key, value in pairs(member) do
			memberClone[key] = value
		end
		clone.members[index] = memberClone
	end
	return clone
end

function Builder:GetApplicantRosterIdentity(data)
	if type(data) ~= "table" then
		return nil
	end
	local rawCount = data.numMembers
	if rawCount ~= nil and not isAccessibleValue(rawCount) then
		return nil
	end
	local okCount, numericCount = pcall(tonumber, rawCount)
	if not okCount then
		return nil
	end
	if numericCount ~= nil
		and (numericCount < 1 or numericCount > 40 or numericCount % 1 ~= 0)
	then
		return nil
	end
	local expectedCount = numericCount or 1
	local keys = {}
	local seen = {}
	for index = 1, expectedCount do
		local member = data.members and data.members[index]
		local key = member and member.rosterIdentityKey
		if key == nil and member then
			key = normalizeRosterIdentityName(member.name)
		end
		if not isAccessibleValue(key) or type(key) ~= "string"
			or key == "" or seen[key]
		then
			return nil
		end
		seen[key] = true
		keys[index] = key
	end
	return {
		expectedCount = expectedCount,
		keys = keys,
		keySet = seen,
	}
end

function Builder:GetHomeRosterIdentitySnapshot()
	local home = LE_PARTY_CATEGORY_HOME
	local units = {}
	local expectedCount = 1
	local complete = true
	local inRaid = readBoolean(IsInRaid, home)
	if inRaid == nil then
		complete = false
		units[1] = "player"
	elseif inRaid then
		local count = readNumber(GetNumGroupMembers, home)
		if count == nil then
			complete = false
			count = 0
		end
		count = math.max(0, math.min(40, math.floor(count)))
		expectedCount = math.max(1, count)
		for index = 1, count do
			units[#units + 1] = "raid" .. index
		end
	else
		local inGroup = readBoolean(IsInGroup, home)
		if inGroup == nil then
			complete = false
			units[1] = "player"
		elseif inGroup then
			local count = readNumber(GetNumGroupMembers, home)
			if count == nil then
				complete = false
				count = readNumber(GetNumSubgroupMembers)
				count = count and (count + 1) or 1
			end
			count = math.max(1, math.min((MAX_PARTY_MEMBERS or 4) + 1, math.floor(count)))
			expectedCount = count
			units[1] = "player"
			for index = 1, count - 1 do
				units[#units + 1] = "party" .. index
			end
		else
			units[1] = "player"
		end
	end

	local snapshot = {
		byGUID = {},
		byName = {},
		complete = complete,
		expectedCount = expectedCount,
		guidByName = {},
	}
	local readableCount = 0
	for _, unit in ipairs(units) do
		local identity = readUnitRosterIdentity(unit)
		if identity and identity.nameKey then
			readableCount = readableCount + 1
			if snapshot.byName[identity.nameKey] ~= nil then
				snapshot.byName[identity.nameKey] = false
				snapshot.guidByName[identity.nameKey] = nil
				snapshot.complete = false
			else
				snapshot.byName[identity.nameKey] = identity
				snapshot.guidByName[identity.nameKey] = identity.guidKey
			end
		else
			snapshot.complete = false
		end
		if identity and identity.guidKey then
			snapshot.byGUID[identity.guidKey] = identity
		end
	end
	if #units ~= expectedCount or readableCount ~= expectedCount then
		snapshot.complete = false
	end
	return snapshot
end

function Builder.GetLabelGold()
	local color = LABEL_GOLD
	return color.r, color.g, color.b
end

function Builder.GetIlvlValueColor()
	local color = IL_VALUE
	return color.r, color.g, color.b
end
