-- GroupFinder archived activity hints.
--
-- These identifiers are non-authoritative facts exported from Blizzard's
-- GroupFinderActivity DB2 data. They provide the packaged structural baseline
-- and expansion placement only: live C_LFGList data still decides whether a
-- concrete instance is searchable/creatable, while the separately persisted
-- Journal overlay can enrich or add structure learned on newer clients.

local _, GF = ...

-- Each encoded record is groupID,activityID,listFilters. Zero means the field
-- is absent. Keeping the archive flat makes its role explicit: this is input
-- data for GF.NavCatalog, not a second navigation tree.
local BASE_BUILD = 67823
local LATEST_BUILD = 68235
-- Revision 3 invalidates Journal overlays written before tier selection was
-- verified. Those snapshots could contain the right instance list under the
-- wrong expansion and are unsafe as last-known-good structure.
local DATA_REVISION = 3

-- 12.0.5.67823 is the complete baseline. 12.0.7.68235 only added two raid
-- identities to the subset consumed by navigation, so keep that release as a
-- tiny delta instead of retaining two decoded copies of the whole archive.
local ARCHIVE = {
	dungeon = {
		categoryID = 2,
		baseFilters = 196,
		preferredFilters = 4,
		expansions = {
			{ 11, "370,0,101;382,1699,165;392,1721,165;396,1749,165;398,1754,165;399,0,101;400,0,101;401,0,101" },
			{ 10, "322,0,134;323,0,134;324,0,134;325,0,134;326,0,134;327,0,134;328,0,134;329,0,134;371,0,134;381,0,134" },
			{ 9, "302,0,134;303,0,134;304,0,134;305,0,134;306,0,134;307,0,134;308,0,134;309,0,134;315,0,134;316,0,134;317,0,134" },
			{ 8, "259,0,134;260,0,134;261,0,134;262,0,134;263,0,134;264,0,134;265,0,134;266,0,134;272,0,134;280,0,134;281,0,134;309,0,134" },
			{ 7, "136,0,134;137,0,134;138,0,134;139,0,134;140,0,134;141,0,134;142,0,134;143,0,134;144,0,134;145,0,134;146,0,134;253,0,134;256,0,134;257,0,134" },
			{ 6, "111,0,134;112,0,134;113,0,134;114,0,134;115,0,134;116,0,134;117,0,134;118,0,134;119,0,134;120,0,134;121,0,134;125,0,134;127,0,134;128,0,134;129,0,134;133,0,69" },
			{ 5, "6,0,134;7,0,134;8,0,134;9,0,70;10,0,134;11,0,134;12,0,134;13,0,134;109,0,134" },
			{ 4, "18,0,134;30,0,134;31,0,134;61,0,134;62,0,134;63,0,134;64,0,134;65,0,134;66,0,134;84,0,134" },
			{ 3, "5,0,134;19,0,134;54,0,134;55,0,134;56,0,134;57,0,134;58,0,134;59,0,134;60,0,134;0,150,134;0,151,134;0,152,134;0,153,134;0,154,134" },
			{ 2, "38,0,134;39,0,134;40,0,134;41,0,134;42,0,134;43,0,134;44,0,134;45,0,134;46,0,134;47,0,134;48,0,134;49,0,134;50,0,134;51,0,134;52,0,134;53,0,134" },
			{ 1, "20,0,134;21,0,134;22,0,134;23,0,134;24,0,134;25,0,134;26,0,134;27,0,134;28,0,134;29,0,134;32,0,134;33,0,134;34,0,134;35,0,134;36,0,134;37,0,134;44,0,134" },
			{ 0, "5,0,134;18,0,134;19,0,134;30,0,134;31,0,134;0,50,134;0,52,134;0,54,134;0,55,134;0,56,134;0,57,134;0,58,134;0,59,134;0,60,134;0,61,134;0,62,134;0,63,134;0,64,134;0,65,134;0,66,134" },
		},
	},
	raid = {
		categoryID = 3,
		baseFilters = 5,
		preferredFilters = 4,
		expansions = {
			{ 11, "402,0,165;403,0,165;404,0,165;0,1735,165" },
			{ 10, "362,0,134;377,0,134;378,0,134;0,1289,134" },
			{ 9, "310,0,134;313,0,134;319,0,134;0,1146,134" },
			{ 8, "267,0,134;271,0,134;282,0,134;0,723,134" },
			{ 7, "135,0,134;251,0,134;252,0,134;254,0,134;255,0,134;258,0,134;0,657,134" },
			{ 6, "122,0,134;123,0,134;126,0,134;131,0,134;132,0,134;0,458,134;0,1674,134" },
			{ 5, "14,0,134;15,0,134;110,0,134;0,398,134" },
			{ 4, "1,0,134;80,0,134;81,0,134;82,0,134;83,0,134;0,397,134" },
			{ 3, "75,0,134;76,0,134;77,0,134;78,0,134;79,0,134" },
			{ 2, "16,0,134;17,0,134;73,0,134;74,0,134;0,303,134" },
			{ 1, "0,45,134;0,296,134;0,297,134;0,298,134;0,299,134;0,300,134;0,301,134" },
			{ 0, "372,0,134;0,9,134;0,293,134;0,294,134;0,295,134" },
		},
	},
}

