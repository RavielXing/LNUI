local _, GF = ...
GF = GF.GF or GF

GF.ApplicantRaidTooltip = GF.ApplicantRaidTooltip or {}
local ART = GF.ApplicantRaidTooltip

local LABEL_COLOR = { r = 1, g = 0.82, b = 0 }
local TEXT_COLOR = { r = 1, g = 1, b = 1 }
local GRAY_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
local NORMAL_COLOR = { r = 1, g = 1, b = 1 }
local HEROIC_COLOR = { r = 0.18, g = 0.85, b = 0.36 }
local MYTHIC_COLOR = { r = 0.72, g = 0.22, b = 1 }
local WCL_COLOR = { r = 0.15, g = 0.78, b = 1 }
local MAX_WCL_SECTIONS = 3

local RAID_DIFFICULTY_ID_BY_TIER = {
	[1] = "PrimaryRaidNormal",
	[2] = "PrimaryRaidHeroic",
	[3] = "PrimaryRaidMythic",
}

local RAID_DIFFICULTY_LOCALE_KEY_BY_TIER = {
	[1] = "DIFF_NORMAL",
	[2] = "DIFF_HEROIC",
	[3] = "DIFF_MYTHIC",
}

local RAID_DIFFICULTY_FALLBACK_BY_TIER = {
	[1] = "Normal",
	[2] = "Heroic",
	[3] = "Mythic",
}

local ARCHON_DIFFICULTY_TIER_BY_ID = {
	[3] = 1,
	[4] = 2,
	[5] = 3,
	[14] = 1,
	[15] = 2,
	[16] = 3,
}

local function trimText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

