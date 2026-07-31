local _, GF = ...

GF.ApplicantModel = {}
local AM = GF.ApplicantModel

local LABEL_GOLD = { r = 1, g = 0.82, b = 0 }
local IL_VALUE = { r = 0.1, g = 1, b = 0.1 }

local STATUS_GRAY = { r = 0.5, g = 0.5, b = 0.5 }
local STATUS_GREEN = GREEN_FONT_COLOR or { r = 0, g = 1, b = 0 }
local MAX_APPLICANT_API_ID = 4294967295

local GRAYED_STATUSES = {
	failed = true,
	cancelled = true,
	declined = true,
	declined_full = true,
	declined_delisted = true,
	invitedeclined = true,
	timedout = true,
	inviteaccepted = true,
}

local ROLE_SORT_RANK = {
	TANK = 1,
	HEALER = 2,
	DAMAGER = 3,
	DPS = 3,
}
local UNKNOWN_ROLE_SORT_RANK = 4

local function getActivityInfo()
	if not C_LFGList or not C_LFGList.GetActiveEntryInfo then
		return nil
	end
	local entry = C_LFGList.GetActiveEntryInfo()
	if not entry or not entry.activityIDs or not entry.activityIDs[1] then
		return nil
	end
	if C_LFGList.GetActivityInfoTable then
		return C_LFGList.GetActivityInfoTable(entry.activityIDs[1], entry.questID)
	end
	return nil
end

local function isGrayedOut(appInfo)
	if not appInfo then
		return true
	end
	if appInfo.pendingApplicationStatus then
		return false
	end
	local status = appInfo.applicationStatus
	return status and GRAYED_STATUSES[status] or false
end

local function getBlocklistMatch(playerName)
	local bl = GF.Blocklist
	if not playerName or playerName == "" or not bl then
		return nil
	end
	if bl.IsEnabled and not bl:IsEnabled() then
		return nil
	end
	if bl.FindPlayerMatch then
		return bl:FindPlayerMatch(playerName)
	end
	return nil
end

local function getSpecName(specID)
	if specID and PlayerUtil and PlayerUtil.GetSpecNameBySpecID then
		local specName = PlayerUtil.GetSpecNameBySpecID(specID)
		if specName and specName ~= "" then
			return specName
		end
	end
	return nil
end

local function specDisplayName(specID, localizedClass)
	local className = localizedClass or ""
	local specName = getSpecName(specID)
	if specName then
		return specName
	end
	return className
end

local function memberItemLevel(activityInfo, itemLevel, pvpItemLevel)
	if activityInfo and activityInfo.isPvpActivity then
		return math.floor(pvpItemLevel or 0)
	end
	return math.floor(itemLevel or 0)
end

local function getListingDungeonScore(applicantID, memberIdx)
	if not C_LFGList or not C_LFGList.GetApplicantDungeonScoreForListing then
		return nil
	end
	local entry = C_LFGList.GetActiveEntryInfo()
	local actID = entry and entry.activityIDs and entry.activityIDs[1]
	if not actID then
		return nil
	end
	local ok, scoreInfo = pcall(C_LFGList.GetApplicantDungeonScoreForListing, applicantID, memberIdx, actID)
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
	if not shouldBuildMplusProfile(activityInfo) then
		return nil
	end
	local includeListingDungeon = activityInfo and activityInfo.isMythicPlusActivity
	local overall = (dungeonScore and dungeonScore > 0) and dungeonScore or nil
	local listing = includeListingDungeon and getListingDungeonScore(applicantID, memberIdx) or nil
	local bestOverall = getBestDungeonScore(applicantID, memberIdx)
	if not overall and not listing and not bestOverall then
		return includeListingDungeon and {} or nil
	end
	return {
		overall = overall,
		mapScore = listing and listing.mapScore,
		bestRunLevel = listing and listing.bestRunLevel,
		finishedSuccess = listing and listing.finishedSuccess,
		bestLevelIncrement = listing and listing.bestLevelIncrement,
		mapName = listing and listing.mapName,
		currentDungeon = listing,
		bestOverallScore = bestOverall,
	}