local DELTAS = {
	{
		build = LATEST_BUILD,
		upsert = {
			raid = {
				[11] = "422,0,165;0,1968,165",
			},
		},
	},
}

local function optionalID(value)
	value = tonumber(value)
	return value ~= 0 and value or nil
end

local function decodeInstances(encoded)
	local instances = {}
	for groupID, activityID, listFilters in encoded:gmatch("(%d+),(%d+),(%d+)") do
		instances[#instances + 1] = {
			groupID = optionalID(groupID),
			activityID = optionalID(activityID),
			listFilters = tonumber(listFilters),
		}
	end
	return instances
end

local function recordIdentity(record)
	if record.groupID then
		return "g:" .. tostring(record.groupID)
	end
	return "a:" .. tostring(record.activityID or 0)
end

local function recordComesBefore(left, right)
	local leftGroup = tonumber(left and left.groupID)
	local rightGroup = tonumber(right and right.groupID)
	if (leftGroup ~= nil) ~= (rightGroup ~= nil) then
		return leftGroup ~= nil
	end
	local leftID = leftGroup or tonumber(left and left.activityID) or 0
	local rightID = rightGroup or tonumber(right and right.activityID) or 0
	return leftID < rightID
end

local function applyEncodedUpserts(instances, encoded)
	local byIdentity = {}
	for index, record in ipairs(instances) do
		byIdentity[recordIdentity(record)] = index
	end
	for _, record in ipairs(decodeInstances(encoded or "")) do
		local identity = recordIdentity(record)
		local index = byIdentity[identity]
		if index then
			instances[index] = record
		else
			instances[#instances + 1] = record
			byIdentity[identity] = #instances
		end
	end
	table.sort(instances, recordComesBefore)
end

local function buildCatalogSection(kind, source, selectedBuild)
	local section = {
		categoryID = source.categoryID,
		baseFilters = source.baseFilters,
		preferredFilters = source.preferredFilters,
		expansions = {},
	}
	for index, encodedExpansion in ipairs(source.expansions) do
		local expansion = {
			expansionIndex = encodedExpansion[1],
			instances = decodeInstances(encodedExpansion[2]),
		}
		for _, delta in ipairs(DELTAS) do
			local encoded = selectedBuild >= delta.build
				and delta.upsert
				and delta.upsert[kind]
				and delta.upsert[kind][expansion.expansionIndex]
			if encoded then
				applyEncodedUpserts(expansion.instances, encoded)
			end
		end
		section.expansions[index] = expansion
	end
	return section
end

local function clientBuild()
	local build = GF.Compat and tonumber(GF.Compat.build)
	if build then
		return build
	end
	if type(GetBuildInfo) == "function" then
		local ok, _, value = pcall(GetBuildInfo)
		if ok then
			return tonumber(value)
		end
	end
	return nil
end

local function selectBuild(build)
	build = tonumber(build)
	if build == nil or build >= LATEST_BUILD then
		return LATEST_BUILD
	end
	-- No older generated snapshot is shipped. 12.0.0 declarations therefore
	-- consume the first known-good 12.0.5 structure as a conservative fallback.
	return BASE_BUILD
end

local function buildCatalog(build)
	local selectedBuild = selectBuild(build)
	return {
		dungeon = buildCatalogSection(
			"dungeon", ARCHIVE.dungeon, selectedBuild),
		raid = buildCatalogSection(
			"raid", ARCHIVE.raid, selectedBuild),
	}, selectedBuild
end

local Data = GF.NavCatalogData or {}
GF.NavCatalogData = Data
GF.NAV_CATALOG_DATA_REVISION = DATA_REVISION

function Data.GetCatalogForBuild(build)
	return buildCatalog(build)
end

function Data.GetCatalog()
	return GF.NAV_CATALOG
end

function Data.GetSelectedBuild()
	return Data.selectedBuild
end

function Data.GetSchemaVersion()
	return 1
end

function Data.GetKnownBuilds()
	return { BASE_BUILD, LATEST_BUILD }
end

GF.NAV_CATALOG, Data.selectedBuild = buildCatalog(clientBuild())

return GF.NAV_CATALOG