local function callFirst(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

local function localeText(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback
end

local function safeFormat(formatText, fallback, ...)
	if type(formatText) == "string" then
		local ok, text = pcall(string.format, formatText, ...)
		if ok and text then
			return text
		end
	end
	return string.format(fallback, ...)
end

local function localeFormat(key, fallback, ...)
	return safeFormat(localeText(key, fallback), fallback, ...)
end

local function normalizedColor(color, fallback)
	fallback = fallback or TEXT_COLOR
	if color and color.r and color.g and color.b then
		return color
	end
	return fallback
end

local function wrapColor(color, text)
	text = tostring(text or "")
	color = normalizedColor(color)
	if color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return string.format("|cff%02x%02x%02x%s|r",
		math.floor((color.r or 1) * 255 + 0.5),
		math.floor((color.g or 1) * 255 + 0.5),
		math.floor((color.b or 1) * 255 + 0.5),
		text)
end

local function addDoubleLine(tooltip, label, value, labelColor, valueColor)
	if not (tooltip and tooltip.AddDoubleLine) then
		return
	end
	labelColor = normalizedColor(labelColor, LABEL_COLOR)
	valueColor = normalizedColor(valueColor, TEXT_COLOR)
	tooltip:AddDoubleLine(label, value or "-",
		labelColor.r, labelColor.g, labelColor.b,
		valueColor.r, valueColor.g, valueColor.b)
end

local function isRaidActivity(memberData)
	local activityInfo = memberData and memberData.activityInfo
	if not activityInfo then
		return false
	end
	return activityInfo.categoryID == GF.CAT_RAID
		or activityInfo.isCurrentRaidActivity == true
end

local function profileService()
	return GF.ApplicantRaidProfileService
end

local function hasRaidDataProvider()
	local service = profileService()
	return service and type(service.HasProvider) == "function"
		and service:HasProvider() == true
end

local function getPreparedProfile(kind, name)
	local service = profileService()
	if not (service and type(service.GetProfile) == "function") then
		return nil, "unavailable"
	end
	return service:GetProfile(kind, name)
end

local function isPendingState(state)
	local service = profileService()
	return state == "pending"
		or (service and state == service.STATE_PENDING)
end

local function getClientActivityRaidLabel(memberData)
	local activityInfo = memberData and memberData.activityInfo
	if type(activityInfo) ~= "table" then
		return nil
	end
	local groupID = tonumber(activityInfo.groupFinderActivityGroupID)
	if groupID and C_LFGList and C_LFGList.GetActivityGroupInfo then
		local groupName = trimText(callFirst(
			C_LFGList.GetActivityGroupInfo, groupID))
		if groupName then
			return groupName
		end
	end
	return trimText(activityInfo.fullName)
		or trimText(activityInfo.name)
		or trimText(activityInfo.shortName)
end

local function raidDifficultyColor(tier)
	tier = tonumber(tier)
	if tier == 3 then
		return MYTHIC_COLOR
	end
	if tier == 2 then
		return HEROIC_COLOR
	end
	return NORMAL_COLOR
end

local function raidDifficultyLabel(tier)
	tier = tonumber(tier)
	if not tier then
		return nil
	end
	local ids = DifficultyUtil and DifficultyUtil.ID
	local difficultyIDKey = RAID_DIFFICULTY_ID_BY_TIER[tier]
	local difficultyID = difficultyIDKey and ids and ids[difficultyIDKey]
	if difficultyID and DifficultyUtil and DifficultyUtil.GetDifficultyName then
		local name = trimText(callFirst(
			DifficultyUtil.GetDifficultyName, difficultyID))
		if name then
			return name
		end
	end
	local localeKey = RAID_DIFFICULTY_LOCALE_KEY_BY_TIER[tier]
	return localeText(
		localeKey, RAID_DIFFICULTY_FALLBACK_BY_TIER[tier] or "")
end

local function raiderIORaidKey(raid)
	if type(raid) ~= "table" then
		return "raid:" .. tostring(raid)
	end
	local dungeon = type(raid.dungeon) == "table" and raid.dungeon or nil
	return "raid:" .. tostring(raid.id or raid.mapId
		or (dungeon and dungeon.id) or raid.name or raid.shortName)
end

local function raiderIORaidName(raid)
	if type(raid) ~= "table" then
		return nil
	end
	local service = profileService()
	local localizedName = service
		and type(service.GetRaiderIORaidDisplayName) == "function"
		and service:GetRaiderIORaidDisplayName(raid) or nil
	local dungeon = type(raid.dungeon) == "table" and raid.dungeon or nil
	return trimText(localizedName)
		or trimText(raid.name)
		or trimText(dungeon and dungeon.name)
		or trimText(raid.shortNameLocale)
		or trimText(dungeon and dungeon.shortNameLocale)
		or trimText(raid.shortName)
		or trimText(dungeon and dungeon.shortName)
end

local function raiderIOBossCount(raid)
	if type(raid) ~= "table" then
		return nil
	end
	local dungeon = type(raid.dungeon) == "table" and raid.dungeon or nil
	local count = tonumber(raid.bossCount)
		or tonumber(dungeon and dungeon.bossCount)
	return count and count > 0 and count or nil
end

local function raiderIOTotalKills(progress)
	if not (type(progress) == "table"
		and type(progress.killsPerBoss) == "table")
	then
		return 0
	end
	local total = 0
	for _, value in pairs(progress.killsPerBoss) do
		local count = tonumber(value)
		if count and count > 0 then
			total = total + count
		end
	end
	return total
end

local function raiderIOProgressValue(progress, raid)
	if type(progress) ~= "table" then
		return nil
	end
	local completed = tonumber(progress.progressCount)
	local possible = raiderIOBossCount(raid)
	local value
	if completed and possible then
		value = string.format("%d/%d", completed, possible)
	elseif completed then
		value = tostring(completed)
	end
	local totalKills = raiderIOTotalKills(progress)
	if totalKills > 0 then
		local killsText = localeFormat(
			"APPLICANT_RAID_KILLS_FMT", "%d Kills", totalKills)
		value = value and (value .. "  " .. killsText) or killsText
	end
	return value
end

local function collectRaiderIOSections(name)
	local service = profileService()
	local kind = service and service.PROVIDER_RAIDERIO or "raiderio"
	local raidProfile, state = getPreparedProfile(kind, name)
	if not (raidProfile and type(raidProfile.progress) == "table") then
		return nil, state
	end
	local groups = {}
	local order = {}
	for i = 1, #raidProfile.progress do
		local progress = raidProfile.progress[i]
		if type(progress) == "table" and type(progress.raid) == "table" then
			local key = raiderIORaidKey(progress.raid)
			local group = groups[key]
			if not group then
				group = { raid = progress.raid, progress = {} }
				groups[key] = group
				order[#order + 1] = key
			end
			group.progress[#group.progress + 1] = progress
		end
	end

	local sections = {}
	for i = 1, #order do
		local group = groups[order[i]]
		local raidName = raiderIORaidName(group.raid)
		if raidName then
			local rows = {}
			for progressIndex = 1, #group.progress do
				local progress = group.progress[progressIndex]
				local tier = tonumber(progress.difficulty)
				local label = raidDifficultyLabel(tier)
				local value = raiderIOProgressValue(progress, group.raid)
				if label and label ~= "" and value then
					rows[#rows + 1] = {
						label = wrapColor(raidDifficultyColor(tier), label),
						value = value,
					}
				end
			end
			if #rows > 0 then
				sections[#sections + 1] = {
					title = raidName,
					rows = rows,
				}
			end
		end
	end
	return #sections > 0 and sections or nil, state
end

local function formatPercentile(value)
	value = tonumber(value)
	if not value or value <= 0 then
		return "-"
	end
	if value == math.floor(value) then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

local function archonDifficultyLabel(difficultyID)
	local tier = ARCHON_DIFFICULTY_TIER_BY_ID[tonumber(difficultyID) or 0]
	return raidDifficultyLabel(tier), tier
end

local function buildArchonSummaryRow(data, raidName)
	if type(data) ~= "table" then
		return nil
	end
	raidName = trimText(raidName)
	local killed = tonumber(data.progressKilled)
	local possible = tonumber(data.progressPossible)
	if not (raidName and killed and possible and possible > 0) then
		return nil
	end
	local difficultyLabel, tier = archonDifficultyLabel(data.difficultyId)
	local label = raidName
	if difficultyLabel and difficultyLabel ~= "" then
		label = wrapColor(raidDifficultyColor(tier), difficultyLabel)
			.. " " .. label
	end
	local progressText = string.format("%d/%d", killed, possible)
	local killsText = localeFormat(
		"APPLICANT_RAID_KILLS_FMT", "%d Kills", tonumber(data.totalKills) or 0)
	local bestAverage = tonumber(data.bestAverage)
	local value
	if bestAverage and bestAverage > 0 then
		value = string.format(
			"%s  %s  %s", formatPercentile(bestAverage), progressText, killsText)
	else
		value = string.format("%s  %s", progressText, killsText)
	end
	return { label = label, value = value }
end

local function collectArchonSections(name, memberData)
	local service = profileService()
	local kind = service and service.PROVIDER_ARCHON or "archon"
	local profile, state = getPreparedProfile(kind, name)
	if not profile then
		return nil, state
	end
	local sections = {}
	local fallbackName = getClientActivityRaidLabel(memberData)
	if type(profile.sections) == "table" then
		for i = 1, #profile.sections do
			local section = profile.sections[i]
			local rankings = type(section) == "table"
				and section.anySpecRankings or nil
			local row = buildArchonSummaryRow({
				difficultyId = section and section.difficultyId,
				progressKilled = rankings and rankings.progressKilled,
				progressPossible = rankings and rankings.progressPossible,
				totalKills = section and section.totalKills,
				bestAverage = rankings and rankings.bestAverage,
			}, fallbackName)
			if row then
				sections[#sections + 1] = row
				if #sections >= MAX_WCL_SECTIONS then
					break
				end
			end
		end
	end
	if #sections == 0 then
		local row = buildArchonSummaryRow(profile.summary, fallbackName)
		if row then
			sections[#sections + 1] = row
		end
	end
	if #sections < MAX_WCL_SECTIONS then
		local row = buildArchonSummaryRow(profile.mainCharacter, fallbackName)
		if row then
			sections[#sections + 1] = row
		end
	end
	return #sections > 0 and sections or nil, state
end

local function raidProgressTitle(memberData)
	if memberData.tooltipKind == "raidSeeking" then
		return localeText("SEEK_TOOLTIP_RAID_PROGRESS_TITLE", "Season Raid Progress:")
	end
	return localeText("APPLICANT_RAID_PROGRESS_TITLE", "Raid Progress")
end

local function renderRaiderIO(tooltip, sections, memberData)
	if not (sections and #sections > 0 and tooltip) then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(raidProgressTitle(memberData),
		LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
	for i = 1, #sections do
		local section = sections[i]
		if section.title and section.title ~= "" then
			tooltip:AddLine(
				section.title, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
		end
		for rowIndex = 1, #section.rows do
			local row = section.rows[rowIndex]
			addDoubleLine(tooltip, row.label, row.value, TEXT_COLOR, TEXT_COLOR)
		end
	end
	return true
end

local function renderArchon(tooltip, sections)
	if not (sections and #sections > 0 and tooltip) then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(localeText(
		"APPLICANT_WCL_PROGRESS_TITLE", "Warcraft Logs"),
		WCL_COLOR.r, WCL_COLOR.g, WCL_COLOR.b, true)
	for i = 1, #sections do
		local section = sections[i]
		addDoubleLine(
			tooltip, section.label, section.value, TEXT_COLOR, TEXT_COLOR)
	end
	return true
end

local function renderProviderLoading(tooltip)
	if not tooltip then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(localeText(
		"APPLICANT_RAID_PROGRESS_LOADING", "Preparing raid progress data"),
		GRAY_COLOR.r, GRAY_COLOR.g, GRAY_COLOR.b, true)
	return true
end

local function renderProviderNoData(tooltip, memberData)
	if not tooltip then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(raidProgressTitle(memberData),
		LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
	local noData = memberData.tooltipKind == "raidSeeking"
		and localeText("SEEK_TOOLTIP_RAID_NO_DATA", "No data")
		or localeText("APPLICANT_RAID_PROGRESS_NO_DATA", "No raid progress data")
	tooltip:AddLine(noData,
		GRAY_COLOR.r, GRAY_COLOR.g, GRAY_COLOR.b, true)
	return true
end

local function appendDialogSectionTitle(rows, title, color)
	rows[#rows + 1] = {
		label = title,
		value = "",
		labelColor = color or LABEL_COLOR,
		valueColor = color or LABEL_COLOR,
		fullWidth = true,
	}
end

local function appendDialogSpacer(rows)
	rows[#rows + 1] = {
		divider = true,
	}
end

local function appendDialogLoading(rows)
	rows[#rows + 1] = {
		label = localeText(
			"APPLICANT_RAID_PROGRESS_LOADING", "Preparing raid progress data"),
		value = "",
		labelColor = GRAY_COLOR,
		valueColor = GRAY_COLOR,
		fullWidth = true,
	}
end

function ART.Prepare(memberData)
	if not (memberData and isRaidActivity(memberData))
		or memberData.isTest == true
		or memberData.isDebugTest == true
	then
		return false
	end
	local name = memberData.name or memberData.displayName
	local service = profileService()
	if not (name and name ~= "" and service
		and type(service.Prepare) == "function")
	then
		return false
	end
	service:Prepare(name)
	return true
end

function ART.CancelPending()
	local service = profileService()
	if service and type(service.CancelPending) == "function" then
		service:CancelPending()
	end
end

function ART.BuildCharacterInfoRows(name, memberData)
	if not (memberData and isRaidActivity(memberData)) then
		return nil, false
	end
	name = name or memberData.name or memberData.displayName
	if not name or name == "" then
		return nil, hasRaidDataProvider()
	end
	ART.Prepare(memberData)

	local rows = {}
	local raiderIOSections, raiderIOState = collectRaiderIOSections(name)
	if raiderIOSections then
		for i = 1, #raiderIOSections do
			local section = raiderIOSections[i]
			if section.title and section.title ~= "" then
				appendDialogSectionTitle(rows, section.title, LABEL_COLOR)
			end
			for rowIndex = 1, #section.rows do
				local row = section.rows[rowIndex]
				rows[#rows + 1] = {
					label = row.label,
					value = row.value,
					labelColor = TEXT_COLOR,
					valueColor = TEXT_COLOR,
					wideValue = true,
				}
			end
		end
	end

	local archonSections, archonState = collectArchonSections(name, memberData)
	if archonSections then
		if #rows > 0 then
			appendDialogSpacer(rows)
		end
		appendDialogSectionTitle(rows, localeText(
			"APPLICANT_WCL_PROGRESS_TITLE", "Warcraft Logs"), WCL_COLOR)
		for i = 1, #archonSections do
			local section = archonSections[i]
			rows[#rows + 1] = {
				label = section.label,
				value = section.value,
				labelColor = TEXT_COLOR,
				valueColor = TEXT_COLOR,
				wideValue = true,
			}
		end
	end

	if #rows == 0 and (isPendingState(raiderIOState)
		or isPendingState(archonState))
	then
		appendDialogLoading(rows)
	end
	return #rows > 0 and rows or nil, hasRaidDataProvider()
end

function ART.Append(tooltip, memberData)
	if not (tooltip and memberData and isRaidActivity(memberData)) then
		return false
	end
	local name = memberData.name or memberData.displayName
	if not name or name == "" then
		return false
	end
	ART.Prepare(memberData)

	local raiderIOSections, raiderIOState = collectRaiderIOSections(name)
	local archonSections, archonState = collectArchonSections(name, memberData)
	local shown = false
	shown = renderRaiderIO(tooltip, raiderIOSections, memberData) or shown
	shown = renderArchon(tooltip, archonSections) or shown
	if not shown and (isPendingState(raiderIOState)
		or isPendingState(archonState))
	then
		shown = renderProviderLoading(tooltip)
	elseif not shown and hasRaidDataProvider() then
		shown = renderProviderNoData(tooltip, memberData)
	end
	return shown
end