end

local function memberRatingText(applicantID, memberIdx, level, dungeonScore, activityInfo, mplusProfileDetail)
	local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL or 80)
	if level and level < maxLevel then
		return "level", level, nil, nil
	end
	if activityInfo and activityInfo.isRatedPvpActivity and C_LFGList.GetApplicantPvpRatingInfoForListing then
		local entry = C_LFGList.GetActiveEntryInfo()
		local actID = entry and entry.activityIDs and entry.activityIDs[1]
		if actID then
			local pvp = C_LFGList.GetApplicantPvpRatingInfoForListing(applicantID, memberIdx, actID)
			if pvp and type(pvp.rating) == "number" and pvp.rating >= 0 then
				return "rating", pvp.rating, GF.GetPvpRatingColor(pvp.rating), pvp
			end
		end
	end
	if activityInfo and activityInfo.isMythicPlusActivity then
		return "mplus", nil, nil, mplusProfileDetail or {}
	end
	local score = dungeonScore
	if score and score > 0 then
		local color = (C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score))
			or HIGHLIGHT_FONT_COLOR
		return "rating", score, color, nil
	end
	return "rating", nil, nil, nil
end

local function buildRoles(tank, healer, damage)
	local role1 = tank and "TANK" or (healer and "HEALER" or (damage and "DAMAGER"))
	local role2 = (tank and healer and "HEALER") or ((tank or healer) and damage and "DAMAGER")
	local role3 = (tank and healer and damage and "DAMAGER")
	return role1, role2, role3
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

function AM:GetApplicantSocialSortPin(applicantID)
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
	if not okInfo or not appInfo then
		return GF.NORMAL_SORT_PIN or 1
	end
	local numMembers = math.max(1, tonumber(appInfo.numMembers) or 1)
	for i = 1, numMembers do
		local ok, _, _, _, _, _, _, _, _, _, _, relationship =
			pcall(C_LFGList.GetApplicantMemberInfo, applicantID, i)
		if ok then
			local socialType = GF.GetSocialRelationshipType and GF.GetSocialRelationshipType(relationship)
			if socialType then
				return GF.GetSocialSortPin and GF.GetSocialSortPin(socialType) or 0
			end
		end
	end
	return GF.NORMAL_SORT_PIN or 1
end

function AM:GetApplicantSortKey(applicantID, columnID)
	local data = self:BuildApplicant(applicantID)
	return getApplicantDataSortKey(data, columnID)
end

function AM:GetSortedApplicantIDs()
	local ids = C_LFGList.GetApplicants() or {}
	if LFGListUtil_SortApplicants then
		LFGListUtil_SortApplicants(ids)
	end
	if GF.ApplicantTestData and GF.ApplicantTestData.IsEnabled and GF.ApplicantTestData:IsEnabled() then
		local testIDs = GF.ApplicantTestData:GetApplicantIDs()
		for _, applicantID in ipairs(testIDs) do
			ids[#ids + 1] = applicantID
		end
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
	return ids
end

function AM:BuildMember(applicantID, memberIdx, appInfo, activityInfo)
	local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore, pvpItemLevel, factionGroup, _, specID, isLeaver =
		C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)

	local grayed = isGrayedOut(appInfo)
	local role1, role2, role3 = buildRoles(tank, healer, damage)
	local mplusProfileDetail = buildMplusProfileDetail(applicantID, memberIdx, dungeonScore, activityInfo)
	local ratingKind, ratingValue, ratingColor, ratingDetail = memberRatingText(applicantID, memberIdx, level, dungeonScore, activityInfo, mplusProfileDetail)
	local blacklistEntry = getBlocklistMatch(name)
	local specName = getSpecName(specID)
	local isLaonongFan
	if GF.IsLaonongFanDirectoryReady and GF.IsLaonongFanDirectoryReady() then
		isLaonongFan = GF.IsLaonongFanName
			and GF.IsLaonongFanName(name, nil, true) == true or false
	end

	return {
		memberIdx = memberIdx,
		name = name,
		displayName = name and Ambiguate(name, "short") or nil,
		class = class,
		localizedClass = localizedClass,
		specID = specID,
		specName = specName,
		specText = specName or specDisplayName(specID, localizedClass),
		activityInfo = activityInfo,
		level = level,
		honorLevel = honorLevel,
		ilvl = memberItemLevel(activityInfo, itemLevel, pvpItemLevel),
		role1 = role1,
		role2 = role2,
		role3 = role3,
		assignedRole = assignedRole,
		relationship = relationship,
		isLeaver = isLeaver,
		isLaonongFan = isLaonongFan,
		isBlacklisted = blacklistEntry ~= nil,
		blacklistEntry = blacklistEntry,
		factionGroup = factionGroup,
		grayed = grayed,
		noTouchy = appInfo.applicationStatus == "invited",
		ratingKind = ratingKind,
		ratingValue = ratingValue,
		ratingColor = ratingColor,
		ratingDetail = ratingDetail,
		mplusProfileDetail = mplusProfileDetail,
		comment = appInfo.comment or "",
	}
end

function AM:BuildApplicant(applicantID)
	if GF.ApplicantTestData and GF.ApplicantTestData.IsTestApplicantID
		and GF.ApplicantTestData:IsTestApplicantID(applicantID) then
		return GF.ApplicantTestData:BuildApplicant(applicantID)
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return nil
	end
	local appInfo = C_LFGList.GetApplicantInfo(applicantID)
	if not appInfo then
		return nil
	end
	local activityInfo = getActivityInfo()
	local numMembers = appInfo.numMembers or 1
	local members = {}
	for i = 1, numMembers do
		members[i] = self:BuildMember(applicantID, i, appInfo, activityInfo)
	end

	local status = appInfo.applicationStatus
	local statusText, statusColor
	if appInfo.applicantInfo then
		statusText = nil
	elseif status then
		statusText = GF.Listing:GetApplicantStatusMessage(status)
		if status == "invited" or status == "inviteaccepted" then
			statusColor = STATUS_GREEN
		elseif status == "failed" or status == "cancelled" or status == "declined"
			or status == "declined_full" or status == "declined_delisted"
			or status == "timedout" or status == "invitedeclined" then
			statusColor = STATUS_GRAY
		end
	end

	local showActions = not appInfo.applicantInfo
		and status == "applied"

	local declineIsAck = status ~= "applied" and status ~= "invited"
	local useCompactInvite = activityInfo and (activityInfo.isMythicPlusActivity or activityInfo.isRatedPvpActivity)

	return {
		applicantID = applicantID,
		appInfo = appInfo,
		members = members,
		numMembers = numMembers,
		comment = appInfo.comment or "",
		loading = appInfo.applicantInfo ~= nil,
		isNew = appInfo.isNew,
		status = status,
		statusText = statusText,
		statusColor = statusColor,
		grayed = isGrayedOut(appInfo),
		showInvite = showActions,
		showDecline = showActions,
		declineIsAck = declineIsAck,
		canInvite = showActions and GF.Listing:CanInviteApplicant(applicantID),
		canDecline = showActions and GF.Listing:CanDeclineApplicant(applicantID),
		useCompactInvite = useCompactInvite,
		activityInfo = activityInfo,
	}
end

function AM.GetLabelGold()
	return LABEL_GOLD.r, LABEL_GOLD.g, LABEL_GOLD.b
end

function AM.GetIlvlValueColor()
	return IL_VALUE.r, IL_VALUE.g, IL_VALUE.b
end
